// Cloudflare Worker for StudentPro push notifications.
// Store the complete Firebase service-account JSON in the Worker secret named
// FIREBASE_SERVICE_ACCOUNT_JSON. Never put that JSON in the Flutter app.

const json = (value, status = 200) =>
  new Response(JSON.stringify(value), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });

const base64Url = (bytes) =>
  btoa(String.fromCharCode(...new Uint8Array(bytes)))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');

const decodeBase64Url = (value) => {
  const base64 = value.replaceAll('-', '+').replaceAll('_', '/')
    + '='.repeat((4 - (value.length % 4)) % 4);
  return Uint8Array.from(atob(base64), (char) => char.charCodeAt(0));
};

const utf8 = new TextEncoder();

function pemBytes(pem) {
  const body = pem.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  return Uint8Array.from(atob(body), (char) => char.charCodeAt(0));
}

async function googleAccessToken(account) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(utf8.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claim = base64Url(utf8.encode(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })));
  const signingInput = `${header}.${claim}`;
  const key = await crypto.subtle.importKey(
    'pkcs8', pemBytes(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' }, key, utf8.encode(signingInput),
  );
  const assertion = `${signingInput}.${base64Url(signature)}`;
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) throw new Error(`Google OAuth failed: ${await response.text()}`);
  return (await response.json()).access_token;
}

async function verifyFirebaseIdToken(idToken, projectId) {
  const [headerPart, payloadPart, signaturePart] = idToken.split('.');
  if (!headerPart || !payloadPart || !signaturePart) throw new Error('Invalid login token');
  const header = JSON.parse(new TextDecoder().decode(decodeBase64Url(headerPart)));
  const payload = JSON.parse(new TextDecoder().decode(decodeBase64Url(payloadPart)));
  const certificates = await (await fetch(
    'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com',
  )).json();
  const certificate = certificates[header.kid];
  if (!certificate) throw new Error('Unknown login token key');
  const key = await crypto.subtle.importKey(
    'spki', pemBytes(certificate),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify'],
  );
  const valid = await crypto.subtle.verify(
    { name: 'RSASSA-PKCS1-v1_5' }, key, decodeBase64Url(signaturePart),
    utf8.encode(`${headerPart}.${payloadPart}`),
  );
  if (!valid || payload.aud !== projectId ||
      payload.iss !== `https://securetoken.google.com/${projectId}` ||
      payload.exp <= Math.floor(Date.now() / 1000) || !payload.sub) {
    throw new Error('Login token is not valid');
  }
  return payload.sub;
}

async function firestoreDocument(projectId, accessToken, path) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${path}`,
    { headers: { authorization: `Bearer ${accessToken}` } },
  );
  if (!response.ok) return null;
  return response.json();
}

async function firestoreApplicant(projectId, accessToken, jobId, studentId) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:runQuery`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'job_applications' }],
          where: {
            compositeFilter: {
              op: 'AND',
              filters: [
                { fieldFilter: { field: { fieldPath: 'job_id' }, op: 'EQUAL', value: { stringValue: jobId } } },
                { fieldFilter: { field: { fieldPath: 'student_id' }, op: 'EQUAL', value: { stringValue: studentId } } },
              ],
            },
          },
          limit: 1,
        },
      }),
    },
  );
  if (!response.ok) throw new Error(`Firestore query failed: ${await response.text()}`);
  const rows = await response.json();
  return rows.find((row) => row.document)?.document ?? null;
}

const stringField = (doc, field) => doc?.fields?.[field]?.stringValue;
const arrayStrings = (doc, field) =>
  (doc?.fields?.[field]?.arrayValue?.values ?? []).map((item) => item.stringValue);

async function sendPush({ account, token, title, body, type, roomId, jobId }) {
  const accessToken = await googleAccessToken(account);
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: {
            type,
            ...(roomId ? { roomId } : {}),
            ...(jobId ? { jobId } : {}),
          },
          android: { priority: 'high' },
        },
      }),
    },
  );
  if (!response.ok) throw new Error(`FCM failed: ${await response.text()}`);
}

export default {
  async fetch(request, env) {
    if (request.method === 'GET') return json({ ok: true, service: 'studentpro-push' });
    if (request.method !== 'POST' || new URL(request.url).pathname !== '/send') {
      return json({ error: 'Not found' }, 404);
    }

    try {
      const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
      const auth = request.headers.get('authorization') ?? '';
      if (!auth.startsWith('Bearer ')) return json({ error: 'Sign in required' }, 401);
      const senderId = await verifyFirebaseIdToken(auth.substring(7), account.project_id);
      const { type = 'chat', roomId, jobId, recipientId, title, body } = await request.json();
      if (!['chat', 'job', 'review'].includes(type) ||
          ![recipientId, title, body].every((item) => typeof item === 'string' && item)) {
        return json({ error: 'type, recipientId, title, and body are required' }, 400);
      }

      const accessToken = await googleAccessToken(account);
      if (type === 'chat') {
        if (typeof roomId !== 'string' || !roomId) return json({ error: 'roomId is required' }, 400);
        const room = await firestoreDocument(account.project_id, accessToken, `chat_rooms/${roomId}`);
        const participants = arrayStrings(room, 'participant_ids');
        if (!participants.includes(senderId) || !participants.includes(recipientId)) {
          return json({ error: 'You are not allowed to notify this user' }, 403);
        }
      } else {
        if (typeof jobId !== 'string' || !jobId) return json({ error: 'jobId is required' }, 400);
        const job = await firestoreDocument(account.project_id, accessToken, `jobs/${jobId}`);
        const employerId = stringField(job, 'emp_id');
        const studentId = stringField(job, 'std_id');
        let authorized = Boolean(employerId && studentId && (
          (senderId === employerId && recipientId === studentId) ||
          (senderId === studentId && recipientId === employerId)
        ));
        // A new application is sent before the job has an assigned student.
        if (type === 'job' && employerId && recipientId === employerId && senderId !== employerId) {
          const applicant = await firestoreApplicant(account.project_id, accessToken, jobId, senderId);
          const sender = await firestoreDocument(account.project_id, accessToken, `users/${senderId}`);
          authorized = Boolean(applicant && stringField(sender, 'u_role') === 'student');
        }
        if (!authorized || senderId === recipientId) {
          return json({ error: 'Sender and recipient must be the two users assigned to this job' }, 403);
        }
        if (type === 'review') {
          const review = await firestoreDocument(account.project_id, accessToken, `reviews/${jobId}`);
          if (stringField(review, 'reviewer_id') !== senderId ||
              stringField(review, 'reviewee_id') !== recipientId ||
              stringField(job, 'job_status') !== 'Done') {
            return json({ error: 'Review does not authorize this notification' }, 403);
          }
        }
      }

      const device = await firestoreDocument(account.project_id, accessToken, `devices/${recipientId}`);
      const fcmToken = stringField(device, 'fcm_token');
      if (!fcmToken) return json({ error: 'Recipient has not enabled notifications' }, 409);

      await sendPush({
        account, token: fcmToken, title, body, type,
        roomId: type === 'chat' ? roomId : undefined,
        jobId: type === 'chat' ? undefined : jobId,
      });
      return json({ ok: true });
    } catch (error) {
      console.error(error);
      return json({ error: 'Push delivery failed' }, 500);
    }
  },
};
