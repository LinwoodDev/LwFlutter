#!/usr/bin/env bash
set -euo pipefail

case "$(uname -s)" in
  Linux*) default_platform="linux" ;;
  MINGW*|MSYS*|CYGWIN*) default_platform="windows" ;;
  Darwin*) default_platform="macos" ;;
  *) default_platform="" ;;
esac

case "$(uname -m)" in
  x86_64|amd64) default_arch="x64" ;;
  arm64|aarch64) default_arch="arm64" ;;
  *) default_arch="" ;;
esac

platform="$default_platform"
arch="$default_arch"
flutter_ref=""
build_root=".build/lwflutter-engine-verify"
patch_root="patches"
skip_sync=false

usage() {
  cat <<'USAGE'
Usage: scripts/verify_engine_build.sh [options]

Builds a LwFlutter local engine config using a persistent checkout and output
directory so build artifacts can be inspected or reused.

Options:
  --platform <linux|windows>  Platform to build. Defaults to the host platform.
  --arch <x64|arm64>          Target architecture. Defaults to the host architecture.
  --flutter-ref <ref>         Flutter tag/branch/SHA. Defaults to flutter.version.
  --build-root <path>         Persistent work directory. Defaults to .build/lwflutter-engine-verify.
  --patch-root <path>         Patch root directory. Defaults to patches.
  --skip-sync                 Skip gclient sync when dependencies are already present.
  -h, --help                  Show this help.

Examples:
  scripts/verify_engine_build.sh --platform linux --arch x64
  scripts/verify_engine_build.sh --platform linux --arch arm64 --skip-sync
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --platform)
      platform="$2"
      shift 2
      ;;
    --arch)
      arch="$2"
      shift 2
      ;;
    --flutter-ref)
      flutter_ref="$2"
      shift 2
      ;;
    --build-root)
      build_root="$2"
      shift 2
      ;;
    --patch-root)
      patch_root="$2"
      shift 2
      ;;
    --skip-sync)
      skip_sync=true
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

case "$platform/$arch" in
  linux/x64)
    engine_out="linux_release_x64"
    gn_args='["--runtime-mode","release","--no-stripped","--no-lto","--xcode-symlinks","--target-dir","linux_release_x64"]'
    drone_os="Linux"
    ;;
  linux/arm64)
    engine_out="linux_release_arm64"
    gn_args='["--linux","--linux-cpu","arm64","--runtime-mode","release","--no-stripped","--no-lto","--xcode-symlinks","--target-dir","linux_release_arm64"]'
    drone_os="Linux"
    ;;
  windows/x64)
    engine_out="windows_release_x64"
    gn_args='["--runtime-mode","release","--no-stripped","--no-lto","--xcode-symlinks","--target-dir","windows_release_x64"]'
    drone_os="Windows-10"
    ;;
  windows/arm64)
    engine_out="windows_release_arm64"
    gn_args='["--runtime-mode","release","--windows-cpu","arm64","--no-stripped","--no-lto","--xcode-symlinks","--target-dir","windows_release_arm64"]'
    drone_os="Windows-10"
    ;;
  *)
    echo "Unsupported or undetected platform/arch: ${platform:-unknown}/${arch:-unknown}" >&2
    echo "Pass --platform <linux|windows> and --arch <x64|arm64> explicitly." >&2
    exit 1
    ;;
esac

build_root_abs="$(mkdir -p "$build_root" && cd "$build_root" && pwd)"
flutter_dir="$build_root_abs/flutter"
depot_tools_dir="$build_root_abs/depot_tools"
materialized_dir="$build_root_abs/materialized-patches"

if [ ! -d "$flutter_dir/.git" ]; then
  git clone https://github.com/flutter/flutter.git "$flutter_dir"
fi

git -C "$flutter_dir" fetch --tags origin
git -C "$flutter_dir" checkout --detach "$flutter_ref"
git -C "$flutter_dir" reset --hard
git -C "$flutter_dir" clean -fd -e engine/src/out

"$repo_root/scripts/materialize_patches.sh" "$patch_root" "$materialized_dir"
"$repo_root/scripts/apply_patches.sh" "$flutter_dir" "$materialized_dir" "$build_root_abs/apply-work" apply

if [ ! -d "$depot_tools_dir/.git" ]; then
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$depot_tools_dir"
fi

export PATH="$flutter_dir/bin:$depot_tools_dir:$PATH"
export DEPOT_TOOLS_WIN_TOOLCHAIN="${DEPOT_TOOLS_WIN_TOOLCHAIN:-0}"

flutter --version

cp "$flutter_dir/engine/scripts/standard.gclient" "$flutter_dir/.gclient"

if [ "$skip_sync" != true ]; then
  (cd "$flutter_dir" && gclient sync -D)
fi

config_file="$flutter_dir/engine/src/flutter/ci/builders/local_engine.json"
config_name="$platform/$engine_out"

jq \
  --arg name "$config_name" \
  --arg engine_out "$engine_out" \
  --arg platform "$platform" \
  --arg drone_os "$drone_os" \
  --argjson gn "$gn_args" \
  '.builds |= map(select(.name != $name)) + [{
    "cas_archive": false,
    "drone_dimensions": ["os=" + $drone_os, "device_type=none"],
    "gclient_variables": {
      "download_android_deps": false,
      "download_jdk": false
    },
    "gn": $gn,
    "name": $name,
    "description": "Builds a release mode LwFlutter engine.",
    "ninja": {"config": $engine_out, "targets": []}
  }]' "$config_file" > "$build_root_abs/local_engine.json"
mv "$build_root_abs/local_engine.json" "$config_file"

(cd "$flutter_dir/engine/src/flutter" && dart tools/engine_tool/bin/et.dart build --config "$engine_out")

echo "Build completed: $flutter_dir/engine/src/out/$engine_out"
