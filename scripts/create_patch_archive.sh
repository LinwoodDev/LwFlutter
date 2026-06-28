#!/usr/bin/env bash
set -euo pipefail

output="${1:-lwflutter-patches.zip}"
work_dir="$(mktemp -d)"

scripts/materialize_patches.sh patches "$work_dir/patches"
cp flutter.version "$work_dir/flutter.version"
(cd "$work_dir" && 7z a "$output" patches flutter.version)
mv "$work_dir/$output" "$output"
