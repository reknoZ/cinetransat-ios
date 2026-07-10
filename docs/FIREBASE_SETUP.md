# Firebase backend (programme + public URLs)

CinéTransat loads **live data from Cloud Firestore** so you can change screenings, cancellations, and links **without** shipping a new iOS or Android build.

## Why Firebase (and not JSON in the repo)

| Approach | App update needed? | Good for |
|----------|-------------------|----------|
| Hard-coded Swift/Kotlin | Yes | Prototypes only |
| JSON in GitHub | No* | Simple, but no console UI, weak realtime |
| **Cloud Firestore** | **No** | Schedule + URLs, realtime, iOS + Android SDKs |

\*JSON on a CDN still works, but you asked for a managed backend like Firebase.

**Alternatives:** [Supabase](https://supabase.com) (Postgres + REST, very similar), AWS Amplify, or a small custom API. Firestore is a solid default for this app size.

## Data model (schema v2 — multi-year)

Each festival season is stored as its own document. The app shows the **current** season by default; a future release will let users browse **past** seasons.

| Firestore path | Purpose |
|----------------|---------|
| `seasons/{year}` | Full programme for that year (`2025`, `2024`, …). Document ID must match `seasonYear`. |
| `cinetransat/publicConfig` | Global URLs, contact, social links, and **`currentSeasonYear`** (watch list + notifications; app **opens the newest** `seasons/{year}` on launch). |

**Deprecated:** `cinetransat/program` (single-season layout). Migrate with `python3 scripts/seed_firestore.py --migrate-legacy-program --delete-legacy-program`.

### `seasons/{year}`

- `schemaVersion` (number) — `2`
- `seasonYear` (number) — must equal document ID, e.g. `2025`
- `updatedAt` (string, ISO-8601)
- `weeks` (array of maps: `id`, `label`, `screenings[]`)

Each screening map:

- `id` — `yyyyMMdd` (watch list + poster key)
- `title`, `startsAt`, `sunset` (ISO-8601 strings, Europe/Zurich)
- `isCanceled`, `synopsis`
- `runtimeMinutes` (number or null)
- `audioLanguage`, `audioLanguageEn`, `subtitleLanguage`, `subtitleLanguageEn` (optional strings — shown on film detail)
- `searchTitle` (optional, used for IMDb/Allociné and default poster slug)
- `posterKey` (optional) — which poster file to show (`paddington-2`, etc.). Defaults to a slug of `searchTitle` or `title`.
- `posterURL` (optional) — full HTTPS URL (overrides template)

### `cinetransat/publicConfig`

- `schemaVersion` — `2`
- `currentSeasonYear` — e.g. `2025` (which `seasons/{year}` document the app listens to)
- `websiteURL`, `practicalInfoURL`, `contactEmail`
- `facebookURL`, `instagramURL` (optional)
- `posterBaseURL` (optional) — any HTTPS template with `{posterKey}` (see **[POSTERS.md](POSTERS.md)** — **not** Firebase Storage)

Legacy field `seasonYear` on `publicConfig` is still decoded for older payloads.

## Posters (HTTPS — no Firebase Storage)

Posters are **plain image URLs**. Firestore holds `posterKey` / `posterURL`; files can live on **Firebase Hosting** (free), GitHub, or your website. Full guide: **[POSTERS.md](POSTERS.md)**.

| Field | Role |
|-------|------|
| Default | `posterKey` = slug of film title (`paddington-2`) |
| Override | Different `posterKey` per screening (catch-up, reschedule) |
| URL | `posterBaseURL` template or per-screening `posterURL` |

Until `posterBaseURL` is set, the app uses bundled Xcode assets (if present), then the generic tile.

## 1. Create the Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/).
2. **Add project** (e.g. `cinetransat`).
3. Add an **iOS app** with bundle ID `com.heewhack.Cine-Transat`.
4. Download **`GoogleService-Info.plist`** and add it to the Xcode target **CinéTransat** (do not commit secrets to a public repo if you prefer — see `.gitignore`).
5. Add an **Android app** in the same Firebase project when you build the Android repo (same Firestore data).

## 2. Enable Firestore

1. Firebase Console → **Build** → **Firestore Database** → **Create database**.
2. Start in **production mode** (you will add rules below).
3. Choose a region close to Geneva (e.g. `europe-west6`).

## 3. Security rules (required — fix “Missing or insufficient permissions”)

The app reads **`seasons/{year}`** and **`cinetransat/publicConfig`**. If your rules only allow `cinetransat/*`, reads on `seasons` will fail.

In **Firebase Console → Firestore → Rules**, paste the contents of [`firestore.rules`](../firestore.rules) from this repo (or copy below), then **Publish**:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /seasons/{year} {
      allow read: if true;
      allow write: if false;
    }
    match /cinetransat/{document=**} {
      allow read: if true;
      allow write: if false;
    }
    match /watchlistDevices/{screeningId} {
      allow read: if true;
      allow create: if screeningId.matches('^\\d{8}$')
        && request.resource.data.keys().hasOnly(['devices'])
        && request.resource.data.devices is list
        && request.resource.data.devices.size() == 1;
      allow update: if screeningId.matches('^\\d{8}$')
        && request.resource.data.keys().hasOnly(['devices'])
        && request.resource.data.devices is list
        && (
          request.resource.data.devices.size() == resource.data.get('devices', []).size() + 1
          || request.resource.data.devices.size() == resource.data.get('devices', []).size() - 1
        );
      allow delete: if false;
    }
    match /watchlistStats/{screeningId} {
      allow read: if true;
      allow create: if request.resource.data.keys().hasOnly(['count'])
        && request.resource.data.count is number
        && request.resource.data.count == 1;
      allow update: if request.resource.data.keys().hasOnly(['count'])
        && request.resource.data.count is number
        && request.resource.data.count >= 0
        && (
          request.resource.data.count == resource.data.get('count', 0) + 1
          || request.resource.data.count == resource.data.get('count', 0) - 1
        );
      allow delete: if false;
    }
    match /watchlistStats/{year}/screenings/{screeningId} {
      allow read: if true;
      allow create: if request.resource.data.keys().hasOnly(['count'])
        && request.resource.data.count is number
        && request.resource.data.count == 1;
      allow update: if request.resource.data.keys().hasOnly(['count'])
        && request.resource.data.count is number
        && request.resource.data.count >= 0
        && (
          request.resource.data.count == resource.data.get('count', 0) + 1
          || request.resource.data.count == resource.data.get('count', 0) - 1
        );
      allow delete: if false;
    }
  }
}
```

### Anonymous watch list stats

**Displayed count (transition):** legacy `count` + `watchlistDevices.devices.length`

Legacy data may live at either path (older builds used the nested one):

- `watchlistStats/{yyyyMMdd}.count` (flat)
- `watchlistStats/{year}/screenings/{yyyyMMdd}.count` (nested)

The app reads **both** during transition and uses whichever document exists.

- **Old app versions** still increment/decrement `watchlistStats.count`.
- **New app** writes `watchlistDevices.devices` only; on first launch after upgrade it also **−1** legacy for each migrated screening so upgraded users are not double-counted.

When every user is on the new build, delete the `watchlistStats` collection and remove the legacy listener/rules — counts will come from `devices.length` only.

Rules: [`firestore.rules`](../firestore.rules). Deploy after changes:

```bash
firebase deploy --only firestore:rules
```

To reset test data: `python scripts/reset_watchlist_stats.py --count 0` (see script help).

### Migrating from legacy `watchlistStats.count`

The old schema stored only an integer per screening (`watchlistStats/{yyyyMMdd}.count`). It did **not** record which installs contributed, so you **cannot** rebuild `devices` arrays from old counts alone.

**Per device (automatic in app v1.2+):** On first launch after upgrade, the app sets `watchlistDevicesSchemaV2Migrated` and runs `arrayUnion` for every screening on that device's local watch list (plus any legacy UserDefaults contribution ledger). After that, only `watchlistDevices` is used.

**You do not need two App Store releases** — one build with the new code + deployed rules is enough.

**Recommended release order:**

1. Deploy Firestore rules (`firebase deploy --only firestore:rules`).
2. Ship the iOS update; each upgraded device registers itself on first open.
3. (Optional) In Firebase Console, delete the obsolete `watchlistStats` collection after most users have updated — or leave it; the app no longer reads it.

**Expect counts to change:** Displayed totals come from `devices.length` and may be **lower** than old `count` values that were inflated by reinstall double-counting. Mention this in release notes if numbers were public.

**Optional admin cleanup** — remove legacy count documents (does not affect the new arrays):

```bash
# Firebase Console → Firestore → watchlistStats → delete collection
# Or use a one-off Admin SDK script with serviceAccountKey.json
```

Optional CLI deploy (from repo root, after `npm install -g firebase-tools` and `firebase login`):

```bash
firebase deploy --only firestore:rules
```

Edits go through the **Firebase Console** or the **Admin SDK** (seed script), not from the public apps.

## 4. Seed data (automated — recommended)

From the repo root, after placing your service account key at `scripts/serviceAccountKey.json`:

```bash
./scripts/seed.sh
```

This writes `seasons/2025` (and any other `scripts/data/seasons/*.json`) plus `cinetransat/publicConfig`.

**Migrate an existing v1 database:**

```bash
python3 scripts/seed_firestore.py --migrate-legacy-program --delete-legacy-program
```

See [`scripts/README.md`](../scripts/README.md) for dry-run, per-year upload, and custom credentials.

**Alternative:** run the app → **Settings → Export data**, save as `scripts/data/seasons/2025.json`, then run `seed_firestore.py`.

## 5. iOS behaviour

- On launch, `Cine_TransatApp.init()` calls `FirebaseApp.configure()` (requires `GoogleService-Info.plist` in the app target).
- `FestivalProgramStore` listens to `cinetransat/publicConfig`, then to `seasons/{currentSeasonYear}`.
- `availableSeasonYears` is populated from the `seasons` collection (for future archive UI).
- `selectSeason(year:)` switches the active listener (archive browsing later).
- Updates apply **in realtime** (e.g. mark a screening canceled).
- Each season is **cached on disk** as `season-{year}.json` for offline use.
- Without Firebase, the app uses **`FestivalProgramBootstrap`** (bundled fallback).

## 6. Android (separate repo)

Use the **same Firebase project** and paths:

- `seasons/{year}`
- `cinetransat/publicConfig` (`currentSeasonYear`)

Add the Android `google-services.json` from Firebase; use the Firestore Android SDK with the same field names. No second backend required.

## 7. Adding a new festival year

1. Copy or generate `scripts/data/seasons/2026.json` (same JSON shape as `2025.json`).
2. Set `currentSeasonYear` in `scripts/data/public_config.json` when you want the live app to switch.
3. Run `./scripts/seed.sh` or `python3 scripts/seed_firestore.py --all-seasons`.

Older seasons remain in Firestore for archive browsing without deleting history.

## 8. Cancellation push notifications

Implemented end-to-end. See **[NOTIFICATIONS.md](NOTIFICATIONS.md)** for APNs, FCM, deploying `functions/notifyScreeningCanceled`, and testing.

Users enable alerts in **Settings → Cancellation alerts** (subscribes to `season_{year}_cancellations`).

## 9. Optional next steps

- **Firebase Remote Config** for feature flags only (not required for programme data).
- **Watch-list counts** in Firestore (separate collection; not implemented yet).
