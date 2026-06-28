#!/usr/bin/env bash
set -euo pipefail

flutter_root="${1:-}"
patch_root="${2:-patches}"
work_dir="${3:-}"
mode="${4:-apply}"

if [ -z "$flutter_root" ]; then
  echo "Usage: scripts/apply_patches.sh <flutter-root> [patch-root] [work-dir] [apply|check]" >&2
  exit 1
fi

if [ -z "$work_dir" ]; then
  work_dir="$(mktemp -d)"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
materialized="$work_dir/materialized-patches"
"$script_dir/materialize_patches.sh" "$patch_root" "$materialized"

cd "$flutter_root"
shopt -s globstar nullglob
patches=("$materialized"/**/*.patch)

if [ ${#patches[@]} -eq 0 ]; then
  echo "No patches found in $patch_root"
  exit 0
fi

for patch in "${patches[@]}"; do
  echo "Applying $patch"
  if grep -qE '^From [0-9a-f]{40} Mon Sep 17 00:00:00 2001$' "$patch"; then
    if [ "$mode" = "check" ]; then
      git am --3way --keep-cr "$patch"
      git am --abort || true
    else
      git am --3way --keep-cr "$patch"
    fi
  else
    if [ "$mode" = "check" ]; then
      git apply --3way --check "$patch"
    else
      git apply --3way "$patch"
    fi
  fi
done
