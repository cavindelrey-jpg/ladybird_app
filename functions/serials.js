// functions/serials.js
//
// Server-enforced serial-number operations. These used to be client-side
// Firestore transactions/batches in serial_repository.dart — moved here so
// a modified client can never forge a claim or mint free seats. Pair with
// firestore.rules denying client writes to `serials/*`.
//
// Wire into your existing functions/index.js with, e.g.:
//   const serials = require('./serials');
//   exports.claimSerial     = serials.claimSerial;
//   exports.generateSerials = serials.generateSerials;
//   exports.revokeSerial    = serials.revokeSerial;
//   exports.releaseSerial   = serials.releaseSerial;

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const db = getFirestore();

const COL_SERIALS = 'serials';
const COL_INSTITUTIONS = 'institutions';
const COL_USERS = 'users';

const ADMIN_ROLES = new Set(['departmentAdmin', 'schoolAdmin', 'superAdmin']);

/** Loads the caller's user doc and throws if not signed in. */
async function requireUser(auth) {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required.');
  const snap = await db.collection(COL_USERS).doc(auth.uid).get();
  return { uid: auth.uid, data: snap.exists ? snap.data() : {} };
}

/**
 * Throws unless the caller is an admin for `institutionId` (or a
 * superAdmin, who can manage any institution).
 */
function assertInstitutionAdmin(userData, institutionId) {
  const role = userData.role || '';
  if (!ADMIN_ROLES.has(role)) {
    throw new HttpsError('permission-denied', 'Admin access required.');
  }
  if (role !== 'superAdmin' && userData.schoolId !== institutionId) {
    throw new HttpsError(
      'permission-denied',
      'You can only manage serials for your own institution.',
    );
  }
}

// ─── claimSerial ────────────────────────────────────────────────────────
// Called immediately after Firebase Auth account creation, as part of
// account creation (see AuthService.claimSerialAndCreateAccount).
exports.claimSerial = onCall(async (request) => {
  const { auth, data } = request;
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required.');

  const code = String(data.code || '').trim().toUpperCase();
  if (!code) throw new HttpsError('invalid-argument', 'Missing serial code.');

  const ref = db.collection(COL_SERIALS).doc(code);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Serial number no longer exists.');
    }
    const serial = snap.data();
    if (serial.status !== 'unclaimed') {
      throw new HttpsError(
        'failed-precondition',
        'This serial number has already been claimed.',
      );
    }
    tx.update(ref, {
      status: 'claimed',
      claimedByUid: auth.uid,
      claimedAt: FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

// ─── releaseSerial ──────────────────────────────────────────────────────
// Rollback path: only the uid holding the claim may release it (used when
// account creation fails right after the serial was claimed).
exports.releaseSerial = onCall(async (request) => {
  const { auth, data } = request;
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in required.');

  const code = String(data.code || '').trim().toUpperCase();
  if (!code) throw new HttpsError('invalid-argument', 'Missing serial code.');

  const ref = db.collection(COL_SERIALS).doc(code);
  const snap = await ref.get();
  if (!snap.exists) return { success: true }; // already gone, nothing to do

  const serial = snap.data();
  if (serial.claimedByUid && serial.claimedByUid !== auth.uid) {
    throw new HttpsError('permission-denied', 'You do not hold this claim.');
  }

  await ref.update({
    status: 'unclaimed',
    claimedByUid: null,
    claimedAt: null,
  });
  return { success: true };
});

// ─── generateSerials ────────────────────────────────────────────────────
// Admin-only. Mints `count` fresh unclaimed serials for `institutionId`.
exports.generateSerials = onCall(async (request) => {
  const { auth, data } = request;
  const { data: userData } = await requireUser(auth);

  const institutionId = String(data.institutionId || '');
  const institutionPrefix = String(data.institutionPrefix || '').toUpperCase();
  const count = Number(data.count || 0);
  const classLevel = data.classLevel || null;

  if (!institutionId || !institutionPrefix) {
    throw new HttpsError('invalid-argument', 'Missing institution details.');
  }
  if (!Number.isInteger(count) || count <= 0 || count > 2000) {
    throw new HttpsError('invalid-argument', 'Count must be between 1 and 2000.');
  }

  assertInstitutionAdmin(userData, institutionId);

  const instSnap = await db.collection(COL_INSTITUTIONS).doc(institutionId).get();
  if (!instSnap.exists) {
    throw new HttpsError('not-found', 'Institution not found.');
  }

  const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const codes = new Set();
  const batch = db.batch();

  while (codes.size < count) {
    let suffix = '';
    for (let i = 0; i < 6; i++) {
      suffix += alphabet[Math.floor(Math.random() * alphabet.length)];
    }
    const code = `${institutionPrefix}-${suffix}`;
    if (codes.has(code)) continue; // extremely unlikely collision
    codes.add(code);

    const ref = db.collection(COL_SERIALS).doc(code);
    batch.set(ref, {
      institutionId,
      status: 'unclaimed',
      claimedByUid: null,
      claimedAt: null,
      createdAt: FieldValue.serverTimestamp(),
      createdBy: auth.uid,
      ...(classLevel ? { classLevel } : {}),
    });
  }

  await batch.commit();
  return { codes: Array.from(codes) };
});

// ─── revokeSerial ───────────────────────────────────────────────────────
// Admin-only. Invalidates an unclaimed or claimed serial.
exports.revokeSerial = onCall(async (request) => {
  const { auth, data } = request;
  const { data: userData } = await requireUser(auth);

  const code = String(data.code || '').trim().toUpperCase();
  if (!code) throw new HttpsError('invalid-argument', 'Missing serial code.');

  const ref = db.collection(COL_SERIALS).doc(code);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Serial number not found.');

  assertInstitutionAdmin(userData, snap.data().institutionId);

  await ref.update({ status: 'revoked' });
  return { success: true };
});
