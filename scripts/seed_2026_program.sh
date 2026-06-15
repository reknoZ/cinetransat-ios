#!/usr/bin/env bash
# Generate 2026 programme + upload to Firestore (keeps 2025 if already seeded).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/scripts"

if [[ ! -d ".venv" ]]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
pip install -q -r requirements.txt

python3 seed_2026_program.py "$@"
