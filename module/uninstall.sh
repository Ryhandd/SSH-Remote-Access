#!/system/bin/sh
MODDIR=${0%/*}
sh "$MODDIR/sshvpn.sh" teardown
rm -rf /data/adb/sshvpn
