#!/usr/bin/env bash
set -euo pipefail

create_branch=false
run_test=false

while [ $# -gt 0 ]; do
  case "$1" in
    --test)
      run_test=true
      shift
      ;;
    --branch)
      create_branch=true
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/update_to_latest_stable.sh [--test] [--branch]

Updates flutter.version to the latest Flutter stable version.

Options:
  --test    Run scripts/test_patches_locally.sh against the new version.
  --branch  Create/switch to update/flutter-stable-<version> before editing.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

json="$(curl --fail --location --silent --show-error https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)"
stable_hash="$(jq -r '.current_release.stable' <<<"$json")"
latest="$(jq -r --arg hash "$stable_hash" '.releases[] | select(.hash == $hash) | .version' <<<"$json")"

if [ -z "$latest" ] || [ "$latest" = "null" ]; then
  echo "Could not resolve latest Flutter stable version" >&2
  exit 1
fi

current="$(head -n 1 flutter.version | tr -d '[:space:]' || true)"

if [ "$current" = "$latest" ]; then
  echo "flutter.version is already at latest stable: $latest"
  exit 0
fi

if [ "$create_branch" = true ]; then
  git switch -C "update/flutter-stable-$latest"
fi

printf '%s\n' "$latest" > flutter.version
echo "Updated flutter.version: $current -> $latest"

if [ "$run_test" = true ]; then
  scripts/test_patches_locally.sh --flutter-ref "$latest"
fi
