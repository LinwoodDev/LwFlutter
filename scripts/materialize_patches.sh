#!/usr/bin/env bash
set -euo pipefail

source_dir="${1:-patches}"
out_dir="${2:-materialized-patches}"

rm -rf "$out_dir"
mkdir -p "$out_dir"

is_url_backed_patch() {
  local file="$1"
  local first
  first="$(grep -vE '^\s*(#|$)' "$file" | head -n 1 | tr -d '[:space:]' || true)"
  [[ "$first" =~ ^https?:// ]]
}

patch_url() {
  grep -vE '^\s*(#|$)' "$1" | head -n 1 | tr -d '[:space:]'
}

if [ -d "$source_dir" ]; then
  while IFS= read -r -d '' patch; do
    rel="${patch#$source_dir/}"
    mkdir -p "$out_dir/$(dirname "$rel")"

    if is_url_backed_patch "$patch"; then
      url="$(patch_url "$patch")"
      echo "Downloading $url -> $out_dir/$rel"
      curl --fail --location --silent --show-error "$url" --output "$out_dir/$rel"
    else
      cp "$patch" "$out_dir/$rel"
    fi
  done < <(find "$source_dir" -type f -name '*.patch' -print0 | sort -z)
fi

count="$(find "$out_dir" -type f -name '*.patch' | wc -l | tr -d '[:space:]')"
echo "Materialized $count patch file(s) into $out_dir"
