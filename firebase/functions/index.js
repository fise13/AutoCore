// Firebase Cloud Functions for syncing custom claims and invite join flow.

const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

exports.syncUserClaims = functions.firestore
  .document('users/{userId}')
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    const data = change.after.data();
    if (!data) {
      return null;
    }

    const companyId = data.companyId || null;
    const role = data.role || 'viewer';

    await admin.auth().setCustomUserClaims(userId, { companyId, role });
    return null;
  });

/** Заменяет кириллицу на латиницу (при копировании кода пользователь может получить похожие символы). */
function normalizeInviteCode(str) {
  const map = { 'А': 'A', 'В': 'B', 'С': 'C', 'Е': 'E', 'Н': 'H', 'К': 'K', 'М': 'M', 'О': 'O',
    'Р': 'P', 'Т': 'T', 'У': 'Y', 'Х': 'X', 'а': 'A', 'в': 'B', 'с': 'C', 'е': 'E',
    'н': 'H', 'к': 'K', 'м': 'M', 'о': 'O', 'р': 'P', 'т': 'T', 'у': 'Y', 'х': 'X' };
  return str.split('').map(c => map[c] || c).join('');
}

/**
 * Callable: join company by invite code.
 * Fixes "Missing or insufficient permissions" — joining user cannot update invites (needs owner/admin).
 * Runs with admin privileges: validates invite, updates user doc, marks invite used.
 */
exports.joinCompanyWithInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Необходим вход в систему');
  }
  let inviteCode = (data?.inviteCode || '').toString().trim().toUpperCase();
  inviteCode = normalizeInviteCode(inviteCode);
  if (!inviteCode) {
    throw new functions.https.HttpsError('invalid-argument', 'Укажите код приглашения');
  }

  const snapshot = await db.collection('invites')
    .where('code', '==', inviteCode)
    .limit(1)
    .get();

  if (snapshot.empty) {
    throw new functions.https.HttpsError('not-found', 'Код приглашения не найден. Проверьте правильность кода и попробуйте снова.');
  }

  const doc = snapshot.docs[0];
  const docData = doc.data();
  const used = docData.used === true;
  const expiresAt = docData.expiresAt?.toDate?.() || new Date(0);

  if (used) {
    throw new functions.https.HttpsError('failed-precondition', 'Код приглашения уже использован');
  }
  if (expiresAt <= new Date()) {
    throw new functions.https.HttpsError('failed-precondition', 'Срок действия кода истёк');
  }

  const companyId = docData.companyId || '';
  const role = docData.role || 'viewer';
  const userId = context.auth.uid;

  await db.collection('users').doc(userId).set({
    companyId,
    role,
  }, { merge: true });

  await doc.ref.update({ used: true });

  return { success: true, companyId, role };
});

