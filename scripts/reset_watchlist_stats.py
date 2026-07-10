#!/usr/bin/env python3
"""Set watchlistDevices `devices` arrays (admin). Use to fix double-counted test data."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from firebase_admin import credentials, firestore, initialize_app


def main() -> None:
    parser = argparse.ArgumentParser(description="Set watchlistDevices screening device lists")
    parser.add_argument(
        "--count",
        type=int,
        required=True,
        help="Length of the devices array (uses placeholder UUIDs for testing)",
    )
    parser.add_argument(
        "--screening",
        action="append",
        help="yyyyMMdd id (repeatable). Default: all documents in watchlistDevices",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    cred = credentials.Certificate(SCRIPT_DIR / "serviceAccountKey.json")
    try:
        initialize_app(cred)
    except ValueError:
        pass

    db = firestore.client()
    base = db.collection("watchlistDevices")

    if args.screening:
        refs = [base.document(sid) for sid in args.screening]
    else:
        refs = [doc.reference for doc in base.stream()]

    if not refs:
        print("No documents found.")
        return

    devices = [f"00000000-0000-0000-0000-{i:012d}" for i in range(args.count)]

    for ref in refs:
        path = ref.path
        if args.dry_run:
            print(f"[dry-run] Would set {path} devices length={len(devices)}")
        else:
            ref.set({"devices": devices}, merge=True)
            print(f"Set {path} devices length={len(devices)}")


if __name__ == "__main__":
    main()
