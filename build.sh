#!/usr/bin/env bash
# Build script for k6a-tune KernelSU module
set -e

SRC="/home/x/Downloads/k6a-tune"
OUT="/home/x/Downloads/k6a-tune.zip"

cd "$SRC"
rm -f "$OUT"

find . -type f | while read f; do
  f="${f#./}"
  case "$f" in
    *.swp|*.swo|*~) continue ;;
  esac
  printf '%s\n' "$f"
done | zip -q "$OUT" -@

echo "Built: $OUT"
echo "Size: $(wc -c < "$OUT") bytes"
