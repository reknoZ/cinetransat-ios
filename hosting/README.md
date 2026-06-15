# Poster images for Firebase Hosting

Add one file per film: `public/posters/{posterKey}.jpg`  
(e.g. `public/posters/paddington-2.jpg` — same keys as in Firestore `posterKey`).

Deploy from the **repo root**:

```bash
firebase login --reauth   # if you see HTTP 401 / invalid credentials
firebase deploy --only hosting
```

Project id: `cinetransat-497ce` (see `.firebaserc`).

Verify a poster is live (should be `HTTP/2 200`, not 404):

```bash
curl -sI "https://cinetransat-497ce.web.app/posters/puan.jpg" | head -1
```

Posters must be real **JPEG** or **PNG** (not AVIF renamed to `.jpg`). Convert if needed:

```bash
sips -s format jpeg hosting/public/posters/puan.jpg --out hosting/public/posters/puan.jpg
```

Then set `posterBaseURL` in Firestore `cinetransat/publicConfig` — see [docs/POSTERS.md](../docs/POSTERS.md).
