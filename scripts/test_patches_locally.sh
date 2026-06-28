#!/usr/bin/env bash
set -euo pipefail

flutter_root=""
flutter_ref=""
patch_root="patches"
keep=false

usage() {
  cat <<'USAGE'
Usage: scripts/test_patches_locally.sh [options]

Tests whether all LwFlutter patches can be applied to the configured Flutter ref.

Options:
  --flutter-root <path>  Use an existing local Flutter checkout via git worktree.
  --flutter-ref <ref>    Flutter tag/branch/SHA to test. Defaults to flutter.version.
  --patch-root <path>    Patch root directory. Defaults to patches.
  --keep                Keep the temporary test checkout after the run.
  -h, --help            Show this help.

Examples:
  scripts/test_patches_locally.sh
  scripts/test_patches_locally.sh --flutter-ref 3.35.7
  scripts/test_patches_locally.sh --flutter-root ~/dev/flutter --flutter-ref 3.35.7
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --flutter-root)
      flutter_root="$2"
      shift 2
      ;;
    --flutter-ref)
      flutter_ref="$2"
      shift 2
      ;;
    --patch-root)
      patch_root="$2"
      shift 2
      ;;
    --keep)
      keep=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ -z "$flutter_ref" ]; then
  flutter_ref="$(head -n 1 flutter.version | tr -d '[:space:]')"
fi

if [ -z "$flutter_ref" ]; then
  echo "flutter.version is empty and --flutter-ref was not provided" >&2
  exit 1
fi

work_dir="$(mktemp -d)"
cleanup() {
  if [ "$keep" = true ]; then
    echo "Keeping test checkout at $work_dir"
  else
    if [ -n "$flutter_root" ] && [ -d "$work_dir/flutter" ]; then
      git -C "$flutter_root" worktree remove --force "$work_dir/flutter" >/dev/null 2>&1 || true
    fi
    rm -rf "$work_dir"
  fi
}
trap cleanup EXIT

if [ -n "$flutter_root" ]; then
  echo "Creating Flutter worktree from $flutter_root at ref $flutter_ref"
  git -C "$flutter_root" fetch --tags origin >/dev/null 2>&1 || true
  git -C "$flutter_root" worktree add --detach "$work_dir/flutter" "$flutter_ref"
else
  echo "Cloning flutter/flutter at ref $flutter_ref"
  git clone --depth 1 --branch "$flutter_ref" https://github.com/flutter/flutter.git "$work_dir/flutter"
fi

"$repo_root/scripts/materialize_patches.sh" "$patch_root" "$work_dir/materialized-patches"

cd "$work_dir/flutter"

ensure_git_identity() {
  if ! git config --get user.name >/dev/null; then
    git config user.name "GitHub Actions"
  fi

  if ! git config --get user.email >/dev/null; then
    git config user.email "actions@github.com"
  fi
}

ensure_git_identity

shopt -s globstar nullglob
patches=("$work_dir"/materialized-patches/**/*.patch)

if [ ${#patches[@]} -eq 0 ]; then
  echo "No patches found."
  exit 0
fi

for patch in "${patches[@]}"; do
  echo "Testing $patch"
  if grep -qE '^From [0-9a-f]{40} Mon Sep 17 00:00:00 2001$' "$patch"; then
    git am --3way --keep-cr --ignore-whitespace --no-gpg-sign "$patch"
  else
    git apply --3way "$patch"
  fi
done

echo "All patches applied successfully to Flutter $flutter_ref."
git status --short
