#!/usr/bin/env bash
# Pakai: package.sh <tag> <versionCode> <owner/repo>  ->  dist/sshvpn-<tag>.zip
set -euo pipefail
TAG="$1"; CODE="$2"; REPO="$3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

[ -f "$ROOT/module/bin/dropbear" ] || { echo "module/bin/dropbear belum ada, jalankan build-dropbear.sh" >&2; exit 1; }

cp -a "$ROOT/module/." "$STAGE/"
rm -f "$STAGE/bin/.gitkeep"
sed -i -e "s|^version=.*|version=${TAG}|" \
       -e "s|^versionCode=.*|versionCode=${CODE}|" \
       -e "s|__REPO__|${REPO}|" "$STAGE/module.prop"

ZIP="$OUT/SSH-Remote-Access-${TAG}.zip"
mkdir -p "$OUT"
rm -f "$ZIP"
(cd "$STAGE" && zip -r9qX "$ZIP" .)

# Guard: module.prop dan customize.sh HARUS ada di root zip (tanpa folder pembungkus)
LIST="$(unzip -Z1 "$ZIP")"
for f in module.prop customize.sh service.sh bin/dropbear; do
  echo "$LIST" | grep -qx "$f" || { echo "zip salah: $f tidak ada di root" >&2; exit 1; }
done
echo "$ZIP"
