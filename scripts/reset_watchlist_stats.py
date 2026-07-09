#!/usr/bin/env python3
"""Set watchlistStats counts (admin). Use to fix double-counted test data."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from firebase_admin import credentials, firestore, initialize_app


def main() -> None:
    parser = argparse.ArgumentParser(description="Set watchlistStats screening counts")
    parser.add_argument("--count", type=int, required=True, help="Value to set on each document")
    parser.add_argument(
        "--screening",
        action="append",
        help="yyyyMMdd id (repeatable). Default: all documents in watchlistStats",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    cred = credentials.Certificate(SCRIPT_DIR / "serviceAccountKey.json")
    try:
        initialize_app(cred)
    except ValueError:
        pass

    db = firestore.client()
    base = db.collection("watchlistStats")

    if args.screening:
        refs = [base.document(sid) for sid in args.screening]
    else:
        refs = [doc.reference for doc in base.stream()]

    if not refs:
        print("No documents found.")
        return

    for ref in refs:
        path = ref.path
        if args.dry_run:
            print(f"[dry-run] Would set {path} count={args.count}")
        else:
            ref.set({"count": args.count}, merge=True)
            print(f"Set {path} count={args.count}")


if __name__ == "__main__":
    main()
