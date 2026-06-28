#!/usr/bin/env bash
set -euo pipefail

flutter_root="${1:-}"
patch_root="${2:-patches}"

if [ -z "$flutter_root" ]; then
  echo "Usage: scripts/apply_patches.sh <flutter-root> [patch-root]" >&2
  exit 1
fi

cd "$flutter_root"
shopt -s globstar nullglob
patches=("$patch_root"/**/*.patch)

if [ ${#patches[@]} -eq 0 ]; then
  echo "No patches found in $patch_root"
  exit 0
fi

for patch in "${patches[@]}"; do
  echo "Applying $patch"
  git am --3way "$patch"
done
