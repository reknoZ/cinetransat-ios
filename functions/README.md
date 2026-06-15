# Cancellation push (Cloud Function)

Sends FCM to topic `season_{year}_cancellations` when a screening’s `isCanceled` becomes `true` in `seasons/{year}`.

## Deploy (once per machine)

```bash
cd functions
npm install   # first time or after package.json changes only
cd ..
firebase deploy --only functions
```

Functions deploy to **`europe-west1`** (same as your first successful deploy). Do not set Cloud Functions `region` to `eur3` — that is a Firestore database location and deploy will fail with HTTP 403.

**Requires:** Firebase project on the **Blaze** plan (usage for this function is typically $0).

## View logs after a test

Firebase Console → **Functions** does **not** show a Logs tab for this Gen 2 function. Use **Google Cloud**:

| Where | Link |
|--------|------|
| **Cloud Run → Logs** (recommended) | [notifyscreeningcanceled logs](https://console.cloud.google.com/run/detail/europe-west1/notifyscreeningcanceled/logs?project=cinetransat-497ce) |
| **Logs Explorer** | [query by service name](https://console.cloud.google.com/logs/query?project=cinetransat-497ce) — filter `resource.labels.service_name="notifyscreeningcanceled"` and exclude `logName:"run.googleapis.com%2Frequests"` |

Look for **text** log lines (`Sending…`, `FCM OK`, `FCM FAILED`), not HTTP `POST` request rows with only `status: 200`.

See also [`docs/NOTIFICATIONS.md`](../docs/NOTIFICATIONS.md).

## If deploy fails

### `Couldn't find firebase-functions package`

Run `npm install` inside `functions/` (see above).

### `An unexpected error has occurred` (right after enabling APIs)

Often the same as missing `node_modules`. Run `npm install`, then deploy again.

### `Permission denied while using the Eventarc Service Agent`

Common **the first time** Functions / Eventarc are enabled on a Blaze project.

1. Wait **5–15 minutes** after upgrading to Blaze or enabling APIs.
2. Run `firebase deploy --only functions` again.

If it still fails:

1. Open [Google Cloud Console → IAM](https://console.cloud.google.com/iam-admin/iam?project=cinetransat-497ce).
2. Find the principal **Eventarc Service Agent** (or `service-PROJECT_NUMBER@gcp-sa-eventarc.iam.gserviceaccount.com`).
3. Confirm it has the **Eventarc Service Agent** role (Firebase enablement usually adds this automatically).

### Node.js runtime warning

This project targets **Node.js 22** (`nodejs22` in `firebase.json`).
