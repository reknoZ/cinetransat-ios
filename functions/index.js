/**
 * Sends FCM topic notifications when a screening becomes canceled in seasons/{year}.
 *
 * Topic (must match iOS): season_{year}_cancellations
 */

const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2/options");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");

// Deploy here (valid Cloud Functions region). Do not use "eur3" — that is Firestore only.
setGlobalOptions({ region: "europe-west1" });

initializeApp();

function weeksList(doc) {
  const weeks = doc?.weeks;
  if (!weeks) return [];
  if (Array.isArray(weeks)) return weeks;
  if (typeof weeks === "object") return Object.values(weeks);
  return [];
}

function isCanceled(screening) {
  const v = screening?.isCanceled;
  return v === true || v === "true" || v === 1;
}

function screeningsById(doc) {
  const map = new Map();
  for (const week of weeksList(doc)) {
    const screenings = week?.screenings;
    const list = Array.isArray(screenings)
      ? screenings
      : screenings && typeof screenings === "object"
        ? Object.values(screenings)
        : [];
    for (const screening of list) {
      if (screening?.id) map.set(screening.id, screening);
    }
  }
  return map;
}

function findNewlyCanceled(before, after) {
  const beforeMap = screeningsById(before);
  const afterMap = screeningsById(after);
  const result = [];
  for (const [id, afterScreening] of afterMap) {
    const wasCanceled = isCanceled(beforeMap.get(id));
    if (isCanceled(afterScreening) && !wasCanceled) {
      result.push(afterScreening);
    }
  }
  return result;
}

function formatStartsAt(iso) {
  if (!iso) return "";
  try {
    const d = new Date(iso);
    return d.toLocaleDateString("fr-CH", {
      weekday: "long",
      day: "numeric",
      month: "long",
    });
  } catch {
    return iso;
  }
}

exports.notifyScreeningCanceled = onDocumentUpdated(
  { document: "seasons/{year}" },
  async (event) => {
  const year = event.params.year;
  const before = event.data.before.data();
  const after = event.data.after.data();
  const newlyCanceled = findNewlyCanceled(before, after);

  // Always log (shows up as stdout) so logs are visible after each Firestore edit.
  console.log(
    JSON.stringify({
      event: "notifyScreeningCanceled",
      year,
      beforeScreenings: screeningsById(before).size,
      afterScreenings: screeningsById(after).size,
      newlyCanceled: newlyCanceled.length,
    })
  );

  if (newlyCanceled.length === 0) {
    return;
  }

  const topic = `season_${year}_cancellations`;
  const messaging = getMessaging();
  console.log(`Sending ${newlyCanceled.length} cancellation alert(s) to topic ${topic}`);

  for (const screening of newlyCanceled) {
    const title = screening.title || "CinéTransat";
    const when = formatStartsAt(screening.startsAt);
    const body = when
      ? `${title} — ${when}. Séance annulée (intempéries).`
      : `${title}. Séance annulée (intempéries).`;

    try {
      const messageId = await messaging.send({
        topic,
        notification: { title: "Séance annulée", body },
        data: {
          screeningId: screening.id || "",
          seasonYear: String(year),
          type: "screening_canceled",
        },
        apns: {
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
          payload: {
            aps: {
              alert: {
                title: "Séance annulée",
                body,
              },
              sound: "default",
            },
          },
        },
      });
      console.log(`FCM OK topic=${topic} messageId=${messageId} screening=${screening.id || "?"}`);
    } catch (err) {
      console.error(`FCM FAILED topic=${topic} screening=${screening.id || "?"}`, err);
      throw err;
    }
  }
  }
);
