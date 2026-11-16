#!/system/bin/sh
MODDIR=${0%/*}
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 3; done
rm -f /data/adb/sshvpn/stopped /data/adb/sshvpn/supervisor.pid /data/adb/sshvpn/dropbear.pid /data/adb/sshvpn/bound
nohup sh "$MODDIR/sshvpn.sh" supervise >/dev/null 2>&1 &
# Fallback: pastikan supervisor hidup walau proses awal mati
sleep 20
grep -q sshvpn.sh "/proc/$(cat /data/adb/sshvpn/supervisor.pid 2>/dev/null)/cmdline" 2>/dev/null \
  || nohup sh "$MODDIR/sshvpn.sh" supervise >/dev/null 2>&1 &
