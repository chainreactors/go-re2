#!/bin/bash
# Build RE2 + CRE2 as a single static archive for the current platform.
#
# Usage:
#   ./scripts/build-static.sh [PLATFORM]
#
# Requires: g++ (or CXX), ar, curl/git

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

CXX="${CXX:-g++}"
AR="${AR:-ar}"

echo "Building RE2 $RE2_VERSION static archive for $PLATFORM"

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

# glibc compat: on glibc >=2.38, gcc emits __isoc23_strtol calls; bundle weak
# fallbacks so the archive links on older glibc too.
if [ "$PLATFORM" = "linux_amd64" ] || [ "$PLATFORM" = "linux_arm64" ]; then
    ${CC:-gcc} -O2 -fPIC -c "$CRE2_DIR/isoc23_compat.c" -o "$TMPDIR/build/isoc23_compat.o"
fi

mkdir -p "$OUTPUT_DIR"
$AR rcs "$OUTPUT_DIR/libre2_cre2.a" "$TMPDIR"/build/*.o

cp "$RE2_SRC/LICENSE" "$OUTPUT_DIR/RE2_LICENSE"

echo "Built: $OUTPUT_DIR/libre2_cre2.a ($(du -h "$OUTPUT_DIR/libre2_cre2.a" | cut -f1))"
