# Cancellation push notifications

When a screening’s `isCanceled` flips to `true` in Firestore (`seasons/{year}`), subscribers receive a push notification—even if the app is closed.

## How it works

| Layer | Role |
|--------|------|
| **Cloud Function** `notifyScreeningCanceled` | Watches `seasons/{year}` updates; sends FCM to topic `season_{year}_cancellations` |
| **iOS (Firebase Messaging)** | User opts in under **Settings → Cancellation alerts**; app subscribes to the current season topic |
| **Local notification (fallback only)** | Firestore listener posts a local alert when the app **runs** (foreground or after you open it). This does **not** replace push when the app is force-quit. |

## One-time setup

### 1. Apple Push Notification service (APNs)

1. [Apple Developer](https://developer.apple.com) → **Certificates, Identifiers & Profiles** → your App ID → enable **Push Notifications**.
2. In Xcode: target **CinéTransat** → **Signing & Capabilities** → **+ Capability** → **Push Notifications** (and **Background Modes** → **Remote notifications** if not already present).

### 2. Firebase Cloud Messaging

1. Firebase Console → **Project settings** → **Cloud Messaging**.
2. Under **Apple app configuration**, upload your **APNs Authentication Key** (.p8) or certificate.
3. Ensure `GoogleService-Info.plist` is in the iOS target (same as Firestore).

### 3. Deploy the Cloud Function

Requires the **Blaze** plan (pay-as-you-go; FCM + modest Firestore triggers are typically within free tier).

```bash
cd functions
npm install          # required — deploy fails without node_modules
cd ..
firebase deploy --only functions
```

If you see **Eventarc Service Agent / Permission denied**, wait 5–15 minutes after enabling Blaze, then deploy again. See [`functions/README.md`](../functions/README.md).

### 4. Push capability in Xcode (when ready)

Do **not** hand-edit `project.pbxproj` entitlements paths (accented folder names can break the project file).

1. Open the **CinéTransat** target → **Signing & Capabilities** → **+ Capability** → **Push Notifications**.
2. Xcode creates the entitlements file and sets `CODE_SIGN_ENTITLEMENTS` correctly.
3. A template lives at `config/CineTransat.entitlements` (`aps-environment` = `development`) if you need to merge settings manually.

For **TestFlight / App Store**, use `production` in `aps-environment` or let automatic signing manage both.

## Alert only when I open the app?

That behavior is the **Firestore fallback**, not a real push. iOS only delivers background/lock-screen alerts when **FCM → APNs** succeeds.

Checklist:

1. **Cloud Function deployed** — `firebase deploy --only functions`; Firebase → **Build → Functions** should list `notifyScreeningCanceled` as active. Application log lines (`Sending…`, `FCM OK`) are **not** in Firebase Console — see [Where to read function logs](#where-to-read-function-logs) below.
2. **APNs key in Firebase** — Project settings → Cloud Messaging → Apple app → upload `.p8` (Development for Xcode debug builds; Production for TestFlight/App Store).
3. **Edit the right document** — `seasons/2026` (same year as `currentSeasonYear`), flip `isCanceled` from `false` → `true`.
4. **Rebuild the app** after code changes — `FirebaseAppDelegateProxyEnabled = NO` requires `AppDelegate` to forward remote notifications; **Background Modes → Remote notifications** must be on (see `CinéTransat/Info.plist`).
5. **Wait ~10 s** after enabling alerts before killing the app (FCM topic subscribe needs the APNs token).

## Testing

1. Install the app on a **physical device** (simulator push is limited).
2. **Settings → Cancellation alerts** → enable; accept the iOS permission prompt.
3. In Firebase Console → Firestore, set `isCanceled: true` on one screening in `seasons/2026` (or your live year).
4. You should receive **Séance annulée** with the film title and date.

After a Firestore test edit, read application logs using one of the paths below.

## Where to read function logs

Gen 2 functions (`notifyScreeningCanceled`) run on **Cloud Run**. Firebase Console → Functions shows the function name and trigger, but **there is no Logs tab there**. Use one of these:

### Option A — Cloud Run (easiest in the browser)

1. Open **[Cloud Run → notifyscreeningcanceled → Logs](https://console.cloud.google.com/run/detail/europe-west1/notifyscreeningcanceled/logs?project=cinetransat-497ce)** (project `cinetransat-497ce`, region `europe-west1`).
2. Set the time range to when you changed `isCanceled`.
3. Ignore rows that are only **HTTP POST** / `run.googleapis.com/requests` (status 200, no message text) — those are **not** your `console.log` output.
4. Look for **text** lines, e.g. `Sending 1 cancellation alert(s)…` or `FCM OK` / `FCM FAILED`.

From Firebase: **Build → Functions** → click `notifyScreeningCanceled` → use **“View details in Google Cloud Console”** (wording may vary) → you land on the same Cloud Run service → **Logs** tab.

### Option B — Logs Explorer (filter out request noise)

1. Open **[Logs Explorer](https://console.cloud.google.com/logs/query?project=cinetransat-497ce)**.
2. Paste this query (edit the timestamp after each test):

```
resource.type="cloud_run_revision"
resource.labels.service_name="notifyscreeningcanceled"
timestamp>="2026-05-25T20:02:00Z"
timestamp<="2026-05-25T20:05:00Z"
NOT logName:"run.googleapis.com%2Frequests"
```

3. Run query. Expand a row → **textPayload** (or **jsonPayload.message**) for `Sending` / `FCM OK` / errors.

### Option C — Terminal

```bash
gcloud logging read \
  'resource.type="cloud_run_revision"
   resource.labels.service_name="notifyscreeningcanceled"
   NOT logName:"run.googleapis.com%2Frequests"' \
  --project=cinetransat-497ce \
  --limit=30 \
  --format='table(timestamp,severity,textPayload)'
```

(Requires [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) and `gcloud auth login`.)

### Reading function log messages

| Log line | Meaning |
|----------|---------|
| `Sending N cancellation alert(s) to topic season_2026_cancellations` | Firestore change detected; about to call FCM. |
| `FCM OK topic=... messageId=...` | FCM accepted the message (server side OK). |
| `FCM FAILED topic=...` | FCM rejected the send — expand the error (APNs config, invalid payload, etc.). |

If you see **Sending** but never **FCM OK** / **FCM FAILED**, the function may have crashed on `messaging.send` — check for a red **ERROR** entry in the same invocation.

**Important:** FCM can return **FCM OK** even when **no phone is subscribed** to that topic, or when **APNs never delivers** to your device. An alert only when you open the app still means the **Firestore fallback** ran, not a successful lock-screen push.

### If FCM OK but no lock-screen alert

1. **Topic subscription (most common)** — In the app: Settings → Cancellation alerts ON. Look for an orange error under the toggle. In Xcode console (Debug build): `FCM subscribed to topic season_2026_cancellations`. Toggle alerts off/on, wait 10 s, then force-quit and test again.
2. **APNs in Firebase** — Project settings → **Cloud Messaging** → your iOS app (`com.heewhack.CineTransat`) → APNs Authentication Key uploaded. Xcode **Run** installs use **development** APNs; upload the `.p8` key and enable both Development and Production in Firebase if offered.
3. **Push capability** — Xcode target → Signing & Capabilities → **Push Notifications** + **Background Modes** → **Remote notifications**.
4. **Direct FCM test (bypasses topic)** — Run from Xcode, enable alerts, copy the `FCM token:` line from the Xcode console. Firebase Console → Engage → Messaging → **Send test message** → paste token. If that does not appear on the lock screen, the problem is APNs/Firebase/device permissions, not the Cloud Function.
5. **Redeploy functions** after pulling latest `index.js` (clearer logs): `firebase deploy --only functions`.

## Topic naming

Must stay in sync between:

- iOS: `CancellationNotificationManager.cancellationTopic(seasonYear:)` → `season_2026_cancellations`
- Cloud Function: `season_${year}_cancellations`
