// Firebase Cloud Messaging (HTTP v1) from an Edge Function: sign a service-account JWT, trade it for an access
// token, send. Uses only Web Crypto + fetch, so the signing is unit-tested under Node (fcm.test.ts).
// The network calls themselves have never run against Firebase: no project exists yet (docs/PUSH.md).

export type ServiceAccount = { client_email: string; private_key: string; project_id: string };

const b64url = (data: ArrayBuffer | string): string => {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
};

const pemToDer = (pem: string): ArrayBuffer => {
  const b64 = pem.replace(/-----(BEGIN|END) PRIVATE KEY-----/g, '').replace(/\s+/g, '');
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
};

/** A signed RS256 JWT asking Google for a `firebase.messaging` access token. */
export async function signJwt(sa: ServiceAccount, nowSeconds: number): Promise<string> {
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: nowSeconds,
      exp: nowSeconds + 3600,
    }),
  );
  const key = await crypto.subtle.importKey('pkcs8', pemToDer(sa.private_key), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claims}`));
  return `${header}.${claims}.${b64url(sig)}`;
}

let cached: { token: string; expires: number } | null = null;

export async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.expires - 60 > now) return cached.token;
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: await signJwt(sa, now) }),
  });
  if (!res.ok) throw new Error(`google oauth ${res.status}`);
  const j = await res.json();
  cached = { token: j.access_token, expires: now + (j.expires_in ?? 3600) };
  return cached.token;
}

export type SendResult = { ok: true } | { ok: false; gone: boolean; status: number };

/** Sends one message. `gone` means the token is dead (uninstalled / rotated): delete the device row. */
export async function sendFcm(sa: ServiceAccount, body: unknown): Promise<SendResult> {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: 'POST',
    headers: { authorization: `Bearer ${await accessToken(sa)}`, 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (res.ok) return { ok: true };
  const text = await res.text();
  return { ok: false, gone: res.status === 404 || text.includes('UNREGISTERED'), status: res.status };
}
