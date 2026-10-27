#!/usr/bin/env bash
# scripts/patch_pdfrx.sh
# Fixes upstream null-safety operator omission in pdfrx_engine-0.4.4
# (lines 380 and 382 in pdf_file_cache.dart)

set -e

PUB_CACHE_DIR="${PUB_CACHE:-$HOME/.pub-cache}"
echo "Checking for pdfrx_engine in $PUB_CACHE_DIR and other cache paths..."

for dir in "$PUB_CACHE_DIR" "$HOME/.pub-cache" /opt/hostedtoolcache; do
  if [ -d "$dir" ]; then
    find "$dir" -name "pdf_file_cache.dart" 2>/dev/null | while read -r file; do
      if [ -f "$file" ]; then
        echo "Patching $file..."
        sed -i 's/cache\.blockSize/cache!\.blockSize/g' "$file" || true
        sed -i 's/await cache\.read/await cache!\.read/g' "$file" || true
      fi
    done
  fi
done

echo "Done patching pdfrx_engine."
