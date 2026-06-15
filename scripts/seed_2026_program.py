#!/usr/bin/env python3
"""
Generate the 2026 season (fictional programme for App Store review) and upload to Firestore.

Keeps seasons/2025.json if present. Sets publicConfig.currentSeasonYear to 2026.

Usage (from repo root):
  python3 scripts/seed_2026_program.py
  python3 scripts/seed_2026_program.py --dry-run
  python3 scripts/seed_2026_program.py --generate-only   # write JSON only, no Firebase
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
DATA_DIR = SCRIPT_DIR / "data"
SEASONS_DIR = DATA_DIR / "seasons"

sys.path.insert(0, str(SCRIPT_DIR))

from generate_seed_data import build_public_config_document, write_json  # noqa: E402
from season_template import TEMPLATE_2026, build_season_document  # noqa: E402

CURRENT_SEASON_YEAR = 2026


def main() -> None:
    parser = argparse.ArgumentParser(description="Add 2026 CinéTransat programme to Firestore")
    parser.add_argument("--dry-run", action="store_true", help="Validate and print plan without uploading")
    parser.add_argument("--generate-only", action="store_true", help="Write JSON files only")
    parser.add_argument("--credentials", type=Path, default=SCRIPT_DIR / "serviceAccountKey.json")
    args = parser.parse_args()

    season_path = SEASONS_DIR / f"{CURRENT_SEASON_YEAR}.json"
    config_path = DATA_DIR / "public_config.json"

    doc_2026 = build_season_document(CURRENT_SEASON_YEAR, TEMPLATE_2026)
    config = build_public_config_document(CURRENT_SEASON_YEAR)

    write_json(season_path, doc_2026)
    write_json(config_path, config)

    screenings = sum(len(w["screenings"]) for w in doc_2026["weeks"])
    print(f"Wrote {season_path} ({len(doc_2026['weeks'])} weeks, {screenings} screenings, no cancellations)")
    print(f"Wrote {config_path} (currentSeasonYear={CURRENT_SEASON_YEAR})")

    if args.generate_only:
        return

    seed_cmd = [
        sys.executable,
        str(SCRIPT_DIR / "seed_firestore.py"),
        "--all-seasons",
        "--public-config",
        str(config_path),
    ]
    if args.dry_run:
        seed_cmd.append("--dry-run")

    seed_cmd.extend(["--credentials", str(args.credentials)])

    print("Uploading to Firestore…")
    subprocess.run(seed_cmd, cwd=REPO_ROOT, check=True)
    print("Done. In Firebase you should have seasons/2025, seasons/2026, and currentSeasonYear=2026.")


if __name__ == "__main__":
    main()
