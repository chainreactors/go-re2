#!/bin/bash
# Build RE2 + CRE2 as a single static archive for the current platform.
#
# Usage:
#   ./scripts/build-static.sh [PLATFORM]
#
# Requires: zig (preferred) or g++/gcc, ar, curl

set -euo pipefail

RE2_VERSION="${RE2_VERSION:-2023-03-01}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRE2_DIR="$REPO_ROOT/internal/cre2"

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)  HOST_PLATFORM="linux_amd64" ;;
    Linux-aarch64) HOST_PLATFORM="linux_arm64" ;;
    Darwin-x86_64) HOST_PLATFORM="darwin_amd64" ;;
    Darwin-arm64)  HOST_PLATFORM="darwin_arm64" ;;
    MINGW*|MSYS*)  HOST_PLATFORM="windows_amd64" ;;
    *)             HOST_PLATFORM="unknown" ;;
esac

PLATFORM="${1:-$HOST_PLATFORM}"
OUTPUT_DIR="$CRE2_DIR/lib/$PLATFORM"

# Use zig cc to pin glibc version — eliminates __isoc23_* symbols and
# isoc23_compat.c entirely. Set NO_ZIG=1 to force system gcc/g++.
USE_ZIG=""
if command -v zig >/dev/null 2>&1 && [ -z "${NO_ZIG:-}" ]; then
    case "$PLATFORM" in
        linux_amd64)  ZIG_TARGET="x86_64-linux-gnu.2.17" ;;
        linux_arm64)  ZIG_TARGET="aarch64-linux-gnu.2.17" ;;
        *)            ZIG_TARGET="" ;;
    esac
    if [ -n "$ZIG_TARGET" ]; then
        CXX="${CXX:-zig c++ -target $ZIG_TARGET}"
        CC="${CC:-zig cc -target $ZIG_TARGET}"
        AR="${AR:-zig ar}"
        USE_ZIG=1
    fi
fi
CXX="${CXX:-g++}"
CC="${CC:-gcc}"
AR="${AR:-ar}"

echo "Building RE2 $RE2_VERSION static archive for $PLATFORM"
echo "  CXX=$CXX"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

curl -sL "https://github.com/google/re2/archive/refs/tags/${RE2_VERSION}.tar.gz" | tar xz -C "$TMPDIR"
RE2_SRC="$TMPDIR/re2-${RE2_VERSION}"

mkdir -p "$TMPDIR/build"
for f in "$RE2_SRC"/re2/*.cc "$RE2_SRC"/util/rune.cc "$RE2_SRC"/util/strutil.cc; do
    [ -f "$f" ] || continue
    OBJ="$TMPDIR/build/$(basename "$f" .cc).o"
    $CXX -std=c++17 -O2 -DNDEBUG -fPIC -I"$RE2_SRC" -c "$f" -o "$OBJ"
done

$CXX -std=c++17 -O2 -DNDEBUG -fPIC \
    -I"$RE2_SRC" -I"$CRE2_DIR" \
    -c "$CRE2_DIR/cre2.cpp" \
    -o "$TMPDIR/build/cre2.o"

# Without zig, system gcc on glibc >=2.38 emits __isoc23_strtol calls.
# Bundle weak fallbacks so the archive still links on older glibc.
if [ -z "$USE_ZIG" ] && { [ "$PLATFORM" = "linux_amd64" ] || [ "$PLATFORM" = "linux_arm64" ]; }; then
    $CC -O2 -fPIC -c "$CRE2_DIR/isoc23_compat.c" -o "$TMPDIR/build/isoc23_compat.o"
fi

mkdir -p "$OUTPUT_DIR"
$AR rcs "$OUTPUT_DIR/libre2_cre2.a" "$TMPDIR"/build/*.o

cp "$RE2_SRC/LICENSE" "$OUTPUT_DIR/RE2_LICENSE"

echo "Built: $OUTPUT_DIR/libre2_cre2.a ($(du -h "$OUTPUT_DIR/libre2_cre2.a" | cut -f1))"
