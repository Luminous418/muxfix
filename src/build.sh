#!/bin/bash
# Builds MuxFix.kext with the Command Line Tools only.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/MuxFix.kext"
KHDR="$(xcrun --show-sdk-path)/System/Library/Frameworks/Kernel.framework/Headers"

echo "== building MuxFix.kext =="
mkdir -p "$OUT/Contents/MacOS"

xcrun clang++ -arch x86_64 -fapple-kext -mkernel -nostdinc -I"$KHDR" \
  -DKERNEL -DKERNEL_PRIVATE -DDRIVER_PRIVATE -DAPPLE -DNeXT \
  -std=c++17 -fno-rtti -fno-exceptions -fno-builtin -fno-common \
  -Wall -Wno-unused-parameter -O2 -c "$HERE/MuxFix.cpp" -o "$HERE/MuxFix.o"

xcrun clang++ -arch x86_64 -fapple-kext -nostdlib -Xlinker -kext \
  "$HERE/MuxFix.o" -o "$OUT/Contents/MacOS/MuxFix" 2>/dev/null

rm -rf "$OUT/Contents/_CodeSignature"
codesign -f -s - "$OUT"
codesign --verify "$OUT"

echo "== done =="
echo "kext: $OUT"
echo "sha256: $(shasum -a 256 "$OUT/Contents/MacOS/MuxFix" | cut -d' ' -f1)"
