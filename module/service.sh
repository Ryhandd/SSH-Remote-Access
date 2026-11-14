#!/system/bin/sh
MODDIR=${0%/*}
until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 3; done
rm -f /data/adb/sshvpn/stopped /data/adb/sshvpn/supervisor.pid /data/adb/sshvpn/dropbear.pid /data/adb/sshvpn/bound
nohup sh "$MODDIR/sshvpn.sh" supervise >/dev/null 2>&1 &
