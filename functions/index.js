// functions/index.js
//
// Server-side replacement for the old client-side "wait 5 minutes, then
// send" Timer in mt_dashboard_page.dart. Runs regardless of whether any
// admin has the app open, and pushes a ringing FCM notification to every
// registered admin device once a report has been sitting unhandled for
// 5+ minutes.
//
// This version uses a SCHEDULED function (Cloud Scheduler + Pub/Sub,
// bundled automatically by Firebase) instead of Cloud Tasks. No queue to
// create, no per-report task scheduling — it just wakes up every minute
// and scans /emergencies for anything overdue. Simpler to deploy; the
// only tradeoff is up to ~1 minute of jitter on top of the 5-minute mark,
// which doesn't matter for this use case.
//
// Requires the Blaze (pay-as-you-go) plan — this is a Google requirement
// for any Cloud Functions trigger, including scheduled ones, even though
// the free tier quota still applies underneath it. Upgrade at:
// Firebase Console → your project → Upgrade → Blaze.
//
// Deploy:
//   firebase init functions        (if not already set up)
//   cd functions && npm install firebase-admin firebase-functions
//   firebase deploy --only functions

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const FOLLOWUP_DELAY_SECONDS = 5 * 60; // 5 minutes, same as the old client Timer

/**
 * Runs every minute. Finds reports still 'baru' that were created 5+
 * minutes ago, claims each one (same transaction pattern as
 * _processAndSendReport() in mt_dashboard_page.dart), marks it
 * 'siap_kirim', and pushes a ringing notification to every admin device.
 */
exports.checkOverdueEmergencies = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async () => {
    const db = admin.database();
    const nowSeconds = Math.floor(Date.now() / 1000);
    const cutoff = nowSeconds - FOLLOWUP_DELAY_SECONDS;

    const snap = await db
      .ref('emergencies')
      .orderByChild('timestamp')
      .endAt(cutoff)
      .get();

    if (!snap.exists()) {
      functions.logger.info('Tidak ada laporan overdue.');
      return null;
    }

    const candidates = [];
    snap.forEach((child) => {
      const data = child.val();
      if (data.status === 'baru' || data.status === undefined) {
        candidates.push({ key: child.key, data });
      }
    });

    if (candidates.length === 0) {
      functions.logger.info('Tidak ada laporan berstatus baru yang overdue.');
      return null;
    }

    let tokens = [];
    const tokensSnap = await db.ref('adminTokens').get();
    const tokensMap = tokensSnap.val() || {};
    tokens = Object.values(tokensMap).filter((t) => typeof t === 'string');

    for (const { key, data } of candidates) {
      await processOverdueReport(db, key, data, tokens, tokensMap);
    }

    return null;
  });

async function processOverdueReport(db, key, data, tokens, tokensMap) {
  const statusRef = db.ref(`emergencies/${key}/status`);

  // Claim it — only proceed if still 'baru'. If it was cancelled, sent
  // manually, or already claimed by another run in the meantime, back off.
  const result = await statusRef.transaction((current) => {
    if (current === null || current === 'baru') {
      return 'siap_kirim';
    }
    return; // undefined return aborts, leaves value untouched
  });

  if (!result.committed) {
    functions.logger.info(`Laporan ${key} sudah ditangani/dibatalkan, lewati.`);
    return;
  }

  if (tokens.length === 0) {
    functions.logger.warn(`Tidak ada adminTokens terdaftar — laporan ${key} siap kirim tapi tidak ada yang dinotifikasi.`);
    return;
  }

  const utId = data.utId ?? 'Tidak diketahui';

  const message = {
    notification: {
      title: `🚨 Laporan Darurat — Area ${utId}`,
      body: 'Belum ditangani selama 5 menit. Buka aplikasi untuk kirim ke BPBD.',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'emergency_alerts', // must match the channel created client-side in fcm_setup.dart
        sound: 'emergency_ring',
        defaultVibrateTimings: false,
        vibrateTimingsMillis: [0, 500, 250, 500],
      },
    },
    data: {
      reportKey: key,
    },
    tokens,
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  functions.logger.info(`Push terkirim untuk laporan ${key}: ${response.successCount} sukses, ${response.failureCount} gagal`);

  // Clean up tokens that are no longer valid (uninstalled app, etc.)
  const tokenEntries = Object.entries(tokensMap);
  const invalidUids = [];
  response.responses.forEach((r, i) => {
    if (!r.success && r.error?.code === 'messaging/registration-token-not-registered') {
      invalidUids.push(tokenEntries[i]?.[0]);
    }
  });
  await Promise.all(
    invalidUids.filter(Boolean).map((uid) => db.ref(`adminTokens/${uid}`).remove())
  );
}