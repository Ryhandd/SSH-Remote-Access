#!/bin/sh
# Harness: uji logika status() sshvpn.sh dengan data & binary tiruan.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d)
mkdir -p "$T/bin" "$T/data/ssh"
export PATH="$T/bin:$PATH"

# --- binary tiruan ---
cat > "$T/bin/ip" <<EOF
#!/bin/sh
if [ "\$1" = "-4" ]; then
  for a in "\$@"; do
    [ "\$a" = "tun1" ] && echo "5: tun1    inet 100.73.20.92/32 scope global tun1"
  done
fi
exit 0
EOF
cat > "$T/bin/dropbear" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$T/bin/dropbearkey" <<'EOF'
#!/bin/sh
echo "Fingerprint: SHA256:fakefingerprint"
EOF
cat > "$T/bin/scp" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$T/bin/iptables" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$T/bin/"*

printf 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAItest laptop\n' > "$T/data/ssh/authorized_keys"
cat > "$T/data/sshvpn.conf" <<'EOF'
PORT="2222"
IFACES="tun1 tailscale0"
BIND="iface"
IDLE="600"
ALLOW_FWD="0"
EOF

sed -e "s|^DATA=/data/adb/sshvpn|DATA=\"$T/data\"|" -e "s|^BIN=.*|BIN=\"$T/bin\"|" \
  "$ROOT/module/sshvpn.sh" > "$T/sshvpn.sh"

pass=0; fail=0
chk() { # chk <label> <expected-substr>
  out=$(sh "$T/sshvpn.sh" status)
  if echo "$out" | grep -qF -- "$2"; then
    echo "PASS  $1"
    pass=$((pass+1))
  else
    echo "FAIL  $1"
    echo "      harap: $2"
    echo "$out" | sed 's/^/      /'
    fail=$((fail+1))
  fi
}

chk "bins ok saat lengkap"            "bins=ok"
chk "deteksi IP VPN tun1"             "up=tun1=100.73.20.92"
chk "iface aktif + key -> siap start" "reason=siap start (jalankan: sshvpn.sh restart)"

rm -f "$T/bin/dropbear"
chk "deteksi dropbear hilang"         "bins=hilang:dropbear"
chk "alasan binary tidak lengkap"     "reason=binary tidak lengkap:dropbear - pasang zip dari GitHub Releases"

printf '#!/bin/sh\nexit 0\n' > "$T/bin/dropbear"; chmod +x "$T/bin/dropbear"
: > "$T/data/ssh/authorized_keys"
chk "deteksi keys kosong"             "keys=0"
chk "alasan keys kosong"              "reason=authorized_keys kosong"

printf 'ssh-ed25519 AAAAtest\n' > "$T/data/ssh/authorized_keys"
IFACES=x sh -c "true"
touch "$T/data/stopped"
chk "alasan dihentikan manual"        "reason=dihentikan manual"
rm -f "$T/data/stopped"

printf 'BIND="iface"\nIFACES="tun9"\nPORT="2222"\nIDLE="600"\nALLOW_FWD="0"\n' > "$T/data/sshvpn.conf"
chk "iface tidak ada -> tunggu VPN"   "reason=menunggu interface VPN (tun9) aktif"

rm -rf "$T"
echo
echo "hasil: $pass lulus, $fail gagal"
[ "$fail" -eq 0 ]