#!/system/bin/sh
# sshvpn: dropbear SSH yang hanya bisa diakses lewat interface VPN (Tailscale/WireGuard app).
# Pakai: sshvpn.sh start|stop|restart|status|log|supervise|teardown|keys-get|keys-set <b64>|conf-set <KEY> <VAL>

MODDIR=${0%/*}
DATA=/data/adb/sshvpn
CONF=$DATA/sshvpn.conf
KEYS=$DATA/ssh/authorized_keys
HOSTKEY=$DATA/dropbear_ed25519_host_key
PIDF=$DATA/dropbear.pid
SUPF=$DATA/supervisor.pid
BOUND=$DATA/bound
STOPPED=$DATA/stopped
STAMP=$DATA/fw.stamp
LOG=$DATA/sshvpn.log
BIN=$MODDIR
CHAIN=SSHVPN
export PATH="$BIN:$PATH"

mkdir -p "$DATA/ssh" 2>/dev/null
chmod 700 "$DATA" "$DATA/ssh" 2>/dev/null

W=""
iptables -w -S >/dev/null 2>&1 && W="-w"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

load_conf() {
  PORT=2222; IFACES="tailscale0 wg0 tun0"; BIND=iface; IDLE=600; ALLOW_FWD=0
  [ -f "$CONF" ] && . "$CONF"
  case $PORT in ''|*[!0-9]*) PORT=2222;; esac
  case $IDLE in ''|*[!0-9]*) IDLE=600;; esac
  [ "$BIND" = all ] || BIND=iface
  [ "$ALLOW_FWD" = 1 ] || ALLOW_FWD=0
}

ifaddr() {
  ip -4 -o addr show dev "$1" 2>/dev/null | sed -n 's/.* inet \([0-9.]*\).*/\1/p' | head -n1
}

want_addrs() {
  if [ "$BIND" = all ]; then echo all; return; fi
  out=""
  for i in $IFACES; do
    a=$(ifaddr "$i")
    [ -n "$a" ] && out="$out $a"
  done
  echo "${out# }"
}

running() {
  p=$(cat "$PIDF" 2>/dev/null)
  [ -n "$p" ] && kill -0 "$p" 2>/dev/null && grep -q dropbear "/proc/$p/cmdline" 2>/dev/null
}

alive_sup() {
  s=$(cat "$SUPF" 2>/dev/null)
  [ -n "$s" ] && grep -q sshvpn.sh "/proc/$s/cmdline" 2>/dev/null
}

ensure_sup() {
  alive_sup || { nohup sh "$MODDIR/sshvpn.sh" supervise >/dev/null 2>&1 & }
}

fw_apply() {
  for T in iptables ip6tables; do
    command -v "$T" >/dev/null 2>&1 || continue
    "$T" $W -N "$CHAIN" 2>/dev/null
    "$T" $W -C INPUT -j "$CHAIN" 2>/dev/null || "$T" $W -I INPUT 1 -j "$CHAIN"
    "$T" $W -F "$CHAIN"
    for i in $IFACES; do
      "$T" $W -A "$CHAIN" -i "$i" -p tcp --dport "$PORT" -j ACCEPT
    done
    "$T" $W -A "$CHAIN" -p tcp --dport "$PORT" -j DROP
  done
  echo "$PORT|$IFACES" > "$STAMP"
}

fw_ensure() {
  [ "$(cat "$STAMP" 2>/dev/null)" = "$PORT|$IFACES" ] && iptables $W -C INPUT -j "$CHAIN" 2>/dev/null && return 0
  fw_apply
}

fw_clear() {
  for T in iptables ip6tables; do
    command -v "$T" >/dev/null 2>&1 || continue
    "$T" $W -D INPUT -j "$CHAIN" 2>/dev/null
    "$T" $W -F "$CHAIN" 2>/dev/null
    "$T" $W -X "$CHAIN" 2>/dev/null
  done
  rm -f "$STAMP"
}

stop_proc() {
  p=$(cat "$PIDF" 2>/dev/null)
  [ -n "$p" ] && kill "$p" 2>/dev/null
  pkill -f "$BIN/dropbear" 2>/dev/null
  rm -f "$PIDF" "$BOUND"
  return 0
}

start_proc() {
  sz=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
  [ "$sz" -gt 262144 ] && : > "$LOG"
  [ -x "$BIN/dropbear" ] || { log "dropbear tidak ada ($BIN/dropbear) - pasang zip dari GitHub Releases"; LASTERR="dropbear tidak ada"; return 1; }
  [ -s "$KEYS" ] || { log "authorized_keys kosong, tidak start"; LASTERR="authorized_keys kosong"; return 2; }
  want=$(want_addrs)
  [ -n "$want" ] || { LASTERR="interface VPN belum aktif"; return 3; }
  chmod 600 "$KEYS"
  [ -f "$HOSTKEY" ] || "$BIN/dropbearkey" -t ed25519 -f "$HOSTKEY" >>"$LOG" 2>&1
  chmod 600 "$HOSTKEY"
  fw_apply
  set -- -F -E -s -g -m -I "$IDLE" -r "$HOSTKEY" -D "$DATA/ssh"
  [ "$ALLOW_FWD" = 1 ] || set -- "$@" -j -k
  if [ "$want" = all ]; then
    set -- "$@" -p "$PORT"
  else
    for a in $want; do set -- "$@" -p "$a:$PORT"; done
  fi
  nohup "$BIN/dropbear" "$@" >>"$LOG" 2>&1 &
  echo $! > "$PIDF"
  echo "$want" > "$BOUND"
  sleep 1
  if running; then log "start ok: $want port $PORT"; else log "start gagal"; rm -f "$PIDF" "$BOUND"; LASTERR="dropbear gagal start, cek log"; return 4; fi
}

