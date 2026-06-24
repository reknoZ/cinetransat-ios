# Firestore seed scripts

Automate uploading festival programmes (one document per year) and public URLs to **Cloud Firestore**.

## One-time setup

1. **Firebase project** with Firestore enabled ([full guide](../docs/FIREBASE_SETUP.md)).

2. **Service account key** (admin access for seeding only):
   - Firebase Console → ⚙️ **Project settings** → **Service accounts**
   - **Generate new private key** → save the downloaded JSON as:
     ```
     scripts/serviceAccountKey.json
     ```
   - Do **not** commit this file (it is gitignored).

3. **Python 3.10+** and dependencies:

   ```bash
   cd scripts
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

## Upload (recommended)

From the repo root:

```bash
./scripts/seed.sh
```

### Add 2026 season (current year, starts 9 July)

Same films as 2025, no cancellations, `currentSeasonYear` → 2026:

```bash
./scripts/seed_2026_program.sh
# or JSON only:
python3 scripts/seed_2026_program.py --generate-only
```

Keeps `seasons/2025.json` if it already exists and uploads **all** `seasons/*.json`.

### Patch projection times only (Firestore)

To update `startsAt` on an existing `seasons/2026` document without re-uploading the full programme:

```bash
./scripts/patch_projection_times.sh --dry-run   # preview changes
./scripts/patch_projection_times.sh             # write seasons/2026 only
```

Or step by step:

```bash
python3 scripts/generate_seed_data.py          # writes scripts/data/seasons/2025.json + public_config.json
python3 scripts/seed_firestore.py --all-seasons
```

Dry run (no Firebase write):

```bash
python3 scripts/seed_firestore.py --all-seasons --dry-run
```

Upload a single year:

```bash
python3 scripts/seed_firestore.py --year 2025
```

Migrate from legacy `cinetransat/program`:

```bash
python3 scripts/seed_firestore.py --migrate-legacy-program --delete-legacy-program
```

Custom credentials path:

```bash
python3 scripts/seed_firestore.py --credentials ~/Downloads/cinetransat-firebase-adminsdk.json
```

## What gets written

| Firestore path | Source file |
|----------------|-------------|
| `seasons/2025` | `scripts/data/seasons/2025.json` |
| `seasons/{year}` | `scripts/data/seasons/{year}.json` (with `--all-seasons`) |
| `cinetransat/publicConfig` | `scripts/data/public_config.json` |

Matches the iOS app’s `FestivalProgramStore` listeners (`currentSeasonYear` → `seasons/{year}`).

**After seeding:** publish Firestore rules from [`firestore.rules`](../firestore.rules) in the Firebase Console (or `firebase deploy --only firestore:rules`). Without the `seasons` read rule, the app logs “Missing or insufficient permissions”.

**Posters:** do **not** require Firebase Storage. See [docs/POSTERS.md](../docs/POSTERS.md) (Firebase Hosting, GitHub, etc.).

## After you change the Swift programme

1. Update `FestivalProgramBootstrap` in `CinéTransat/FestivalProgram.swift`.
2. Mirror the same changes in `scripts/generate_seed_data.py` (canonical for seeding), **or** export from the app:
   - **Settings → Export data** → save as `scripts/data/seasons/2025.json`
3. Run `./scripts/seed.sh` again.

## Adding another year

1. Add `scripts/data/seasons/2024.json` (same schema as `2025.json`).
2. Run `python3 scripts/seed_firestore.py --all-seasons`.
3. When ready to switch the live app, set `currentSeasonYear` in `public_config.json` and re-upload public config (or full seed).

## Android

Use the **same Firebase project**; no separate seed needed once Firestore is populated.
