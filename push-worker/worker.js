/**
 * TUP Announcement App - push notification relay (Cloudflare Worker, free plan).
 *
 * Flow:
 *   1. The app publishes an announcement to Firestore.
 *   2. The app calls this Worker with the officer's Firebase login token and
 *      the new announcement's ID.
 *   3. The Worker checks that:
 *        - the token is a real, unexpired Firebase login for THIS project,
 *        - the announcement exists, was created by that same user,
 *          was created in the last 10 minutes,
 *        - it has not already been announced (so no duplicates / spam).
 *   4. The Worker sends ONE push to the FCM topic "uni" (everyone).
 *
 * Required secret (Worker -> Settings -> Variables and Secrets):
 *   SERVICE_ACCOUNT_JSON = the full contents of the Firebase service-account key file.
 */

const MAX_AGE_MS = 10 * 60 * 1000;
const TOPIC = "uni";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type",
};

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: {"Content-Type": "application/json", ...CORS},
  });

// ---------- base64 helpers ----------
const b64urlToBytes = (s) => {
  s = s.replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
};
const bytesToB64url = (bytes) => {
  let bin = "";
  for (const b of new Uint8Array(bytes)) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};
const strToB64url = (s) => bytesToB64url(new TextEncoder().encode(s));
const decodeJson = (part) => JSON.parse(new TextDecoder().decode(b64urlToBytes(part)));

// ---------- verify the officer's Firebase login token ----------
const JWK_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
let jwkCache = {keys: null, at: 0};

async function getJwks() {
  if (jwkCache.keys && Date.now() - jwkCache.at < 60 * 60 * 1000) return jwkCache.keys;
  const res = await fetch(JWK_URL);
  if (!res.ok) throw new Error("Could not fetch Google signing keys");
  const data = await res.json();
  jwkCache = {keys: data.keys, at: Date.now()};
  return data.keys;
}

async function verifyFirebaseToken(idToken, projectId) {
  const parts = String(idToken || "").split(".");
  if (parts.length !== 3) throw new Error("Malformed token");
  const header = decodeJson(parts[0]);
  const claims = decodeJson(parts[1]);
  if (header.alg !== "RS256" || !header.kid) throw new Error("Bad token header");

  const jwk = (await getJwks()).find((k) => k.kid === header.kid);
  if (!jwk) throw new Error("Unknown signing key");
  const key = await crypto.subtle.importKey(
      "jwk", jwk, {name: "RSASSA-PKCS1-v1_5", hash: "SHA-256"}, false, ["verify"]);
  const ok = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5", key, b64urlToBytes(parts[2]),
      new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
  if (!ok) throw new Error("Bad token signature");

  const now = Math.floor(Date.now() / 1000);
  if (claims.aud !== projectId) throw new Error("Token is for another project");
  if (claims.iss !== `https://securetoken.google.com/${projectId}`) throw new Error("Bad issuer");
  if (!claims.exp || claims.exp < now) throw new Error("Token expired");
  if (claims.iat && claims.iat > now + 300) throw new Error("Token from the future");
  if (!claims.sub) throw new Error("No user in token");
  return claims.sub; // the user's uid
}

// ---------- Google OAuth for the service account ----------
let tokenCache = {token: null, exp: 0};

async function getAccessToken(sa) {
  if (tokenCache.token && Date.now() < tokenCache.exp - 60000) return tokenCache.token;

  const iat = Math.floor(Date.now() / 1000);
  const head = strToB64url(JSON.stringify({alg: "RS256", typ: "JWT"}));
  const body = strToB64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/cloud-platform",
    aud: "https://oauth2.googleapis.com/token",
    iat,
    exp: iat + 3600,
  }));

  const pem = sa.private_key
      .replace(/-----BEGIN PRIVATE KEY-----/, "")
      .replace(/-----END PRIVATE KEY-----/, "")
      .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
      "pkcs8", der, {name: "RSASSA-PKCS1-v1_5", hash: "SHA-256"}, false, ["sign"]);
  const sig = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${head}.${body}`));

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${head}.${body}.${bytesToB64url(sig)}`,
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Google auth failed: ${data.error_description || data.error}`);
  tokenCache = {token: data.access_token, exp: Date.now() + data.expires_in * 1000};
  return data.access_token;
}

// ---------- Firestore (REST) ----------
const docUrl = (pid, id) =>
  `https://firestore.googleapis.com/v1/projects/${pid}/databases/(default)/documents/announcements/${id}`;

