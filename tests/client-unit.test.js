import { test } from "node:test";
import assert from "node:assert/strict";
import { Client } from "../web/api.js";
import { artifactFile, artifactPreview, bytesLabel } from "../web/studio.js";
const makeVault = () => ({
  data: { cache: {}, pending: [], token: "token" },
  writes: 0,
  async save() {
    this.writes++;
  },
});
const response = (data, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
Object.defineProperty(globalThis, "navigator", {
  value: { onLine: true },
  configurable: true,
});
test("SYNC01 persist before request; unknown success retries the same idempotency key", async () => {
  const vault = makeVault(),
    client = new Client(vault);
  let attempts = 0;
  const keys = [];
  globalThis.fetch = async (_url, options) => {
    assert.ok(vault.writes > 0);
    keys.push(options.headers["Idempotency-Key"]);
    if (attempts++ === 0)
      throw new TypeError("Network timed out after server commit");
    return response({ wallet: { coins: 2 } });
  };
  await client.mutate(
    "/api/cards/card/review",
    { known: true },
    { queue: true, key: "stable-operation-key" },
  );
  assert.equal(vault.data.pending.length, 1);
  await client.sync();
  assert.equal(vault.data.pending.length, 0);
  assert.deepEqual(keys, ["stable-operation-key", "stable-operation-key"]);
});
test("SYNC02 permanent conflicts are retained visibly, not silently dropped", async () => {
  const vault = makeVault(),
    client = new Client(vault);
  globalThis.fetch = async () =>
    response(
      { error: { code: "VERSION_CONFLICT", message: "Resolve conflict" } },
      409,
    );
  await client.mutate(
    "/api/decks/deck",
    { title: "Edited" },
    { method: "PUT", queue: true },
  );
  assert.equal(vault.data.pending.length, 1);
  assert.match(vault.data.pending[0].error, /VERSION_CONFLICT/);
});
test("SYNC03 session expiry leaves work queued for reauthentication", async () => {
  const vault = makeVault(),
    client = new Client(vault);
  globalThis.fetch = async () =>
    response({ error: { code: "AUTH_REQUIRED", message: "Sign in" } }, 401);
  await client.mutate("/api/study/offline", { id: "session" }, { queue: true });
  assert.equal(vault.data.pending.length, 1);
  assert.equal(vault.data.pending[0].error, null);
});
test("SYNC04 offline reads use the previously saved snapshot", async () => {
  const vault = makeVault();
  vault.data.cache["/api/progress"] = { data: { topics: [] }, at: 1 };
  globalThis.fetch = async () => {
    throw new TypeError("offline");
  };
  const result = await new Client(vault).request("/api/progress");
  assert.equal(result.offline, true);
  assert.deepEqual(result.topics, []);
});
test("SYNC05 queue processes at most 20 operations per batch", async () => {
  const vault = makeVault(),
    client = new Client(vault);
  vault.data.pending = Array.from({ length: 55 }, (_, i) => ({
    id: "operation-" + i,
    path: "/api/study/offline",
    method: "POST",
    body: { id: i },
    error: null,
  }));
  globalThis.fetch = async () => response({ ok: true });
  await client.sync();
  assert.equal(vault.data.pending.length, 35);
});
test("SYNC06 admin responses never enter offline cache", async () => {
  const vault = makeVault();
  globalThis.fetch = async () => response({ private: "moderation" });
  await new Client(vault).request("/api/admin");
  assert.deepEqual(vault.data.cache, {});
});

import { previewCSV } from "../web/import.js";
test("CSV04 offline quoted multiline Unicode import and duplicates", () => {
  const result = previewCSV('front,back\n"Ano, ini?","Pagtuon\n📖"\nQ,A\nQ,A');
  assert.equal(result.valid.length, 3);
  assert.equal(result.valid[0].back, "Pagtuon\n📖");
  assert.equal(result.duplicates.length, 1);
});
test("CSV05 malformed quote and oversized field stay out of valid import", () => {
  const result = previewCSV('a"b,c\n' + "x".repeat(4001) + ",answer");
  assert.equal(result.valid.length, 0);
  assert.equal(result.errors.length, 2);
});
test("STUDIO01 generated cards render safely and export as Quizlet CSV", async () => {
  const artifact = {
    title: "Biology review",
    kind: "flashcards",
    body: JSON.stringify([{ front: '<script>alert("x")</script>', back: 'Cells "divide"' }]),
  };
  const escape = (value) => String(value).replaceAll("<", "&lt;").replaceAll(">", "&gt;");
  assert.doesNotMatch(artifactPreview(artifact, escape), /<script>/);
  const output = artifactFile(artifact);
  assert.equal(output.name, "Biology_review.csv");
  assert.match(await output.blob.text(), /"Cells ""divide"""/);
  assert.equal(bytesLabel(2 * 1024 * 1024), "2.0 MB");
});
