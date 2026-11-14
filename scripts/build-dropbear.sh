#!/usr/bin/env bash
# Build dropbear + dropbearkey + scp untuk Android arm64 (dynamic, link ke bionic) pakai NDK.
# Hasil: module/bin/{dropbear,dropbearkey,scp}
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER="${DROPBEAR_VERSION:-2025.88}"
API="${ANDROID_API:-26}"
NDK="${ANDROID_NDK_LATEST_HOME:-${ANDROID_NDK_HOME:-}}"
[ -n "$NDK" ] || { echo "ANDROID_NDK_LATEST_HOME / ANDROID_NDK_HOME belum diset" >&2; exit 1; }

TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

curl -fsSL "https://matt.ucc.asn.au/dropbear/releases/dropbear-${VER}.tar.bz2" -o "$WORK/db.tar.bz2"
tar -xjf "$WORK/db.tar.bz2" -C "$WORK"
cd "$WORK/dropbear-${VER}"

cat > localoptions.h <<'EOF'
#undef DEFAULT_PATH
#define DEFAULT_PATH "/system/bin:/system/xbin:/vendor/bin:/data/adb/modules/sshvpn/bin:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin"
EOF

export CC="$TC/aarch64-linux-android${API}-clang"
export AR="$TC/llvm-ar" RANLIB="$TC/llvm-ranlib" STRIP="$TC/llvm-strip"

./configure --host=aarch64-linux-android --disable-zlib \
  --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx \
  --disable-lastlog --disable-loginfunc --disable-pututline --disable-pututxline
make -j"$(nproc)" PROGRAMS="dropbear dropbearkey scp"

mkdir -p "$ROOT/module/bin"
for b in dropbear dropbearkey scp; do
  "$STRIP" "$b"
  install -m 0755 "$b" "$ROOT/module/bin/$b"
done
ls -l "$ROOT/module/bin"
