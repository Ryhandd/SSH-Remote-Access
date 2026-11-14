#!/system/bin/sh
MODDIR=${0%/*}
sh "$MODDIR/sshvpn.sh" restart
sh "$MODDIR/sshvpn.sh" status
echo
sh "$MODDIR/sshvpn.sh" log | tail -n 5
