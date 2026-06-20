#!/usr/bin/env bash
# Build script for k6a-tune KernelSU module
set -e

SRC="/home/x/Downloads/k6a-tune"
OUT="/home/x/Downloads/k6a-tune.zip"

cd "$SRC"
rm -f "$OUT"

find . -type f \
  ! -path './.git/*' \
  ! -path '*.swp' \
  ! -path '*.swo' \
  ! -path '*~' \
  | sed 's|^\./||' \
  | sort \
  | zip -q "$OUT" -@

echo "Built: $OUT"
echo "Size: $(wc -c < "$OUT") bytes"
