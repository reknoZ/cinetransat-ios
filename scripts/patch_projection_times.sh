#!/usr/bin/env bash
# Patch projection start times on seasons/2026 in Firestore (startsAt only).
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/patch_projection_times.py "$@"
