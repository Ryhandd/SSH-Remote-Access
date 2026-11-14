#!/system/bin/sh
# Dipanggil installer Magisk / KernelSU / KernelSU Next / APatch.
# Modul ini tanpa overlay mount: hanya script + binary, jadi tidak butuh metamodule.

ui_print "======================================"
ui_print "  ⚡ SSH Remote Access by Ryhandd ⚡  "
ui_print "======================================"
ui_print "- Versi  : $(sed -n 's/^version=//p' "$MODPATH/module.prop")"
ui_print "- Author : $(sed -n 's/^author=//p' "$MODPATH/module.prop")"
ui_print "- Web    : rayhand.vercel.app"

A="${ARCH:-$(getprop ro.product.cpu.abi)}"
case "$A" in
  arm64*) ;;
  *) abort "! Hanya arm64 (terdeteksi: $A)" ;;
esac

if [ ! -f "$MODPATH/dropbear" ]; then
  ui_print "! PERINGATAN: binary dropbear tidak ada di zip ini."
  ui_print "! Pakai zip dari GitHub Releases agar SSH berfungsi."
fi

D=/data/adb/sshvpn
mkdir -p "$D/ssh"
chmod 700 "$D" "$D/ssh"
[ -f "$D/sshvpn.conf" ] || cp "$MODPATH/sshvpn.conf" "$D/sshvpn.conf"
chmod 600 "$D/sshvpn.conf"

for f in /sdcard/sshvpn_authorized_keys /storage/emulated/0/sshvpn_authorized_keys; do
  if [ -f "$f" ] && [ ! -s "$D/ssh/authorized_keys" ]; then
    r=$(sh "$MODPATH/sshvpn.sh" keys-set "$(base64 "$f" | tr -d '\n')")
    ui_print "- Import public key dari $f: $r"
    break
  fi
done

set_perm_recursive "$MODPATH" 0 0 0755 0644
for s in sshvpn.sh service.sh action.sh uninstall.sh dropbear dropbearkey scp; do
  [ -f "$MODPATH/$s" ] && set_perm "$MODPATH/$s" 0 0 0755
done

ui_print "- Pasang app Tailscale atau WireGuard, lalu connect."
ui_print "- Taruh public key di /sdcard/sshvpn_authorized_keys (atau isi via WebUI) lalu reboot."
ui_print "- Login: ssh root@<ip-vpn> -p 2222"

ui_print "- Membuka website portofolio..."
am start --user 0 -a android.intent.action.VIEW -d "https://rayhand.vercel.app" >/dev/null 2>&1

ui_print "- Selesai! Silakan Reboot."
