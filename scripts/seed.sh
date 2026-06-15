#!/usr/bin/env bash
# Seed Firestore from scripts/data/ (or regenerate + upload).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/scripts"

if [[ ! -d ".venv" ]]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
pip install -q -r requirements.txt

python3 generate_seed_data.py
python3 seed_firestore.py --year 2026
python3 seed_firestore.py --year 2025
python3 seed_firestore.py --year 2024
