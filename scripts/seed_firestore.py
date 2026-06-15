#!/usr/bin/env python3
"""
Upload CinéTransat seasons and public config to Cloud Firestore.

Layout (schema v2):
  seasons/{year}     — full programme for that year (2025, 2024, …)
  cinetransat/publicConfig — site URLs + currentSeasonYear (default season in the app)

Usage:
  python3 scripts/seed_firestore.py
  python3 scripts/seed_firestore.py --year 2025
  python3 scripts/seed_firestore.py --all-seasons
  python3 scripts/seed_firestore.py --migrate-legacy-program
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_DATA_DIR = SCRIPT_DIR / "data"
SEASONS_DIR = DEFAULT_DATA_DIR / "seasons"
DEFAULT_CREDENTIALS = SCRIPT_DIR / "serviceAccountKey.json"

SEASONS_COLLECTION = "seasons"
PUBLIC_CONFIG_PATH = ("cinetransat", "publicConfig")
LEGACY_PROGRAM_PATH = ("cinetransat", "program")


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def validate_season(doc: dict) -> None:
    required = ("schemaVersion", "seasonYear", "weeks")
    for key in required:
        if key not in doc:
            raise ValueError(f"season document missing '{key}'")
    if not isinstance(doc["weeks"], list) or not doc["weeks"]:
        raise ValueError("season.weeks must be a non-empty array")
    year = doc["seasonYear"]
    if not isinstance(year, int):
        raise ValueError("seasonYear must be an integer")


def validate_public_config(doc: dict) -> None:
    if "schemaVersion" not in doc:
        raise ValueError("publicConfig document missing 'schemaVersion'")
    if doc.get("currentSeasonYear") is None and doc.get("seasonYear") is None:
        raise ValueError("publicConfig needs currentSeasonYear (or legacy seasonYear)")


def season_ref(db, year: int):
    return db.collection(SEASONS_COLLECTION).document(str(year))


def upload(
    credentials_path: Path,
    seasons: list[tuple[int, dict]],
    public_config: dict,
    dry_run: bool,
    delete_legacy_program: bool,
) -> None:
    for _year, doc in seasons:
        validate_season(doc)
    validate_public_config(public_config)

    if dry_run:
        for year, doc in seasons:
            screenings = sum(len(w.get("screenings", [])) for w in doc["weeks"])
            print(
                f"[dry-run] Would write {SEASONS_COLLECTION}/{year} "
                f"({len(doc['weeks'])} weeks, {screenings} screenings)"
            )
        print(f"[dry-run] Would write {'/'.join(PUBLIC_CONFIG_PATH)}")
        print(f"[dry-run] currentSeasonYear: {public_config.get('currentSeasonYear')}")
        if delete_legacy_program:
            print(f"[dry-run] Would delete legacy {'/'.join(LEGACY_PROGRAM_PATH)}")
        return

    try:
        import firebase_admin
        from firebase_admin import credentials as fb_credentials
        from firebase_admin import firestore
    except ImportError:
        print("Missing dependency. Run: pip install -r scripts/requirements.txt", file=sys.stderr)
        sys.exit(1)

    if not credentials_path.is_file():
        print(
            f"Service account file not found: {credentials_path}\n"
            "Download it from Firebase Console → Project settings → Service accounts\n"
            f"Save as: {DEFAULT_CREDENTIALS}",
            file=sys.stderr,
        )
        sys.exit(1)

    if not firebase_admin._apps:
        firebase_admin.initialize_app(fb_credentials.Certificate(str(credentials_path)))

    db = firestore.client()

    for year, doc in seasons:
        if doc["seasonYear"] != year:
            raise ValueError(f"File year {year} does not match seasonYear {doc['seasonYear']}")
        season_ref(db, year).set(doc)
        screenings = sum(len(w.get("screenings", [])) for w in doc["weeks"])
        print(
            f"Uploaded {SEASONS_COLLECTION}/{year} "
            f"({len(doc['weeks'])} weeks, {screenings} screenings)"
        )

    db.collection(PUBLIC_CONFIG_PATH[0]).document(PUBLIC_CONFIG_PATH[1]).set(public_config)
    print(f"Uploaded {'/'.join(PUBLIC_CONFIG_PATH)}")

    if delete_legacy_program:
        legacy_ref = db.collection(LEGACY_PROGRAM_PATH[0]).document(LEGACY_PROGRAM_PATH[1])
        legacy_ref.delete()
        print(f"Deleted legacy {'/'.join(LEGACY_PROGRAM_PATH)}")

    print("Done. Apps listen to publicConfig.currentSeasonYear → seasons/{year}.")


def migrate_legacy_program(db) -> dict | None:
    legacy = db.collection(LEGACY_PROGRAM_PATH[0]).document(LEGACY_PROGRAM_PATH[1]).get()
    if not legacy.exists:
        return None
    data = legacy.to_dict()
    if not data:
        return None
    return data


def collect_season_files(explicit_year: int | None, all_seasons: bool) -> list[tuple[int, dict]]:
    if all_seasons:
        paths = sorted(SEASONS_DIR.glob("*.json"))
        if not paths:
            raise FileNotFoundError(f"No season files in {SEASONS_DIR}")
        result: list[tuple[int, dict]] = []
        for path in paths:
            year = int(path.stem)
            result.append((year, load_json(path)))
        return result

    year = explicit_year or int(
        load_json(DEFAULT_DATA_DIR / "public_config.json").get(
            "currentSeasonYear",
            load_json(DEFAULT_DATA_DIR / "public_config.json").get("seasonYear", 2025),
        )
    )
    path = SEASONS_DIR / f"{year}.json"
    if not path.is_file():
        path = DEFAULT_DATA_DIR / "program.json"
    if not path.is_file():
        raise FileNotFoundError(
            f"No season file for {year}. Run: python3 scripts/generate_seed_data.py"
        )
    return [(year, load_json(path))]


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed CinéTransat Firestore (multi-year)")
    parser.add_argument("--credentials", type=Path, default=DEFAULT_CREDENTIALS)
    parser.add_argument("--year", type=int, help="Upload one season (default: currentSeasonYear from public_config.json)")
    parser.add_argument("--all-seasons", action="store_true", help="Upload every scripts/data/seasons/*.json")
    parser.add_argument("--public-config", type=Path, default=DEFAULT_DATA_DIR / "public_config.json")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--regenerate", action="store_true")
    parser.add_argument(
        "--migrate-legacy-program",
        action="store_true",
        help="If cinetransat/program exists, copy it to seasons/{year} before upload",
    )
    parser.add_argument(
        "--delete-legacy-program",
        action="store_true",
        help="Remove deprecated cinetransat/program after successful upload",
    )
    args = parser.parse_args()

    if args.regenerate:
        subprocess.run([sys.executable, str(SCRIPT_DIR / "generate_seed_data.py")], check=True)

    if not args.public_config.is_file():
        print(f"Missing {args.public_config}", file=sys.stderr)
        sys.exit(1)

    public_config = load_json(args.public_config)
    seasons = collect_season_files(args.year, args.all_seasons)

    if args.migrate_legacy_program and not args.dry_run:
        try:
            import firebase_admin
            from firebase_admin import credentials as fb_credentials
            from firebase_admin import firestore

            if args.credentials.is_file() and not firebase_admin._apps:
                firebase_admin.initialize_app(fb_credentials.Certificate(str(args.credentials)))
            db = firestore.client()
            legacy = migrate_legacy_program(db)
            if legacy:
                year = int(legacy.get("seasonYear", seasons[0][0]))
                print(f"Migrating legacy cinetransat/program → seasons/{year}")
                seasons = [(year, legacy)] + [(y, d) for y, d in seasons if y != year]
                args.delete_legacy_program = True
        except ImportError:
            pass

    upload(
        args.credentials,
        seasons,
        public_config,
        args.dry_run,
        args.delete_legacy_program,
    )


if __name__ == "__main__":
    main()