const str = (f) => (f && f.stringValue) || "";

const truncate = (s, n) => {
  const t = String(s || "").replace(/\s+/g, " ").trim();
  return t.length > n ? `${t.slice(0, n - 1)}…` : t;
};

async function markNotified(pid, id, updateTime, access) {
  // Compare-and-set: only succeeds if nobody changed the doc since we read it.
  const url = `${docUrl(pid, id)}?updateMask.fieldPaths=notifiedAt` +
    `&currentDocument.updateTime=${encodeURIComponent(updateTime)}`;
  const res = await fetch(url, {
    method: "PATCH",
    headers: {Authorization: `Bearer ${access}`, "Content-Type": "application/json"},
    body: JSON.stringify({fields: {notifiedAt: {timestampValue: new Date().toISOString()}}}),
  });
  return res.ok;
}

async function unmarkNotified(pid, id, access) {
  await fetch(`${docUrl(pid, id)}?updateMask.fieldPaths=notifiedAt`, {
    method: "PATCH",
    headers: {Authorization: `Bearer ${access}`, "Content-Type": "application/json"},
    body: JSON.stringify({fields: {}}),
  });
}

// ---------- main handler ----------
export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, {status: 204, headers: CORS});
    if (request.method !== "POST") return json({error: "Use POST"}, 405);

    let sa;
    try {
      sa = JSON.parse(env.SERVICE_ACCOUNT_JSON);
    } catch {
      return json({error: "Server is missing SERVICE_ACCOUNT_JSON"}, 500);
    }
    const pid = sa.project_id;

    // 1. Who is calling?
    let uid;
    try {
      const auth = request.headers.get("Authorization") || "";
      uid = await verifyFirebaseToken(auth.replace(/^Bearer\s+/i, ""), pid);
    } catch (e) {
      return json({error: `Unauthorized: ${e.message}`}, 401);
    }

    // 2. Which announcement?
    let announcementId = "";
    try {
      announcementId = String((await request.json()).announcementId || "");
    } catch {}
    if (!/^[A-Za-z0-9]{10,40}$/.test(announcementId)) {
      return json({error: "Bad announcementId"}, 400);
    }

    try {
      const access = await getAccessToken(sa);

      // 3. Read the announcement and check it.
      const res = await fetch(docUrl(pid, announcementId), {
        headers: {Authorization: `Bearer ${access}`},
      });
      if (res.status === 404) return json({error: "Announcement not found"}, 404);
      if (!res.ok) return json({error: "Could not read announcement"}, 502);
      const doc = await res.json();
      const f = doc.fields || {};

      if (str(f.createdBy) !== uid) return json({error: "Not your announcement"}, 403);
      if (Date.now() - new Date(doc.createTime).getTime() > MAX_AGE_MS) {
        return json({error: "Announcement is too old to notify"}, 410);
      }
      if (f.notifiedAt) return json({ok: true, alreadySent: true});

      // 4. Claim it, then send.
      if (!(await markNotified(pid, announcementId, doc.updateTime, access))) {
        return json({ok: true, alreadySent: true});
      }

      const category = str(f.category) || "Announcement";
      const urgent = category === "Class Suspension" || category === "Emergency Alerts";

      const push = await fetch(`https://fcm.googleapis.com/v1/projects/${pid}/messages:send`, {
        method: "POST",
        headers: {Authorization: `Bearer ${access}`, "Content-Type": "application/json"},
        body: JSON.stringify({
          message: {
            topic: TOPIC,
            notification: {
              title: `${category}: ${truncate(str(f.title), 80)}`,
              body: truncate(str(f.description), 140),
            },
            data: {announcementId, category},
            android: {priority: urgent ? "HIGH" : "NORMAL"},
            apns: {headers: {"apns-priority": urgent ? "10" : "5"}},
          },
        }),
      });

      if (!push.ok) {
        await unmarkNotified(pid, announcementId, access); // allow a retry
        const detail = await push.text();
        return json({error: "FCM send failed", detail: detail.slice(0, 500)}, 502);
      }
      return json({ok: true, sent: true});
    } catch (e) {
      return json({error: `Server error: ${e.message}`}, 500);
    }
  },
};
