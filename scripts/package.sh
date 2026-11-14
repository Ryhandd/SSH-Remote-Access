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

mkdir -p "$OUT"
rm -f "$OUT/sshvpn-${TAG}.zip"
(cd "$STAGE" && zip -r9q "$OUT/sshvpn-${TAG}.zip" .)
echo "$OUT/sshvpn-${TAG}.zip"
