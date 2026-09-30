import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { server } from "./server.mjs";
let app, student, teacher, admin, other, minor, privateDeck, room;
const uid = () => crypto.randomUUID();
async function api(
  path,
  { token, ticket, method = "GET", body, key, status = 200 } = {},
) {
  const r = await fetch(app.url + path, {
    method,
    headers: {
      ...(token ? { Authorization: "Bearer " + token } : {}),
      ...(ticket ? { "X-Dungeon-Ticket": ticket } : {}),
      ...(body
        ? {
            "Content-Type": "application/json",
            "Idempotency-Key": key || uid(),
          }
        : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const data = await r.json();
  assert.equal(r.status, status, `${method} ${path}: ${JSON.stringify(data)}`);
  return data;
}
async function login(email) {
  return api("/api/auth/login", {
    method: "POST",
    body: { email, password: "StudyArena!2026" },
  });
}
async function register(name, age = "adult", verify = true) {
  const email = name + "@study.test";
  await api("/api/auth/register", {
    method: "POST",
    body: {
      email,
      password: "StudyArena!2026",
      school_id: "ID-" + name,
      display_name: name,
      age_band: age,
    },
  });
  if (verify) {
    const mail = await api("/api/demo/mail?email=" + email);
    const token = mail.items[0].body.match(/token=([^\s]+)/)[1];
    await api("/api/auth/verify", { method: "POST", body: { token } });
  }
  return login(email);
}
async function preferences(account, competition) {
  const result = await api("/api/me", {
    method: "PUT",
    token: account.token,
    body: {
      ...account.user,
      version: account.user.version,
      competition,
      role: "admin",
    },
  });
  account.user = result.user;
  return result;
}
// The integration server uses an isolated synthetic SQLite database. These narrow fixture
// changes make time and daily-cap boundaries deterministic without long real-time waits.
function dungeonFixture(sql, params = []) {
  const script = `import json, sqlite3, sys
db = sqlite3.connect(sys.argv[1], timeout=5)
row = db.execute(sys.argv[2], json.loads(sys.argv[3])).fetchone()
db.commit()
print(json.dumps(row))`;
  const python = process.platform === "win32" ? "python" : "python3";
  return JSON.parse(execFileSync(python, ["-c", script, path.join(app.dir, "arena.db"), sql, JSON.stringify(params)], { encoding: "utf8" }));
}
before(async () => {
  app = await server();
  student = await login("student@study.test");
  teacher = await login("teacher@study.test");
  admin = await login("admin@study.test");
  other = await register("peer");
  minor = await register("minor", "minor");
});
after(async () => {
  console.log(
    app.logs().includes("exception=")
      ? "Server exceptions occurred; inspect failed tests."
      : "No unhandled server exceptions during integration tests.",
  );
  await app.stop();
});
test("A01 duplicate identities rejected; role elevation ignored", async () => {
  await api("/api/auth/register", {
    method: "POST",
    body: {
      email: "peer@study.test",
      password: "StudyArena!2026",
      school_id: "other-school",
      display_name: "Peer duplicate",
      age_band: "adult",
    },
    status: 409,
  });
  const p = await preferences(student, false);
  assert.equal(p.user.role, "student");
  assert.equal(p.user.competition, 0);
});
test("A02 verification one-time token; unverified competition blocked", async () => {
  const u = await register("unverified", "adult", false);
  await preferences(u, true);
  const error = await api("/api/duels/queue", {
    token: u.token,
    method: "POST",
    body: { topic_id: "algebra" },
    status: 403,
  });
  assert.equal(error.error.code, "EMAIL_UNVERIFIED");
});
test("A03 private logs and admin routes enforce object and role access", async () => {
  await api("/api/admin", { token: student.token, status: 403 });
  const t = await api("/api/admin", { token: teacher.token });
  assert.equal(t.aggregate.suppressed, true);
  assert.equal(t.users, undefined);
  assert.equal(t.ledger, undefined);
});
test("A05 login records a streak and returns free companion milestones", async () => {
  const signedIn = await login("student@study.test");
  assert.ok(signedIn.login_streak.current >= 1);
  assert.ok(Array.isArray(signedIn.login_streak.unlocks));
});
test("S01 private sources accept arbitrary files; text creates grounded tools", async () => {
  async function upload(account, name, mime, content) {
    const bytes = Buffer.from(content), sha256 = await crypto.subtle.digest("SHA-256", bytes), digest = Buffer.from(sha256).toString("hex");
    const created = await api("/api/studio/sources", { token: account.token, method: "POST", body: { title: name, filename: name, mime, bytes: bytes.length, sha256: digest } });
    await api(`/api/studio/sources/${created.source.id}/chunks`, { token: account.token, method: "POST", body: { offset: 0, base64: bytes.toString("base64"), complete: true } });
    return created.source.id;
  }
  const binaryId = await upload(student, "archive.bin", "application/octet-stream", Buffer.from([0, 1, 2, 3]));
  await api("/api/studio/generate", { token: student.token, method: "POST", body: { source_id: binaryId, kind: "reviewer" }, status: 409 });
  await api(`/api/studio/sources/${binaryId}/chunks`, { token: other.token, method: "POST", body: { offset: 0, base64: "AA==", complete: true }, status: 404 });
  const textId = await upload(student, "physics.txt", "text/plain", "Force is mass multiplied by acceleration. Acceleration measures change in velocity over time. Net force is the vector sum of forces on an object.");
  const generated = await api("/api/studio/generate", { token: student.token, method: "POST", body: { source_id: textId, kind: "flashcards" } });
  assert.equal(generated.artifact.ai, 0);
  assert.ok(JSON.parse(generated.artifact.body).length >= 2);
  await api(`/api/studio/artifacts/${generated.artifact.id}`, { token: other.token, status: 404 });
});
test("S02 private folder files are encrypted at rest, download intact, and stay owner-only", async () => {
  // 1.5 MiB of synthetic bytes spans two encrypted segments; the marker must not appear on disk.
  const marker = Buffer.from("SYNTHETIC-PRIVATE-NOTE-MARKER"),
    bytes = Buffer.alloc(1536 * 1024);
  for (let i = 0; i < bytes.length; i += marker.length) marker.copy(bytes, i);
  const digest = Buffer.from(await crypto.subtle.digest("SHA-256", bytes)).toString("hex");
  const created = await api("/api/studio/sources", { token: student.token, method: "POST", body: { title: "Folder file", filename: "notes.bin", mime: "application/octet-stream", bytes: bytes.length, sha256: digest } });
  const id = created.source.id, chunk = 512 * 1024;
  for (let offset = 0; offset < bytes.length; offset += chunk)
    await api(`/api/studio/sources/${id}/chunks`, { token: student.token, method: "POST", body: { offset, base64: bytes.subarray(offset, offset + chunk).toString("base64"), complete: offset + chunk >= bytes.length } });
  const stored = await readFile(path.join(app.dir, "files", `studio-${id}.enc`));
  assert.equal(stored.subarray(0, 4).toString(), "SAF1");
  assert.equal(stored.includes(marker), false);
  const parts = [];
  let offset = 0, complete = false;
  while (!complete) {
    const piece = await api(`/api/studio/sources/${id}/file?offset=${offset}`, { token: student.token });
    assert.equal(piece.source.file_key, undefined);
    parts.push(Buffer.from(piece.base64, "base64"));
    offset = piece.next_offset;
    complete = piece.complete;
  }
  assert.equal(parts.length, 2);
  assert.ok(Buffer.concat(parts).equals(bytes));
  await api(`/api/studio/sources/${id}/file?offset=0`, { token: other.token, status: 404 });
  await api(`/api/studio/sources/${id}/file?offset=7`, { token: student.token, status: 422 });
  assert.equal((await api("/api/studio", { token: other.token })).sources.some((s) => s.id === id), false);
  await api(`/api/studio/sources/${id}`, { token: other.token, method: "DELETE", body: {}, status: 404 });
  await api(`/api/studio/sources/${id}`, { token: student.token, method: "DELETE", body: {} });
  await api(`/api/studio/sources/${id}/file?offset=0`, { token: student.token, status: 404 });
});
test("S03 private folder quota is 250 MB per student", async () => {
  const account = await register("folder"), max = 25 * 1024 * 1024, ids = [];
  const declare = (status = 200) =>
    api("/api/studio/sources", { token: account.token, method: "POST", status, body: { title: "Big", filename: "big.pdf", mime: "application/pdf", bytes: max, sha256: "a".repeat(64) } });
  for (let i = 0; i < 10; i++) ids.push((await declare()).source.id);
  const studio = await api("/api/studio", { token: account.token });
  assert.equal(studio.used_bytes, studio.quota_bytes);
  assert.equal((await declare(413)).error.code, "QUOTA");
  await api(`/api/studio/sources/${ids[0]}`, { token: account.token, method: "DELETE", body: {} });
  await declare();
});
test("C01 empty deck supported; no 501st card; Unicode preserved", async () => {
  const x = await api("/api/decks", {
    token: student.token,
    method: "POST",
    body: { title: "Hiligaynon notes", topic_id: "algebra", cards: [] },
  });
  privateDeck = x.deck;
  const empty = await api("/api/decks/" + x.deck.id, { token: student.token });
  assert.equal(empty.total, 0);
  await api("/api/decks/" + x.deck.id, { token: other.token, status: 404 });
  const cards = Array.from({ length: 501 }, (_, i) => ({
    front: "Pamangkot " + i,
    back: "Sabát " + i,
  }));
  await api("/api/decks", {
    token: student.token,
    method: "POST",
    body: { title: "Too big", topic_id: "algebra", cards },
    status: 422,
  });
  const valid = await api("/api/decks/" + x.deck.id, {
    token: student.token,
    method: "PUT",
    body: {
      version: 1,
      title: "Hiligaynon notes",
      topic_id: "algebra",
      cards: [
        {
          front: "Ano ang kahulugan sang “pagtuon”?",
          back: "Pagtuon — learning 📖",
        },
      ],
    },
  });
  assert.equal(valid.deck.version, 2);
  const result = await api("/api/decks/" + x.deck.id, { token: student.token });
  assert.equal(result.cards[0].back, "Pagtuon — learning 📖");
});
test("C02 CSV preview detects malformed and duplicate rows without writes", async () => {
  const result = await api("/api/import/preview", {
    token: student.token,
    method: "POST",
    body: {
      text: 'front,back\n"Question, with comma","Two lines\ninside"\nwrong\nA,B\nA,B\n',
      delimiter: ",",
    },
  });
  assert.equal(result.valid.length, 3);
  assert.equal(result.errors.length, 1);
  assert.equal(result.duplicates.length, 1);
});
test("C03 version conflict preserves a separate private copy", async () => {
  const result = await api("/api/decks/" + privateDeck.id, {
    token: student.token,
    method: "PUT",
    body: {
      version: 1,
      title: "Concurrent copy",
      topic_id: "algebra",
      cards: [{ front: "Other change", back: "Other answer" }],
    },
  });
  assert.equal(result.conflict_copy, true);
  assert.notEqual(result.deck.id, privateDeck.id);
});
test("C04 due review earns once; duplicate retry and repeated practice cannot farm coins", async () => {
  const deck = await api("/api/decks/" + privateDeck.id, {
    token: student.token,
  });
  const path = "/api/cards/" + deck.cards[0].id + "/review",
    key = uid();
  const first = await api(path, {
    token: student.token,
    method: "POST",
    body: { known: true },
    key,
  });
  const retry = await api(path, {
    token: student.token,
    method: "POST",
    body: { known: true },
    key,
  });
  assert.deepEqual(retry, first);
  const next = await api(path, {
    token: student.token,
    method: "POST",
    body: { known: true },
  });
  assert.equal(next.rewarded, false);
  assert.equal(next.wallet.coins, first.wallet.coins);
});
test("B01 short, valid, overlapping and clock-manipulated offline sessions", async () => {
  const now = Date.now() / 1000;
  const base = {
    id: uid(),
    topic_id: "algebra",
    started: now - 1200,
    ended: now - 1190,
    elapsed: 10,
    timezone: "Asia/Manila",
    notes: "Private test note",
  };
  let result = await api("/api/study/offline", {
    token: student.token,
    method: "POST",
    body: base,
  });
  assert.equal(result.session.credited, 0);
  const long = {
    ...base,
    id: uid(),
    started: now - 1000,
    ended: now - 400,
    elapsed: 600,
  };
  result = await api("/api/study/offline", {
    token: student.token,
    method: "POST",
    body: long,
  });
  assert.equal(result.session.credited, 10);
  const overlap = await api("/api/study/offline", {
    token: student.token,
    method: "POST",
    body: { ...long, id: uid() },
  });
  assert.equal(overlap.session.credited, 0);
  await api("/api/study/offline", {
    token: student.token,
    method: "POST",
    body: { ...long, id: uid(), elapsed: 99999 },
    status: 422,
  });
});
test("B02 only one connected active focus session; own access", async () => {
  const result = await api("/api/study/sessions", {
    token: other.token,
    method: "POST",
    body: { topic_id: "algebra", notes: "Private" },
  });
  await api("/api/study/sessions", {
    token: other.token,
    method: "POST",
    body: { topic_id: "algebra" },
    status: 409,
  });
  await api("/api/study/sessions/" + result.session.id, {
    token: student.token,
    method: "PUT",
    body: { action: "complete" },
    status: 404,
  });
  await api("/api/study/sessions/" + result.session.id, {
    token: other.token,
    method: "PUT",
    body: { action: "discard" },
  });
});
test("D01 no-answer quiz rejected; valid quiz requires independent approval", async () => {
  await api("/api/quizzes", {
    token: teacher.token,
    method: "POST",
    body: {
      title: "Invalid",
      topic_id: "algebra",
      source: "Original teacher questions",
      license: "CC BY",
      questions: [
        {
          kind: "mcq",
          prompt: "Question?",
          options: ["A", "B"],
          accepted: [],
          explanation: "Because.",
        },
      ],
    },
    status: 422,
  });
});
test("D02 solo answer explanations and private attempt boundaries", async () => {
  const result = await api("/api/quizzes/quiz-algebra/attempts", {
    token: student.token,
    method: "POST",
    body: { timed: false },
  });
  await api("/api/attempts/" + result.attempt.id, {
    token: other.token,
    status: 404,
  });
  const q = result.questions[0];
  const answer = await api("/api/attempts/" + result.attempt.id + "/answer", {
    token: student.token,
    method: "POST",
    body: { question_id: q.id, answer: q.accepted[0] },
  });
  assert.equal(answer.correct, true);
  assert.ok(answer.explanation.length > 10);
  await api("/api/attempts/" + result.attempt.id + "/finish", {
    token: student.token,
    method: "POST",
    body: { discard: true },
  });
});
test("D03 offline quiz result merges once and computes per-topic evidence", async () => {
  const quiz = await api("/api/quizzes/quiz-algebra");
  const now = Date.now() / 1000,
    id = uid(),
    body = {
      id,
      version: quiz.quiz.version,
      started: now - 100,
      ended: now,
      timed: false,
      answers: quiz.questions.map((q) => ({
        question_id: q.id,
        answer: q.accepted[0],
        elapsed: 50,
      })),
    };
  const first = await api("/api/quizzes/quiz-algebra/offline", {
    token: student.token,
    method: "POST",
    body,
    key: id,
  });
  const retry = await api("/api/quizzes/quiz-algebra/offline", {
    token: student.token,
    method: "POST",
    body,
    key: id,
  });
  assert.equal(first.attempt.score, 3);
  assert.deepEqual(retry, first);
  const progress = await api("/api/progress", { token: student.token });
  assert.ok(
    progress.topics.find((t) => t.id === "algebra").evidence_count >= 3,
  );
});
test("D04 answers after timed deadline are uncredited", async () => {
  const quiz = await api("/api/quizzes/quiz-computing"),
    now = Date.now() / 1000;
  const result = await api("/api/quizzes/quiz-computing/offline", {
    token: student.token,
    method: "POST",
    body: {
      id: uid(),
      version: 1,
      started: now - 400,
      ended: now,
      timed: true,
      answers: quiz.questions.map((q) => ({
        question_id: q.id,
        answer: q.accepted[0],
        elapsed: 350,
      })),
    },
  });
  assert.equal(result.attempt.score, 0);
});
test("J01 insufficient funds and idempotency payload conflict", async () => {
  await api("/api/shop/skin-fox/purchase", {
    token: other.token,
    method: "POST",
    body: {},
    status: 409,
  });
  const key = uid();
  await api("/api/admin/ledger", {
    token: admin.token,
    method: "POST",
    body: {
      user_id: student.user.id,
      xp: 0,
      coins: 100,
      origin: uid(),
      reason: "Integration fixture funding",
    },
    key,
  });
  await api("/api/admin/ledger", {
    token: admin.token,
    method: "POST",
    body: {
      user_id: student.user.id,
      xp: 0,
      coins: 200,
      origin: uid(),
      reason: "Different payload",
    },
    key,
    status: 409,
  });
});
test("J02 concurrent two-device purchase charges once and owned item is not repurchased", async () => {
  const before = (await api("/api/wallet", { token: student.token })).wallet
    .coins;
  const key = uid(),
    options = { token: student.token, method: "POST", body: {}, key };
  const [x, y] = await Promise.all([
    api("/api/shop/hat-leaf/purchase", options),
    api("/api/shop/hat-leaf/purchase", options),
  ]);
  assert.deepEqual(x, y);
  await api("/api/shop/hat-leaf/purchase", {
    token: student.token,
    method: "POST",
    body: {},
  });
  const after = (await api("/api/wallet", { token: student.token })).wallet
    .coins;
  assert.equal(before - after, 10);
});
test("J03 prize age gate and auditable denial refunds", async () => {
  await api("/api/admin/flags/prizes", {
    token: admin.token,
    method: "PUT",
    body: { enabled: true, reason: "Enable synthetic prize test" },
  });
  const gate = await api("/api/shop/school-kit/purchase", {
    token: minor.token,
    method: "POST",
    body: { rules_version: 1 },
    status: 403,
  });
  assert.equal(gate.error.code, "AGE_RESTRICTED");
  const before = (await api("/api/wallet", { token: student.token })).wallet
    .coins;
  const result = await api("/api/shop/school-kit/purchase", {
    token: student.token,
    method: "POST",
    body: { rules_version: 1 },
  });
  await api("/api/admin/claims/" + result.claim.id, {
    token: admin.token,
    method: "POST",
    body: { action: "deny", reason: "Synthetic denial for refund test" },
  });
  assert.equal(
    (await api("/api/wallet", { token: student.token })).wallet.coins,
    before,
  );
  await api("/api/admin/claims/" + result.claim.id, {
    token: admin.token,
    method: "POST",
    body: {
      action: "fulfill",
      reason: "Invalid transition",
      receipt: "receipt-123",
    },
    status: 409,
  });
});
test("J04 compensation cannot create negative balances", async () => {
  const result = await api("/api/admin/ledger", {
    token: admin.token,
    method: "POST",
    body: {
      user_id: other.user.id,
      xp: 0,
      coins: -999,
      origin: uid(),
      reason: "Invalid balance correction",
    },
    status: 409,
  });
  assert.equal(result.error.code, "NEGATIVE_BALANCE");
});
test("J05 fixed-price theme and celebration effects are bought, equipped and never over-spent", async () => {
  const account = await register("styler");
  await api("/api/admin/ledger", { token: admin.token, method: "POST", body: { user_id: account.user.id, xp: 0, coins: 40, origin: uid(), reason: "Integration fixture funding" } });
  const shop = await api("/api/shop", { token: account.token });
  const price = (id) => shop.items.find((item) => item.id === id);
  assert.deepEqual(["theme-sepia", "effect-confetti", "effect-sparkles"].map((id) => [price(id).kind, price(id).price, price(id).stock]),
    [["theme", 20, null], ["effect", 15, null], ["effect", 15, null]]);
  // The former "Moonlit" item (dark mode, which Settings gives free) is now the Cosmos theme.
  assert.deepEqual([price("theme-night").title, price("theme-night").value], ["Cosmos theme", "cosmos"]);
  assert.equal(shop.items.some((item) => item.kind === "theme" && item.value === "dark"), false);
  assert.equal((await api("/api/shop/effect-confetti/purchase", { token: account.token, method: "POST", body: {} })).wallet.coins, 25);
  await api("/api/inventory/effect-confetti/equip", { token: account.token, method: "POST", body: {} });
  assert.equal((await api("/api/shop/theme-sepia/purchase", { token: account.token, method: "POST", body: {} })).wallet.coins, 5);
  await api("/api/inventory/theme-sepia/equip", { token: account.token, method: "POST", body: {} });
  const denied = await api("/api/shop/effect-sparkles/purchase", { token: account.token, method: "POST", body: {}, status: 409 });
  assert.equal(denied.error.code, "INSUFFICIENT_FUNDS");
  const inventory = (await api("/api/shop", { token: account.token })).inventory;
  assert.deepEqual(inventory.filter((i) => i.equipped).map((i) => i.item_id).sort(), ["effect-confetti", "theme-sepia"]);
  const item = await api("/api/admin/catalog", { token: admin.token, method: "POST", body: { title: "Soft stars", kind: "effect", price: 12, stock: 5, adult_only: false, rules: "", rules_version: 1, sponsor: "", value: "sparkles", reason: "Synthetic effect catalog test" } });
  assert.equal(item.item.kind, "effect");
});
test("G01 invite secrecy, join, ownership deletion guard, member removal", async () => {
  const created = await api("/api/rooms", {
    token: student.token,
    method: "POST",
    body: { title: "Quiet engineering", topic_id: "calculus" },
  });
  room = created.room;
  assert.equal(room.code_hash, undefined);
  await api("/api/rooms/join", {
    token: other.token,
    method: "POST",
    body: { code: "guessed-code" },
    status: 404,
  });
  await api("/api/rooms/join", {
    token: other.token,
    method: "POST",
    body: { code: created.code },
  });
  await api("/api/me/delete", {
    token: student.token,
    method: "POST",
    body: { confirm: "DELETE" },
    status: 409,
  });
  await api("/api/rooms/" + room.id, {
    token: student.token,
    method: "PUT",
    body: { action: "remove", user_id: other.user.id },
  });
  await api("/api/rooms/" + room.id, { token: other.token, status: 404 });
});
test("G02 room discussion escapes later in UI; block, report, moderation", async () => {
  const msg = await api("/api/rooms/" + room.id + "/messages", {
    token: student.token,
    method: "POST",
    body: { body: "<img src=x onerror=alert(1)> test text" },
  });
  const report = await api("/api/reports", {
    token: student.token,
    method: "POST",
    body: {
      kind: "message",
      target_id: msg.message.id,
      reason: "Unsafe markup test",
    },
  });
  await api("/api/admin/reports/" + report.report.id, {
    token: admin.token,
    method: "POST",
    body: { action: "hide", reason: "Reviewed unsafe test markup" },
  });
  const state = await api("/api/rooms/" + room.id, { token: student.token });
  assert.equal(
    state.messages.some((m) => m.id === msg.message.id),
    false,
  );
});
test("H01 competition hidden rejects entry; opt-in matches same-band peers", async () => {
  await api("/api/duels/queue", {
    token: student.token,
    method: "POST",
    body: { topic_id: "algebra" },
    status: 403,
  });
  await preferences(student, true);
  await preferences(other, true);
  await api("/api/duels/queue", {
    token: student.token,
    method: "POST",
    body: { topic_id: "algebra" },
  });
  const match = await api("/api/duels/queue", {
    token: other.token,
    method: "POST",
    body: { topic_id: "algebra" },
  });
  assert.equal(match.duel.state, "active");
  assert.equal(match.questions[0].accepted, undefined);
  const duel = await api("/api/duels/" + match.duel.id, {
    token: student.token,
  });
  assert.equal(duel.questions[0].explanation, undefined);
  await api("/api/duels/" + match.duel.id + "/forfeit", {
    token: other.token,
    method: "POST",
    body: {},
  });
  const ended = await api("/api/duels/" + match.duel.id, {
    token: student.token,
  });
  assert.equal(ended.duel.state, "forfeit");
  assert.ok(ended.questions[0].accepted.length);
});
test("H02 global competition disable clears navigation flag and blocks API", async () => {
  await api("/api/admin/flags/competition", {
    token: admin.token,
    method: "PUT",
    body: { enabled: false, reason: "Global disable verification" },
  });
  const result = await api("/api/duels/current", {
    token: student.token,
    status: 403,
  });
  assert.equal(result.error.code, "FEATURE_DISABLED");
  await api("/api/admin/flags/competition", {
    token: admin.token,
    method: "PUT",
    body: { enabled: true, reason: "Restore after test" },
  });
});
test("K01 notification cap validates and competition hides challenge setting", async () => {
  await preferences(student, false);
  const result = await api("/api/notifications/settings", {
    token: student.token,
    method: "PUT",
    body: {
      reminders: true,
      streak: true,
      invitations: true,
      challenges: true,
      rewards: true,
      quiet_start: 22,
      quiet_end: 7,
      reminder_time: "18:00",
      daily_cap: 3,
    },
  });
  assert.equal(result.settings.challenges, 0);
  await api("/api/notifications/settings", {
    token: student.token,
    method: "PUT",
    body: { reminder_time: "18:00", daily_cap: 4 },
    status: 422,
  });
});
test("A04 export excludes secrets; deletion revokes every session", async () => {
  const exp = await api("/api/me/export", { token: other.token });
  assert.equal(exp.profile.password_hash, undefined);
  assert.equal(exp.profile.school_cipher, undefined);
  await api("/api/me/delete", {
    token: other.token,
    method: "POST",
    body: { confirm: "DELETE" },
  });
  await api("/api/me", { token: other.token, status: 401 });
});
test("L01 students cannot inspect audit, flags, reports or private notes through moderation", async () => {
  await api("/api/admin/content/decks/" + privateDeck.id, {
    token: minor.token,
    status: 403,
  });
  const state = await api("/api/admin", { token: admin.token });
  assert.ok(state.audit.length > 5);
  assert.equal(state.study_sessions, undefined);
  assert.equal(state.answers, undefined);
});
test("DUN01 run questions stay private; a correct answer credits once and victory is validated", async () => {
  const runner = await register("dungeon-runner");
  await preferences(runner, true);
  const run = await api("/api/dungeon/runs", {
    token: runner.token, method: "POST", body: { difficulty: "easy", companion: "moss" },
  });
  assert.ok(/^[A-Za-z0-9_-]{43}$/.test(run.ticket), "ticket format");
  assert.equal(run.question_count, 20);
  assert.equal(run.time_limit_seconds, 480);
  assert.equal(run.mistake_limit, 5);
  assert.equal(run.hint_cost, 2);
  assert.ok(["library", "mixed", "practice"].includes(run.source));
  const url = `/api/dungeon/runs/${run.run_id}`;
  const preflight = await fetch(app.url + url + "/answer", {
    method: "OPTIONS",
    headers: { Origin: app.url, "Access-Control-Request-Method": "POST", "Access-Control-Request-Headers": "X-Dungeon-Ticket, Content-Type" },
  });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get("access-control-allow-origin"), app.url);
  assert.ok(preflight.headers.get("access-control-allow-headers").toLowerCase().includes("x-dungeon-ticket"));
  const listing = await api(url + "/questions", { ticket: run.ticket });
  assert.equal(listing.questions.length, 20);
  assert.equal(new Set(listing.questions.map(q => q.index)).size, 20);
  for (const q of listing.questions) {
    assert.ok(q.options.length >= 2 && q.options.length <= 4);
    if (q.source === "practice") assert.equal(q.options.length, 4);
    assert.equal(q.correct_choice, undefined);
    assert.equal(q.explanation, undefined);
    assert.ok(["quiz", "flashcard", "practice"].includes(q.source));
  }
  const denied = await api(url + "/questions", { token: student.token, status: 404 });
  assert.equal(denied.error.code, "RUN_NOT_FOUND");
  const invalid = await api(url + "/answer", {
    ticket: "invalid", method: "POST", body: { index: 0, choice: 0 }, status: 401,
  });
  assert.equal(invalid.error.code, "TICKET_INVALID");
  const correctChoice = dungeonFixture(
    "SELECT correct_choice FROM dungeon_run_questions WHERE run_id=? AND idx=0", [run.run_id],
  )[0];
  await new Promise(resolve => setTimeout(resolve, 1600));
  const before = (await api("/api/wallet", { token: runner.token })).wallet.coins;
  const answer = await api(url + "/answer", {
    ticket: run.ticket, method: "POST", body: { index: 0, choice: correctChoice },
  });
  assert.equal(answer.correct, true);
  assert.ok(answer.correct_choice === correctChoice, "correct answer returned");
  assert.equal(answer.coins_awarded, 1);
  assert.equal(answer.flagged_fast, false);
  const repeat = await api(url + "/answer", {
    ticket: run.ticket, method: "POST", body: { index: 0, choice: correctChoice },
  });
  assert.ok(JSON.stringify(repeat) === JSON.stringify(answer), "answer replay is identical");
  const wallet = await api("/api/wallet", { token: runner.token });
  assert.equal(wallet.wallet.coins, before + 1);
  assert.equal(wallet.ledger.filter(entry => entry.reason === "dungeon_answer").length, 1);
  const finish = await api(url + "/finish", {
    ticket: run.ticket, method: "POST", body: { outcome: "victory" },
  });
  assert.notEqual(finish.outcome, "victory");
  assert.equal(finish.answered, 1);
  assert.equal(finish.correct_count, 1);
});
test("DUN02 fast answers earn no coins; hints charge once and reject an empty wallet", async () => {
  const runner = await register("dungeon-hints");
  const practiceOnly = await api("/api/dungeon/runs", {
    token: runner.token, method: "POST", body: { difficulty: "average", companion: "lumi" }, status: 403,
  });
  assert.equal(practiceOnly.error.code, "FEATURE_DISABLED");
  await preferences(runner, true);
  const run = await api("/api/dungeon/runs", {
    token: runner.token, method: "POST", body: { difficulty: "average", companion: "lumi" },
  });
  const url = `/api/dungeon/runs/${run.run_id}`;
  const listing = await api(url + "/questions", { ticket: run.ticket });
  // True/false questions keep two options, so hint on one with at least three choices.
  const hintIndex = listing.questions.find(q => q.options.length >= 3).index;
  const poor = await api(url + "/hint", {
    ticket: run.ticket, method: "POST", body: { index: hintIndex }, status: 409,
  });
  assert.equal(poor.error.code, "INSUFFICIENT_COINS");
  await api("/api/admin/ledger", {
    token: admin.token, method: "POST",
    body: { user_id: runner.user.id, xp: 0, coins: 10, origin: uid(), reason: "Synthetic hint test funding" },
  });
  const first = await api(url + "/hint", {
    ticket: run.ticket, method: "POST", body: { index: hintIndex },
  });
  assert.equal(first.coins_spent, run.hint_cost);
  assert.equal(first.wallet_balance, 10 - run.hint_cost);
  assert.equal(first.removed_choices.length, 2);
  assert.equal(new Set(first.removed_choices).size, 2);
  const repeat = await api(url + "/hint", {
    ticket: run.ticket, method: "POST", body: { index: hintIndex },
  });
  assert.ok(JSON.stringify(repeat) === JSON.stringify(first), "hint replay is identical");
  assert.equal((await api("/api/wallet", { token: runner.token })).wallet.coins, 10 - run.hint_cost);
  const choice = dungeonFixture(
    "SELECT correct_choice FROM dungeon_run_questions WHERE run_id=? AND idx=0", [run.run_id],
  )[0];
  await new Promise(resolve => setTimeout(resolve, 1100));
  dungeonFixture("UPDATE dungeon_run_questions SET served_at=? WHERE run_id=? AND idx=0", [Date.now() / 1000, run.run_id]);
  const answer = await api(url + "/answer", {
    ticket: run.ticket, method: "POST", body: { index: 0, choice },
  });
  assert.equal(answer.correct, true);
  assert.equal(answer.flagged_fast, true);
  assert.equal(answer.coins_awarded, 0);
});
test("DUN03 daily dungeon cap and ticket expiry are enforced", async () => {
  const runner = await register("dungeon-limits");
  await preferences(runner, true);
  const run = await api("/api/dungeon/runs", {
    token: runner.token, method: "POST", body: { difficulty: "hard", companion: "coral" },
  });
  assert.equal(run.question_count, 40);
  const url = `/api/dungeon/runs/${run.run_id}`;
  await api(url + "/questions", { ticket: run.ticket });
  dungeonFixture(
    "INSERT INTO ledger(id,user_id,xp,coins,origin,reason,created,actor_id) VALUES(?,?,0,100,?,'dungeon_answer',?,NULL)",
    [uid(), runner.user.id, "dungeon_answer:fixture:" + uid(), Date.now() / 1000],
  );
  const choice = dungeonFixture(
    "SELECT correct_choice FROM dungeon_run_questions WHERE run_id=? AND idx=0", [run.run_id],
  )[0];
  await new Promise(resolve => setTimeout(resolve, 1600));
  const answer = await api(url + "/answer", {
    ticket: run.ticket, method: "POST", body: { index: 0, choice },
  });
  assert.equal(answer.correct, true);
  assert.equal(answer.cap_reached, true);
  assert.equal(answer.coins_awarded, 0);
  dungeonFixture("UPDATE dungeon_runs SET ticket_expires=? WHERE id=?", [Date.now() / 1000 - 1, run.run_id]);
  const expired = await api(url + "/answer", {
    ticket: run.ticket, method: "POST", body: { index: 1, choice: 0 }, status: 401,
  });
  assert.equal(expired.error.code, "TICKET_INVALID");
});

test("DUN04 a complete correct run can finish in victory", async () => {
  const runner = await register("dungeon-victory");
  await preferences(runner, true);
  const run = await api("/api/dungeon/runs", {
    token: runner.token, method: "POST", body: { difficulty: "easy", companion: "moss" },
  });
  const url = `/api/dungeon/runs/${run.run_id}`;
  dungeonFixture(
    "UPDATE dungeon_run_questions SET answered_at=?,choice=correct_choice,correct=1 WHERE run_id=?",
    [Date.now() / 1000, run.run_id],
  );
  const finish = await api(url + "/finish", {
    ticket: run.ticket, method: "POST", body: { outcome: "victory" },
  });
  assert.equal(finish.outcome, "victory");
  assert.equal(finish.answered, 20);
  assert.equal(finish.correct_count, 20);
});

test("DUN05 a run with a few wrong answers can still win, and timeout is recorded", async () => {
  const runner = await register("dungeon-imperfect");
  await preferences(runner, true);
  const run = await api("/api/dungeon/runs", {
    token: runner.token, method: "POST", body: { difficulty: "easy", companion: "sky" },
  });
  const url = `/api/dungeon/runs/${run.run_id}`;
  // Questions are single-attempt: 17 correct and 3 wrong (under the easy limit of 5) still resolve all 20.
  dungeonFixture(
    "UPDATE dungeon_run_questions SET answered_at=?,choice=correct_choice,correct=(CASE WHEN idx < 3 THEN 0 ELSE 1 END) WHERE run_id=?",
    [Date.now() / 1000, run.run_id],
  );
  dungeonFixture("UPDATE dungeon_runs SET mistakes_used=3 WHERE id=?", [run.run_id]);
  const finish = await api(url + "/finish", {
    ticket: run.ticket, method: "POST", body: { outcome: "victory" },
  });
  assert.equal(finish.outcome, "victory");
  assert.equal(finish.correct_count, 17);
  const second = await api("/api/dungeon/runs", {
    token: runner.token, method: "POST", body: { difficulty: "easy", companion: "sky" },
  });
  const timeout = await api(`/api/dungeon/runs/${second.run_id}/finish`, {
    ticket: second.ticket, method: "POST", body: { outcome: "timeout" },
  });
  assert.equal(timeout.outcome, "timeout");
});

test("DUN06 a student's own flashcards become 4-choice dungeon questions without leaking answers", async () => {
  const runner = await register("dungeon-cards");
  await preferences(runner, true);
  const cards = ["mitochondrion", "ribosome", "nucleus", "vacuole", "chloroplast"].map((back, i) => ({
    front: `Synthetic organelle card ${i}`, back,
  }));
  await api("/api/decks", { token: runner.token, method: "POST", body: { title: "Synthetic cell deck", topic_id: "algebra", cards } });
  const run = await api("/api/dungeon/runs", { token: runner.token, method: "POST", body: { difficulty: "easy", companion: "mint" } });
  const listing = await api(`/api/dungeon/runs/${run.run_id}/questions`, { ticket: run.ticket });
  const fromCards = listing.questions.filter(q => q.source === "flashcard");
  assert.equal(fromCards.length, 5);
  for (const q of fromCards) {
    assert.equal(q.options.length, 4);
    assert.equal(new Set(q.options).size, 4);
    assert.equal(q.correct_choice, undefined);
  }
  const outsider = await register("dungeon-cards-outsider");
  await preferences(outsider, true);
  const other = await api("/api/dungeon/runs", { token: outsider.token, method: "POST", body: { difficulty: "easy", companion: "mint" } });
  const otherListing = await api(`/api/dungeon/runs/${other.run_id}/questions`, { ticket: other.ticket });
  assert.equal(otherListing.questions.filter(q => q.prompt.startsWith("Synthetic organelle card")).length, 0);
});
