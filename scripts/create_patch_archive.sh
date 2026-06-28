#!/usr/bin/env bash
set -euo pipefail

output="${1:-lwflutter-patches.zip}"
7z a "$output" patches flutter.version
