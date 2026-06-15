# Movie posters (no Firebase Storage required)

The app loads posters over **HTTPS** (`AsyncImage`). You only need a public URL — **Cloud Firestore** for metadata, **not** Firebase Storage.

## How the app picks an image

1. **`posterURL`** on a screening (full URL) — highest priority  
2. **`posterBaseURL`** in `cinetransat/publicConfig` + `{posterKey}` — e.g. `https://yoursite.example/posters/{posterKey}.jpg`  
3. Bundled images in the Xcode asset catalog (offline fallback)

`posterKey` is usually a slug of the film title (`paddington-2`). Override it per screening for catch-up nights (see [FIREBASE_SETUP.md](FIREBASE_SETUP.md)).

---

## Option A — Firebase Hosting (recommended, free on Spark)

Same Firebase project as Firestore, **no Blaze plan** for static files.

1. Posters live in this repo under [`hosting/public/posters/`](../hosting/public/posters/) as `{posterKey}.jpg`.
2. Install [Firebase CLI](https://firebase.google.com/docs/cli) and run `firebase login`.
3. From the repo root:

   ```bash
   firebase deploy --only hosting
   ```

4. Set `posterBaseURL` in `scripts/data/public_config.json` (use your Hosting URL from the CLI output):

   ```json
   "posterBaseURL": "https://YOUR-PROJECT.web.app/posters/{posterKey}.jpg"
   ```

5. `./scripts/seed.sh` to update Firestore.

---

## Option B — GitHub (or any static host)

1. Public repo (or folder) with files like `posters/paddington-2.jpg`.
2. Use raw URLs in `posterBaseURL`, e.g. jsDelivr:

   ```json
   "posterBaseURL": "https://cdn.jsdelivr.net/gh/YOUR_ORG/cinetransat-posters@main/posters/{posterKey}.jpg"
   ```

   Or set **`posterURL`** on each screening in Firestore to the full image URL.

---

## Option C — Your own site

If [cinetransat.ch](https://www.cinetransat.ch) (or a CDN) can serve `/posters/paddington-2.jpg`:

```json
"posterBaseURL": "https://www.cinetransat.ch/app-posters/{posterKey}.jpg"
```

---

## Option D — Per-screening URLs only

Skip `posterBaseURL`. Set `posterURL` on each screening in Firestore when images live in different places.

---

## File names

Each screening has a **`posterKey`** in Firestore (filename without extension). It must match the file in `hosting/public/posters/` **exactly** — including accents and punctuation (`soirée-choréoké.jpg`, `le-fabuleux-destin-d'amelie-poulain.jpg`).

The mapping from programme title → file stem lives in **`PosterCatalog.swift`** (and `POSTER_STEM_BY_TITLE` in `scripts/generate_seed_data.py`). When you add a film or rename a file, update both.

For catch-up / reschedule nights, set `posterKey` to the **film** being shown (e.g. `paddington-2`), not the evening title.

JPEG or PNG (the app tries `.jpg` then `.png`). Keep files reasonably sized (e.g. under 500 KB) for mobile.

## Caching in the app

Posters are saved under **Caches/PosterImages/** after the first successful download. Later launches load from disk immediately (no re-download unless the cache file is cleared). HTTP responses also use `URLCache`.
