#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:-patches}"
out_dir="${2:-materialized-patches}"

rm -rf "$out_dir"
mkdir -p "$out_dir"

if [ -d "$source_dir" ]; then
  while IFS= read -r -d '' patch; do
    rel="${patch#$source_dir/}"
    mkdir -p "$out_dir/$(dirname "$rel")"
    cp "$patch" "$out_dir/$rel"
  done < <(find "$source_dir" -type f -name '*.patch' -print0 | sort -z)
fi

count="$(find "$out_dir" -type f -name '*.patch' | wc -l | tr -d '[:space:]')"
echo "Materialized $count patch file(s) into $out_dir"
