#!/usr/bin/env python3
"""
Patch projection start times on an existing Firestore season document.

Reads seasons/{year} from Firestore, updates only each screening's startsAt field,
then writes back that single document. Does not touch other seasons or publicConfig.

Usage:
  python3 scripts/patch_projection_times.py --dry-run
  python3 scripts/patch_projection_times.py
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from generate_seed_data import PROJECTION_START_2026, starts_iso  # noqa: E402

DEFAULT_CREDENTIALS = SCRIPT_DIR / "serviceAccountKey.json"
TZ = timezone(timedelta(hours=2))


def screening_date_parts(screening_id: str) -> tuple[int, int, int]:
    if len(screening_id) != 8 or not screening_id.isdigit():
        raise ValueError(f"Invalid screening id: {screening_id!r}")
    return int(screening_id[0:4]), int(screening_id[4:6]), int(screening_id[6:8])


def patch_weeks(weeks: list[dict], season_year: int) -> tuple[list[dict], list[str]]:
    if season_year != 2026:
        raise ValueError(f"Only 2026 projection times are defined (got {season_year})")

    changes: list[str] = []
    for week in weeks:
        for screening in week.get("screenings", []):
            sid = screening.get("id")
            if not sid or sid not in PROJECTION_START_2026:
                continue
            y, m, d = screening_date_parts(sid)
            new_starts = starts_iso(y, m, d)
            old_starts = screening.get("startsAt")
            if old_starts == new_starts:
                continue
            screening["startsAt"] = new_starts
            title = screening.get("title", sid)
            changes.append(f"  {sid} {title}: {old_starts} → {new_starts}")
    return weeks, changes


def main() -> None:
    parser = argparse.ArgumentParser(description="Patch startsAt on seasons/{year} in Firestore")
    parser.add_argument("--year", type=int, default=2026)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--credentials", type=Path, default=DEFAULT_CREDENTIALS)
    args = parser.parse_args()

    if args.dry_run:
        try:
            import firebase_admin  # noqa: F401
        except ImportError:
            print("Missing dependency. Run: pip install -r scripts/requirements.txt", file=sys.stderr)
            sys.exit(1)

    if not args.credentials.is_file():
        print(
            f"Service account file not found: {args.credentials}\n"
            "Save Firebase service account JSON as scripts/serviceAccountKey.json",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        import firebase_admin
        from firebase_admin import credentials as fb_credentials
        from firebase_admin import firestore
    except ImportError:
        print("Missing dependency. Run: pip install -r scripts/requirements.txt", file=sys.stderr)
        sys.exit(1)

    if not firebase_admin._apps:
        firebase_admin.initialize_app(fb_credentials.Certificate(str(args.credentials)))

    db = firestore.client()
    ref = db.collection("seasons").document(str(args.year))
    snapshot = ref.get()
    if not snapshot.exists:
        print(f"No document at seasons/{args.year}", file=sys.stderr)
        sys.exit(1)

    doc = snapshot.to_dict() or {}
    weeks = doc.get("weeks")
    if not isinstance(weeks, list):
        print(f"seasons/{args.year} has no weeks array", file=sys.stderr)
        sys.exit(1)

    season_year = int(doc.get("seasonYear", args.year))
    patched_weeks, changes = patch_weeks(weeks, season_year)

    if not changes:
        print(f"No startsAt changes needed on seasons/{args.year}.")
        return

    print(f"seasons/{args.year} — {len(changes)} screening(s) to update:")
    print("\n".join(changes))

    if args.dry_run:
        print("\n[dry-run] No write performed.")
        return

    ref.update(
        {
            "weeks": patched_weeks,
            "updatedAt": datetime.now(TZ).isoformat(timespec="seconds"),
        }
    )
    print(f"\nUpdated seasons/{args.year} (startsAt only).")


if __name__ == "__main__":
    main()