supervise() {
  alive_sup && exit 0
  echo $$ > "$SUPF"
  while :; do
    load_conf
    fw_ensure
    want=$(want_addrs)
    if [ -f "$STOPPED" ] || [ -z "$want" ]; then
      running && stop_proc
    elif [ -s "$KEYS" ]; then
      if ! running || [ "$want" != "$(cat "$BOUND" 2>/dev/null)" ]; then
        stop_proc
        start_proc
      fi
    fi
    sleep 15
  done
}

fingerprint() {
  [ -f "$HOSTKEY" ] && "$BIN/dropbearkey" -y -f "$HOSTKEY" 2>/dev/null | sed -n 's/^Fingerprint: //p'
}

status() {
  miss=""
  for b in dropbear dropbearkey; do
    [ -x "$BIN/$b" ] || miss="$miss $b"
  done
  if [ -n "$miss" ]; then bins="hilang:${miss# }"; else bins="ok"; fi
  [ -x "$BIN/scp" ] || bins="$bins (scp tidak ada, kirim file pakai ssh cat)"
  if running; then echo "running=1"; echo "pid=$(cat "$PIDF")"; else echo "running=0"; fi
  echo "stopped=$([ -f "$STOPPED" ] && echo 1 || echo 0)"
  echo "sup=$(alive_sup && echo 1 || echo 0)"
  echo "port=$PORT"
  echo "bind=$BIND"
  echo "ifaces=$IFACES"
  echo "idle=$IDLE"
  echo "fwd=$ALLOW_FWD"
  up=""
  for i in $IFACES; do
    a=$(ifaddr "$i")
    [ -n "$a" ] && up="$up $i=$a"
  done
  echo "up=${up# }"
  echo "bound=$(cat "$BOUND" 2>/dev/null)"
  n=$(grep -cE '^[^#[:space:]]' "$KEYS" 2>/dev/null)
  echo "keys=${n:-0}"
  echo "fp=$(fingerprint)"
  echo "bins=$bins"
  if running; then reason="berjalan"
  elif [ -n "$miss" ]; then reason="binary tidak lengkap:${miss# } - pasang zip dari GitHub Releases"
  elif [ -f "$STOPPED" ]; then reason="dihentikan manual"
  elif [ "${n:-0}" -eq 0 ]; then reason="authorized_keys kosong - isi public key di WebUI"
  elif [ -z "$(want_addrs)" ]; then reason="menunggu interface VPN ($IFACES) aktif"
  else reason="siap start (jalankan: sshvpn.sh restart)"
  fi
  echo "reason=$reason"
}

bad() { echo "invalid: $1"; exit 1; }

conf_set() {
  k=$1; v=$2
  case $k in
    PORT)
      case $v in ''|*[!0-9]*) bad PORT;; esac
      [ "$v" -ge 1024 ] && [ "$v" -le 65535 ] || bad "PORT 1024-65535" ;;
    IDLE)
      case $v in ''|*[!0-9]*) bad IDLE;; esac ;;
    ALLOW_FWD)
      [ "$v" = 0 ] || [ "$v" = 1 ] || bad ALLOW_FWD ;;
    BIND)
      [ "$v" = iface ] || [ "$v" = all ] || bad BIND ;;
    IFACES)
      case $v in ''|*[!A-Za-z0-9_.\ -]*) bad IFACES;; esac ;;
    *) bad "key $k" ;;
  esac
  [ -f "$CONF" ] || : > "$CONF"
  grep -v "^$k=" "$CONF" > "$CONF.tmp"
  printf '%s="%s"\n' "$k" "$v" >> "$CONF.tmp"
  mv "$CONF.tmp" "$CONF"
  chmod 600 "$CONF"
  echo ok
}

keys_set() {
  printf '%s' "$1" | base64 -d > "$KEYS.tmp" 2>/dev/null || { rm -f "$KEYS.tmp"; echo "invalid: base64"; exit 1; }
  badline=0
  while IFS= read -r l || [ -n "$l" ]; do
    case $l in
      ''|'#'*) ;;
      ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-nistp*\ *|sk-ssh-ed25519@openssh.com\ *|sk-ecdsa-sha2-nistp256@openssh.com\ *) ;;
      *) badline=1 ;;
    esac
  done < "$KEYS.tmp"
  if [ "$badline" = 1 ]; then rm -f "$KEYS.tmp"; echo "invalid: baris key harus polos (ssh-ed25519/ssh-rsa/ecdsa ...)"; exit 1; fi
  mv "$KEYS.tmp" "$KEYS"
  chmod 600 "$KEYS"
  echo ok
}

load_conf
case "$1" in
  start|restart) rm -f "$STOPPED"; ensure_sup; stop_proc; start_proc ;;
  stop) touch "$STOPPED"; stop_proc ;;
  status) status ;;
  log) tail -n 60 "$LOG" 2>/dev/null ;;
  supervise) supervise ;;
  teardown) s=$(cat "$SUPF" 2>/dev/null); [ -n "$s" ] && kill "$s" 2>/dev/null; rm -f "$SUPF"; stop_proc; fw_clear ;;
  keys-get) cat "$KEYS" 2>/dev/null ;;
  keys-set) keys_set "$2" ;;
  conf-set) conf_set "$2" "$3" ;;
  *) echo "usage: sshvpn.sh start|stop|restart|status|log|keys-get|keys-set <b64>|conf-set <KEY> <VAL>"; exit 1 ;;
esac
