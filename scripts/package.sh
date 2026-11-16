#!/usr/bin/env bash
# Pakai: package.sh <tag> <versionCode> <owner/repo>
#   -> dist/SSH-Remote-Access-<tag>.zip  (butuh module/{dropbear,dropbearkey,scp})
# ALLOW_NO_BIN=1 -> dist/SSH-Remote-Access-<tag>-nobin.zip (tes install tanpa binary)
set -euo pipefail
TAG="$1"; CODE="$2"; REPO="$3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

NEED="module.prop customize.sh service.sh action.sh uninstall.sh sshvpn.sh sshvpn.conf webroot/index.html"
SUFFIX=""
NEED="$NEED dropbear dropbearkey scp"
for b in dropbear dropbearkey scp; do
  [ -f "$ROOT/module/$b" ] || {
    echo "ERROR: module/$b belum ada." >&2
    echo "Jalankan dulu: bash scripts/build-dropbear.sh (butuh Android NDK)." >&2
    echo "Zip rilis WAJIB berisi binary, kalau tidak SSH tidak jalan." >&2
    exit 1
  }
done

cp -a "$ROOT/module/." "$STAGE/"
rm -f "$STAGE/.gitkeep"
sed -i -e "s|^version=.*|version=${TAG}|" \
       -e "s|^versionCode=.*|versionCode=${CODE}|" \
       -e "s|__REPO__|${REPO}|" "$STAGE/module.prop"

ZIP="$OUT/SSH-Remote-Access-${TAG}${SUFFIX}.zip"
mkdir -p "$OUT"
rm -f "$ZIP"
(cd "$STAGE" && zip -r9qX "$ZIP" . -x '.*')

# Guard: file penting HARUS ada di root zip (tanpa folder pembungkus)
LIST="$(unzip -Z1 "$ZIP")"
for f in $NEED; do
  echo "$LIST" | grep -qx "$f" || { echo "zip salah: $f tidak ada di root" >&2; exit 1; }
done
echo "$ZIP"
