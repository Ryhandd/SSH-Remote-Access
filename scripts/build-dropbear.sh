#!/usr/bin/env bash
# Build dropbear + dropbearkey + scp untuk Android arm64 (dynamic, link ke bionic) pakai NDK.
# Hasil: module/{dropbear,dropbearkey,scp}
#
# Env opsional:
#   DROPBEAR_VERSION  (default 2026.94)
#   ANDROID_API       (default 26)
#   ANDROID_NDK_HOME  / ANDROID_NDK_LATEST_HOME / ANDROID_NDK_ROOT  (kalau kosong, dicari otomatis)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VER="${DROPBEAR_VERSION:-2026.94}"
API="${ANDROID_API:-26}"
NDK_ZIP_URL="${NDK_ZIP_URL:-https://dl.google.com/android/repository/android-ndk-r27c-linux.zip}"

WORK="$(mktemp -d)"
LOGDIR="${BUILD_LOG_DIR:-$WORK/logs}"
mkdir -p "$LOGDIR"
trap 'rm -rf "$WORK"' EXIT

# ---------- 1. cari NDK ----------
find_ndk() {
  local c
  for c in "${ANDROID_NDK_LATEST_HOME:-}" "${ANDROID_NDK_HOME:-}" "${ANDROID_NDK_ROOT:-}" "${ANDROID_NDK:-}"; do
    [ -n "$c" ] && [ -d "$c/toolchains/llvm/prebuilt" ] && { printf '%s\n' "$c"; return 0; }
  done
  for c in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" /usr/local/lib/android/sdk /opt/android-sdk "$HOME/Android/Sdk"; do
    [ -n "$c" ] || continue
    for c2 in "$c"/ndk/*; do
      [ -d "$c2/toolchains/llvm/prebuilt" ] && { printf '%s\n' "$c2"; return 0; }
    done
  done
  return 1
}

NDK="$(find_ndk || true)"
if [ -z "$NDK" ]; then
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) ;;
    *)
      echo "ERROR: NDK tidak ditemukan dan auto-download hanya untuk Linux x86_64." >&2
      echo "       Set ANDROID_NDK_HOME ke folder NDK." >&2
      exit 1
      ;;
  esac
  echo "== NDK tidak ditemukan, mengunduh r27c =="
  curl -fsSL "$NDK_ZIP_URL" -o "$WORK/ndk.zip"
  unzip -q "$WORK/ndk.zip" -d "$WORK"
  NDK="$WORK/android-ndk-r27c"
fi
echo "== NDK: $NDK =="

HOSTTAG="$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m)"
TC="$NDK/toolchains/llvm/prebuilt/$HOSTTAG/bin"
if [ ! -d "$TC" ]; then
  TC="$(find "$NDK/toolchains/llvm/prebuilt" -maxdepth 2 -type d -name bin | head -n1)"
fi
[ -d "$TC" ] || { echo "ERROR: toolchain bin tidak ditemukan di $NDK" >&2; exit 1; }
echo "== toolchain: $TC =="

CC_BIN="$TC/aarch64-linux-android${API}-clang"
[ -x "$CC_BIN" ] || {
  echo "ERROR: compiler tidak ada: $CC_BIN" >&2
  echo "Tersedia:" >&2
  ls "$TC" | grep -E '^aarch64-linux-android[0-9]+-clang$' | head -n 20 >&2
  exit 1
}

# ---------- 2. unduh source ----------
SRC_URL="https://matt.ucc.asn.au/dropbear/releases/dropbear-${VER}.tar.bz2"
echo "== unduh $SRC_URL =="
curl -fsSL "$SRC_URL" -o "$WORK/db.tar.bz2"
tar -xjf "$WORK/db.tar.bz2" -C "$WORK"
cd "$WORK/dropbear-${VER}"

cat > localoptions.h <<'EOF'
#undef DEFAULT_PATH
#define DEFAULT_PATH "/system/bin:/system/xbin:/vendor/bin:/product/bin:/data/adb/modules/sshvpn:/data/adb/magisk:/data/adb/ksu/bin:/data/adb/ap/bin"
EOF

export CC="$CC_BIN"
export AR="$TC/llvm-ar" RANLIB="$TC/llvm-ranlib" STRIP="$TC/llvm-strip"
export CFLAGS="-O2 -fPIE"
export LDFLAGS="-pie"

# ---------- 3. configure ----------
echo "== configure =="
if ! ./configure --host=aarch64-linux-android \
      --disable-zlib \
      --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx \
      --disable-lastlog --disable-loginfunc --disable-pututline --disable-pututxline \
      > "$LOGDIR/configure.log" 2>&1; then
  echo "ERROR: configure gagal. 40 baris terakhir:" >&2
  tail -n 40 "$LOGDIR/configure.log" >&2
  exit 1
fi

# ---------- 4. build ----------
echo "== build =="
if ! make -j"$(nproc 2>/dev/null || echo 2)" PROGRAMS="dropbear dropbearkey scp" > "$LOGDIR/make.log" 2>&1; then
  echo "ERROR: make gagal. 60 baris terakhir:" >&2
  tail -n 60 "$LOGDIR/make.log" >&2
  exit 1
fi

# ---------- 5. pasang ke module/ ----------
for b in dropbear dropbearkey scp; do
  [ -f "$b" ] || { echo "ERROR: binary $b tidak dihasilkan" >&2; exit 1; }
  "$STRIP" "$b"
  install -m 0755 "$b" "$ROOT/module/$b"
  file "$b" 2>/dev/null | sed 's/^/   /' || true
done

echo "== selesai =="
ls -l "$ROOT/module/dropbear" "$ROOT/module/dropbearkey" "$ROOT/module/scp"