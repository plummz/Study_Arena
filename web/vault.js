const enc = new TextEncoder(),
  dec = new TextDecoder();
let dbPromise;
function database() {
  return (dbPromise ||= new Promise((resolve, reject) => {
    const r = indexedDB.open("study-arena-v1", 1);
    r.onupgradeneeded = () => r.result.createObjectStore("vaults");
    r.onsuccess = () => resolve(r.result);
    r.onerror = () => reject(r.error);
  }));
}
async function read(key) {
  const db = await database();
  return new Promise((ok, no) => {
    const r = db.transaction("vaults").objectStore("vaults").get(key);
    r.onsuccess = () => ok(r.result);
    r.onerror = () => no(r.error);
  });
}
async function write(key, value) {
  const db = await database();
  return new Promise((ok, no) => {
    const tx = db.transaction("vaults", "readwrite");
    tx.objectStore("vaults").put(value, key);
    tx.oncomplete = ok;
    tx.onerror = () => no(tx.error);
    tx.onabort = () => no(tx.error);
  });
}
async function derive(password, salt) {
  const material = await crypto.subtle.importKey(
    "raw",
    enc.encode(password),
    "PBKDF2",
    false,
    ["deriveKey"],
  );
  return crypto.subtle.deriveKey(
    { name: "PBKDF2", salt, iterations: 250000, hash: "SHA-256" },
    material,
    { name: "AES-GCM", length: 256 },
    false,
    ["encrypt", "decrypt"],
  );
}
export class Vault {
  constructor(email, key, salt, data) {
    Object.assign(this, { email, key, salt, data });
    this.writes = Promise.resolve();
  }
  static async open(email, password) {
    email = email.trim().toLowerCase();
    const record = await read(email);
    const salt = record?.salt || crypto.getRandomValues(new Uint8Array(16));
    const key = await derive(password, salt);
    let data = {
      cache: {},
      pending: [],
      history: [],
      attempts: {},
      reviews: {},
      downloads: {},
      theme: "light",
    };
    if (record) {
      try {
        data = JSON.parse(
          dec.decode(
            await crypto.subtle.decrypt(
              { name: "AES-GCM", iv: record.iv },
              key,
              record.encrypted,
            ),
          ),
        );
      } catch {
        throw new Error(
          "This device has an encrypted study workspace for this email. Unlock it with the password used when it was saved. If you changed your password, export unsynced work using the previous password before replacing it.",
        );
      }
    }
    const vault = new Vault(email, key, salt, data);
    await vault.save();
    return vault;
  }
  save() {
    // Serialize both encryption and writes; an older encryption must never overwrite newer work.
    const snapshot = JSON.stringify(this.data);
    this.writes = this.writes
      .catch(() => {})
      .then(async () => {
        const iv = crypto.getRandomValues(new Uint8Array(12));
        const encrypted = await crypto.subtle.encrypt(
          { name: "AES-GCM", iv },
          this.key,
          enc.encode(snapshot),
        );
        await write(this.email, { salt: this.salt, iv, encrypted });
      });
    return this.writes;
  }
}
// "Keep me signed in": the workspace key is a non-extractable CryptoKey, so IndexedDB can hold
// it without its raw bytes ever being readable by script. The password itself is never stored.
// Signing out (lock) deletes it; without it the password is needed again.
const SESSION = "__remembered_session__";
export async function rememberSession(vault) {
  await write(SESSION, { email: vault.email, key: vault.key, salt: vault.salt });
}
export async function forgetSession() {
  const db = await database();
  await new Promise((ok, no) => {
    const tx = db.transaction("vaults", "readwrite");
    tx.objectStore("vaults").delete(SESSION);
    tx.oncomplete = ok;
    tx.onerror = () => no(tx.error);
  });
}
export async function resumeSession() {
  const session = await read(SESSION).catch(() => null);
  if (!session?.key) return null;
  const record = await read(session.email);
  try {
    const data = JSON.parse(
      dec.decode(
        await crypto.subtle.decrypt({ name: "AES-GCM", iv: record.iv }, session.key, record.encrypted),
      ),
    );
    return new Vault(session.email, session.key, record.salt, data);
  } catch {
    await forgetSession();
    return null;
  }
}
export const uuid = () => crypto.randomUUID();
export const digest = async (bytes) =>
  Array.from(
    new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
