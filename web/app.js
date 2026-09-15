import { Vault, uuid, digest } from "./vault.js";
import { previewCSV } from "./import.js";
import { Client, ApiError } from "./api.js";
import { reminders, pushRegistration } from "./native.js";
import {
  STUDIO_KINDS,
  artifactFile,
  artifactPreview,
  bytesLabel,
} from "./studio.js";

const $ = (s) => document.querySelector(s),
  h = (value) =>
    String(value ?? "").replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
const icons = {
  home: "M3 10 12 3l9 7v11h-6v-7H9v7H3Z",
  focus: "M12 8v5l3 2 M9 2h6 M12 5a8 8 0 1 0 0 16 8 8 0 0 0 0-16",
  library: "M4 3h6v18H4z M14 3h6v18h-6z M4 7h6 M14 7h6",
  studio: "M12 3v4 M12 17v4 M3 12h4 M17 12h4 M5.6 5.6l2.8 2.8 M15.6 15.6l2.8 2.8 M18.4 5.6l-2.8 2.8 M8.4 15.6l-2.8 2.8 M12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7",
  dungeon: "M4 21V8l3-3 3 3 2-5 2 5 3-3 3 3v13 M8 21v-6h8v6 M4 11h16",
  progress: "M4 20V4 M4 20h17 M8 16v-5 M13 16V7 M18 16V3",
  shop: "M3 7h18l-2 14H5Z M8 7V5a4 4 0 0 1 8 0v2",
  rooms:
    "M8 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8 M2 21v-3a6 6 0 0 1 12 0v3 M17 5a4 4 0 0 1 0 8 M18 16a5 5 0 0 1 4 5",
  settings: "M4 7h16 M4 17h16 M8 4v6 M16 14v6",
  duel: "m4 3 17 17 M20 3 3 20 M3 15l6 6 M15 3l6 6",
  admin: "M12 2 3 6v6q0 7 9 10 9-3 9-10V6Z M8 12l3 3 5-6",
};
const icon = (name) =>
  `<svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="${icons[name] || icons.library}"/></svg>`;
let vault = null,
  client = new Client(),
  user = null,
  route = "home",
  params = {},
  config = { flags: [] },
  topics = [],
  health = {},
  cleanup = () => {},
  handlers = {},
  formHandlers = {},
  counter = 0,
  generation = 0,
  reactionTimer = null,
  companionPositionTimer = null,
  companionPlayIndex = 0;
const flag = (name) =>
  config.flags?.find((f) => f.name === name)?.enabled === 1;
const button = (label, fn, cls = "", disabled = false) => {
  const id = `b${++counter}`;
  handlers[id] = fn;
  return `<button type="button" data-action="${id}" class="${cls}" ${disabled ? "disabled" : ""}>${label}</button>`;
};
const form = (id, html, fn) => {
  formHandlers[id] = fn;
  return `<form data-form="${id}">${html}</form>`;
};
const field = (label, name, value = "", type = "text", extra = "") =>
  `<div class="field"><label for="f-${h(name)}">${h(label)}</label><input id="f-${h(name)}" name="${h(name)}" type="${type}" value="${h(value)}" ${extra}></div>`;
const area = (label, name, value = "", extra = "") =>
  `<div class="field"><label for="f-${h(name)}">${h(label)}</label><textarea id="f-${h(name)}" name="${h(name)}" ${extra}>${h(value)}</textarea></div>`;
const select = (label, name, options, value = "") =>
  `<div class="field"><label for="f-${h(name)}">${h(label)}</label><select id="f-${h(name)}" name="${h(name)}">${options.map((o) => `<option value="${h(o.value ?? o.id)}" ${String(o.value ?? o.id) === String(value) ? "selected" : ""}>${h(o.label ?? o.title)}</option>`).join("")}</select></div>`;
const check = (label, name, checked = false) =>
  `<label class="check"><input type="checkbox" name="${h(name)}" ${checked ? "checked" : ""}>${h(label)}</label>`;
const empty = (title, text) =>
  `<div class="empty"><h3>${h(title)}</h3><p>${h(text)}</p></div>`;
const date = (seconds) =>
  new Date(seconds * 1000).toLocaleString([], {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
const band = (n) =>
  ["Foundation", "Developing", "Proficient", "Advanced"][n || 0];
const title = (eyebrow, heading, sub, action = "") =>
  `<div class="page-title"><div><div class="eyebrow">${h(eyebrow)}</div><h1>${h(heading)}</h1><p>${h(sub)}</p></div>${action}</div>`;
const progressBar = (value, label) =>
  `<progress max="100" value="${Math.max(0, Math.min(100, value || 0))}" aria-label="${h(label)}">${Math.round(value || 0)}%</progress>`;
const companions = [
  { id: "moss", name: "Moss", color: "Olive", note: "A steady reader who makes quiet progress feel important.", voice: { wave: "Slow and steady—I’m right here with my book.", think: "Let’s pause, breathe, and remember one piece at a time.", celebrate: "A quiet little victory. Well done.", encourage: "No worry. Every reread grows a stronger memory.", focus: "Pages open, distractions down. Let’s settle in." }, motions: { idle: "breathe", wave: "walk", think: "nod", celebrate: "hop", encourage: "nod", focus: "breathe" }, play: [["walk", "A short walk helps me think."], ["nod", "One small step still counts."], ["shake", "Shake off the distraction, gently."]] },
  { id: "lumi", name: "Lumi", color: "Golden", note: "A warm book buddy who celebrates patient learning.", voice: { wave: "Hi, study star! Shall we read together?", think: "We can give this question a warm, careful look.", celebrate: "Lovely work! I knew that answer was glowing in you.", encourage: "That answer needs another look, and that is completely okay.", focus: "I’ll keep the study light warm while you focus." }, motions: { idle: "sway", wave: "sway", think: "wiggle", celebrate: "twirl", encourage: "sway", focus: "breathe" }, play: [["sway", "A tiny sway and we’re ready!"], ["twirl", "A golden twirl just for you."], ["wiggle", "Book-buddy wiggle!"]] },
  { id: "coral", name: "Coral", color: "Coral", note: "A flashcard fox who cheers brave answers.", voice: { wave: "Hey! Flashcards ready—let’s zoom!", think: "Fox focus! Check every clue before we pounce.", celebrate: "YES! Quick paws, sharp mind!", encourage: "Missed it? No problem—we chase the next clue!", focus: "Sprint into focus, then keep a steady pace!" }, motions: { idle: "ready", wave: "run", think: "wiggle", celebrate: "hop", encourage: "shake", focus: "run" }, play: [["run", "Zoom! Catch me if you can!"], ["wiggle", "My tail does this when ideas are close!"], ["hop", "Flashcard victory hop!"]] },
  { id: "sky", name: "Sky", color: "Blue", note: "A curious owl who loves pencils and good questions.", voice: { wave: "Observation: you look ready to learn.", think: "Let’s inspect the question from another angle.", celebrate: "Excellent reasoning! That conclusion checks out.", encourage: "Useful result: we found what needs more evidence.", focus: "Pencil ready. Eyes on the important details." }, motions: { idle: "hover", wave: "flap", think: "nod", celebrate: "flap", encourage: "sway", focus: "hover" }, play: [["flap", "Wing stretch! My pencil is ready."], ["hover", "A higher view can reveal the answer."], ["nod", "Hypothesis accepted—for now!"]] },
  { id: "plum", name: "Plum", color: "Purple", note: "A thoughtful reader who reminds you to review gently.", voice: { wave: "Hmm, hello. I saved a quiet reading spot for you.", think: "Let’s think slowly; the details usually whisper.", celebrate: "Oh! We found it. That feels wonderfully neat.", encourage: "Interesting miss. Let’s mark it and return wiser.", focus: "Quiet paws, clear page, calm mind." }, motions: { idle: "wiggle", wave: "wiggle", think: "nod", celebrate: "twirl", encourage: "sway", focus: "breathe" }, play: [["wiggle", "My ears wiggle when a thought is forming."], ["nod", "Hmm... yes, that makes sense."], ["twirl", "A very dignified little spin."]] },
  { id: "sunny", name: "Sunny", color: "Orange", note: "An energetic study pal who turns effort into joy.", voice: { wave: "Woo-hoo! You’re here—let’s make learning lively!", think: "Brain power charging... almost there!", celebrate: "BOOM! Bright answer, big cheer!", encourage: "Shake it out! A new try is already a win!", focus: "Energy in, distractions out—go, go, focus!" }, motions: { idle: "bounce", wave: "hop", think: "shake", celebrate: "spin", encourage: "wiggle", focus: "bounce" }, play: [["hop", "Boing! That woke up my brain!"], ["spin", "Sunshine spin incoming!"], ["shake", "Shake, shake—ready again!"]] },
  { id: "mint", name: "Mint", color: "Mint", note: "A calm notebook keeper for focused study moments.", voice: { wave: "Oh, hi. We can start whenever you feel ready.", think: "No rush... let’s write down what we know first.", celebrate: "You did it. I’m quietly very happy for you.", encourage: "It’s okay. We can try again with smaller steps.", focus: "Soft breath, open notebook, one calm task." }, motions: { idle: "breathe", wave: "sway", think: "shake", celebrate: "hop", encourage: "breathe", focus: "breathe" }, play: [["sway", "I’m just finding a comfortable study spot."], ["shake", "A tiny nervous shake... and I’m okay."], ["breathe", "In, out, and back to the page."]] },
  { id: "nova", name: "Nova", color: "Navy and gold", note: "A starry guide who makes every new idea feel magical.", voice: { wave: "A new study constellation awaits us.", think: "Follow the clues; every idea leaves a little starlight.", celebrate: "Brilliant! That answer lit up the whole sky.", encourage: "Even wandering stars find their way. Try the next path.", focus: "Let the noise fade. Keep only this one bright thought." }, motions: { idle: "float", wave: "float", think: "hover", celebrate: "twirl", encourage: "sway", focus: "float" }, play: [["float", "Gravity is optional during study magic."], ["twirl", "A constellation twirl!"], ["hover", "I’m following a trail of starlight."]] },
  { id: "ember", name: "Ember", color: "Flame orange", note: "A brave dragon scholar who turns hard questions into sparks.", voice: { wave: "Tiny flame, giant study quest!", think: "Let me warm up this clue.", celebrate: "Blazing answer! You did it!", encourage: "Even dragon fire needs a second spark.", focus: "Flame steady. Eyes forward." }, motions: { idle: "breathe", wave: "flap", think: "sway", celebrate: "hop", encourage: "nod", focus: "breathe" }, play: [["flap", "Wing warm-up!"], ["hop", "A fiery victory hop!"], ["wiggle", "My tail flame found an idea!"]] },
  { id: "bubbles", name: "Bubbles", color: "Aqua and pink", note: "A curious axolotl scientist who tests every idea with joy.", voice: { wave: "Hello! Ready for a tiny experiment?", think: "Observe, compare, then answer.", celebrate: "Experiment successful!", encourage: "That result teaches us what to test next.", focus: "Lab quiet. Curiosity on." }, motions: { idle: "sway", wave: "wiggle", think: "nod", celebrate: "hop", encourage: "sway", focus: "breathe" }, play: [["wiggle", "Gill wiggle! Science is happening."], ["hop", "A bubbly breakthrough!"], ["sway", "Let’s mix one more idea."]] },
  { id: "byte", name: "Byte", color: "Teal and navy", note: "A friendly robot programmer who debugs one step at a time.", voice: { wave: "Study system online!", think: "Scanning the clues...", celebrate: "Correct output confirmed!", encourage: "No failure—just useful debug data.", focus: "Focus mode activated." }, motions: { idle: "hover", wave: "nod", think: "shake", celebrate: "twirl", encourage: "nod", focus: "hover" }, play: [["nod", "Diagnostics look good!"], ["twirl", "Upgrade complete!"], ["shake", "Recalibrating my answer sensor."]] },
  { id: "clover", name: "Clover", color: "Leaf green", note: "A rabbit botanist who helps patient learning take root.", voice: { wave: "A fresh idea just sprouted!", think: "Let’s follow this clue like a growing vine.", celebrate: "Wonderful—your answer bloomed!", encourage: "Roots grow quietly. Try once more.", focus: "One seed, one page, one task." }, motions: { idle: "sway", wave: "hop", think: "wiggle", celebrate: "hop", encourage: "nod", focus: "breathe" }, play: [["hop", "Botany bunny bounce!"], ["wiggle", "My ears heard a new idea."], ["sway", "Growing knowledge takes time."]] },
  { id: "mochi", name: "Mochi", color: "Cream and red", note: "A gentle bear reader who makes every page feel cozy.", voice: { wave: "I saved you a cozy reading place.", think: "Let’s read that part one more time.", celebrate: "That answer deserves a warm bear hug!", encourage: "We can turn the page and try again.", focus: "Scarf snug. Book open." }, motions: { idle: "breathe", wave: "sway", think: "nod", celebrate: "hop", encourage: "sway", focus: "breathe" }, play: [["sway", "Cozy study sway."], ["hop", "A soft little celebration!"], ["nod", "This chapter makes sense."]] },
  { id: "comet", name: "Comet", color: "Silver blue", note: "A fox astronaut who explores questions like distant worlds.", voice: { wave: "Navigator ready. Where shall we explore?", think: "Plotting a path through the evidence.", celebrate: "Perfect landing! Correct answer!", encourage: "Course adjusted. Next attempt ahead.", focus: "One bright mission. Zero distractions." }, motions: { idle: "float", wave: "hover", think: "nod", celebrate: "twirl", encourage: "sway", focus: "float" }, play: [["float", "Low-gravity study mode!"], ["twirl", "Orbital celebration!"], ["hover", "Scanning the next constellation."]] },
  { id: "pebble", name: "Pebble", color: "Stone and amber", note: "A little golem historian who remembers lessons carved by time.", voice: { wave: "Greetings. I brought an old story.", think: "The answer may be hidden in what came before.", celebrate: "A fine answer—worthy of the archive!", encourage: "Stone becomes smooth through many tries.", focus: "Steady as stone. Read carefully." }, motions: { idle: "breathe", wave: "nod", think: "sway", celebrate: "shake", encourage: "nod", focus: "breathe" }, play: [["shake", "Ancient-rune rumble!"], ["nod", "History agrees."], ["sway", "Even stones enjoy a story."]] },
  { id: "melody", name: "Melody", color: "Rose and violet", note: "A songbird musician who finds the rhythm inside every lesson.", voice: { wave: "Hello! Let’s find today’s study rhythm.", think: "Listen—the clues have a pattern.", celebrate: "Perfect note, perfect answer!", encourage: "A missed note helps the next one sound better.", focus: "Quiet beat, steady page." }, motions: { idle: "sway", wave: "flap", think: "nod", celebrate: "twirl", encourage: "sway", focus: "breathe" }, play: [["flap", "Conductor wings ready!"], ["twirl", "Celebration chorus!"], ["sway", "Study to the rhythm."]] },
  { id: "taro", name: "Taro", color: "Purple and brass", note: "A raccoon inventor who builds clever answers from small clues.", voice: { wave: "I brought tools—and three new ideas!", think: "Let’s take this question apart carefully.", celebrate: "It works! Brilliant construction!", encourage: "Prototype one taught us plenty. Rebuild!", focus: "Goggles down. Tinkering quietly." }, motions: { idle: "wiggle", wave: "nod", think: "shake", celebrate: "hop", encourage: "nod", focus: "breathe" }, play: [["wiggle", "My inventor tail is calibrating."], ["hop", "Contraption success!"], ["shake", "One tiny adjustment..."]] },
  { id: "sol", name: "Sol", color: "Sun gold", note: "A kind lion leader who helps every learner feel courageous.", voice: { wave: "You’re here! Let’s lead today with courage.", think: "A good leader listens to every clue.", celebrate: "Radiant work! Be proud of that answer.", encourage: "Courage means trying the next step.", focus: "Stand tall. Choose one clear goal." }, motions: { idle: "breathe", wave: "sway", think: "nod", celebrate: "hop", encourage: "nod", focus: "breathe" }, play: [["sway", "Leader’s welcome wave!"], ["hop", "Sun-bright celebration!"], ["nod", "You’ve got this."]] },
];
const companionById = (id) =>
  companions.find((companion) => companion.id === id) || companions[0];
function companionState() {
  const fallback = { selected: "moss", unlocked: ["moss"], friendship: {}, motion: "full", reactions: "balanced", cosmetic: "none", bonusAnimation: "none" };
  if (!vault) return fallback;
  const state = (vault.data.companions ||= fallback);
  state.unlocked = [...new Set((state.unlocked || ["moss"]).filter((id) => companions.some((c) => c.id === id)))];
  if (!state.unlocked.includes("moss")) state.unlocked.unshift("moss");
  if (!state.unlocked.includes(state.selected)) state.selected = "moss";
  state.friendship ||= {};
  state.motion ||= "full";
  state.reactions ||= "balanced";
  state.cosmetic ||= "none";
  state.bonusAnimation ||= "none";
  return state;
}
function companionFriendship(points = 1) {
  if (!vault || !user) return;
  const state = companionState(), id = state.selected;
  state.friendship[id] = Math.min(9999, (state.friendship[id] || 0) + points);
  vault.save().catch(showError);
}
function companionLevel(id = companionState().selected) {
  const points = companionState().friendship[id] || 0;
  return { points, level: Math.min(20, Math.floor(points / 25) + 1), next: 25 - (points % 25) };
}
function companionSprite(companion, cls = "") {
  return `<img class="companion-sprite ${cls}" src="/assets/companions/${companion.id}.png" alt="" aria-hidden="true">`;
}
function companionReact(mood = "wave", message = "", movement = "") {
  const dock = $("#companion-dock"),
    bubble = $("#companion-bubble");
  if (!dock || !bubble) return;
  const companion = companionById(companionState().selected);
  if (companionState().reactions === "quiet" && !message && Math.random() < 0.6) return;
  bubble.textContent = message || companion.voice[mood] || companion.voice.wave;
  bubble.hidden = false;
  dock.dataset.mood = mood;
  dock.dataset.motion = companionState().motion === "off" ? "still" : movement || companion.motions[mood] || companion.motions.wave;
  dock.classList.remove("is-speaking");
  void dock.offsetWidth;
  dock.classList.add("is-speaking");
  clearTimeout(reactionTimer);
  reactionTimer = setTimeout(() => {
    bubble.hidden = true;
    dock.classList.remove("is-speaking");
    dock.dataset.mood = "idle";
    dock.dataset.motion = companionState().motion === "off" ? "still" : companion.motions.idle;
  }, 4200);
}
function companionInteract() {
  const companion = companionById(companionState().selected),
    [movement, message] = companion.play[companionPlayIndex++ % companion.play.length];
  companionReact("wave", message, movement);
}
function positionCompanion(dock, left, top) {
  const padding = 4,
    maxLeft = Math.max(padding, innerWidth - dock.offsetWidth - padding),
    maxTop = Math.max(padding, innerHeight - dock.offsetHeight - padding),
    x = Math.max(padding, Math.min(maxLeft, left)),
    y = Math.max(padding, Math.min(maxTop, top));
  dock.style.left = `${x}px`;
  dock.style.top = `${y}px`;
  dock.style.right = "auto";
  dock.style.bottom = "auto";
  dock.classList.toggle("bubble-right", x < 245);
  dock.classList.toggle("bubble-below", y < 125);
  return { x, y, maxLeft, maxTop, padding };
}
function rememberCompanionPosition(dock) {
  if (!vault) return;
  const rect = dock.getBoundingClientRect(),
    placed = positionCompanion(dock, rect.left, rect.top),
    width = Math.max(1, placed.maxLeft - placed.padding),
    height = Math.max(1, placed.maxTop - placed.padding);
  companionState().position = {
    x: (placed.x - placed.padding) / width,
    y: (placed.y - placed.padding) / height,
  };
  clearTimeout(companionPositionTimer);
  companionPositionTimer = setTimeout(() => vault?.save().catch(showError), 120);
}
function setupCompanionDrag() {
  const dock = $("#companion-dock"),
    handle = dock?.querySelector(".companion-button");
  if (!dock || !handle) return;
  const saved = companionState().position;
  if (saved && Number.isFinite(saved.x) && Number.isFinite(saved.y)) {
    const width = Math.max(1, innerWidth - dock.offsetWidth - 8),
      height = Math.max(1, innerHeight - dock.offsetHeight - 8);
    positionCompanion(dock, 4 + saved.x * width, 4 + saved.y * height);
  }
  let drag = null;
  handle.addEventListener("pointerdown", (event) => {
    if (event.button !== 0) return;
    const rect = dock.getBoundingClientRect();
    drag = { id: event.pointerId, startX: event.clientX, startY: event.clientY, left: rect.left, top: rect.top, moved: false };
    handle.setPointerCapture(event.pointerId);
    dock.classList.add("dragging");
  });
  handle.addEventListener("pointermove", (event) => {
    if (!drag || drag.id !== event.pointerId) return;
    const dx = event.clientX - drag.startX,
      dy = event.clientY - drag.startY;
    if (!drag.moved && Math.hypot(dx, dy) < 6) return;
    drag.moved = true;
    dock.dataset.dragged = "true";
    document.body.classList.add("companion-dragging");
    positionCompanion(dock, drag.left + dx, drag.top + dy);
    event.preventDefault();
  });
  const finishDrag = (event) => {
    if (!drag || drag.id !== event.pointerId) return;
    const moved = drag.moved;
    drag = null;
    dock.classList.remove("dragging");
    document.body.classList.remove("companion-dragging");
    if (moved) {
      rememberCompanionPosition(dock);
      const companion = companionById(companionState().selected);
      companionReact("wave", `${companion.name} likes this new study spot!`, companion.motions.wave);
    }
  };
  handle.addEventListener("pointerup", finishDrag);
  handle.addEventListener("pointercancel", finishDrag);
  handle.addEventListener("keydown", (event) => {
    const directions = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
    if (event.key === "Home") {
      event.preventDefault();
      delete companionState().position;
      dock.removeAttribute("style");
      dock.classList.remove("bubble-right", "bubble-below");
      vault?.save().catch(showError);
      companionReact("wave", "Back to my favorite corner!", "hop");
      return;
    }
    if (!directions[event.key]) return;
    event.preventDefault();
    const rect = dock.getBoundingClientRect(),
      step = event.shiftKey ? 40 : 14,
      [x, y] = directions[event.key];
    positionCompanion(dock, rect.left + x * step, rect.top + y * step);
    rememberCompanionPosition(dock);
  });
}
function companionDock() {
  const state = companionState(), companion = companionById(state.selected);
  return `<aside id="companion-dock" class="companion-dock companion-${companion.id} effect-${h(state.cosmetic)} animation-${h(state.bonusAnimation)}" data-mood="idle" data-motion="${state.motion === "off" ? "still" : companion.motions.idle}" aria-label="${h(companion.name)}, your movable study companion"><div id="companion-bubble" class="companion-bubble" role="status" aria-live="polite" hidden></div><span class="companion-cosmetic" aria-hidden="true">${state.cosmetic === "study-crown" ? "♛" : state.cosmetic === "sparkles" ? "✦" : ""}</span>${button(`${companionSprite(companion, "companion-dock-sprite")}<span class="sr-only">Talk to ${h(companion.name)}. Drag to move; arrow keys also move; Home resets position.</span>`, () => {
    const currentDock = $("#companion-dock");
    if (currentDock?.dataset.dragged === "true") {
      currentDock.dataset.dragged = "false";
      return;
    }
    companionInteract();
  }, "companion-button companion-drag-handle")}</aside>`;
}
function companionGallery() {
  const state = companionState();
  return `<section class="card companion-section"><div class="section-header"><div><div class="eyebrow">Hand-drawn study friends</div><h2>Choose your companion</h2><p>All eighteen characters are free. Unlock any friend you like—study coins are never required.</p></div><span class="pill">${state.unlocked.length} / ${companions.length} unlocked</span></div><div class="companion-grid">${companions.map((companion) => {
    const unlocked = state.unlocked.includes(companion.id),
      selected = state.selected === companion.id;
    return `<article class="companion-card ${selected ? "selected" : ""}">${companionSprite(companion, "companion-card-sprite")}<div><h3>${h(companion.name)}</h3><span class="companion-color">${h(companion.color)}</span><p>${h(companion.note)}</p></div>${selected ? '<span class="pill companion-status">With you</span>' : button(unlocked ? `Choose ${h(companion.name)}` : `Unlock ${h(companion.name)} free`, async () => {
      if (!unlocked) state.unlocked.push(companion.id);
      state.selected = companion.id;
      await vault.save();
      await go("shop");
      companionReact("celebrate", `${companion.name} joined your study team!`);
    }, selected ? "small" : "primary small")}</article>`;
  }).join("")}</div><div class="actions section">${button("Visit companion room", () => go("companions"), "primary")}</div></section>`;
}
const streakRewards = [
  { id: "sparkles", days: 3, title: "Study sparkles", kind: "cosmetic", mark: "✦" },
  { id: "star-trail", days: 7, title: "Star trail", kind: "cosmetic", mark: "⋆" },
  { id: "study-crown", days: 14, title: "Study crown", kind: "cosmetic", mark: "♛" },
  { id: "super-run", days: 30, title: "Super run", kind: "animation", mark: "➜" },
];
function streakRewardGallery() {
  const login = vault?.data.loginStreak || { current: 0, best: 0, unlocks: [] }, state = companionState();
  return `<section class="card streak-rewards"><div class="section-header"><div><div class="eyebrow">Login streak gifts</div><h2>${login.current || 0} days together</h2><p>Simply return on consecutive days. These companion extras are free and never require coins.</p></div><span class="pill">Best: ${login.best || login.current || 0}</span></div><div class="streak-track">${streakRewards.map((reward) => {
    const unlocked = (login.unlocks || []).includes(reward.id), equipped = reward.kind === "animation" ? state.bonusAnimation === reward.id : state.cosmetic === reward.id;
    return `<article class="streak-gift ${unlocked ? "unlocked" : "locked"}"><div>${reward.mark}</div><strong>${reward.days} days · ${h(reward.title)}</strong><small>${unlocked ? "Unlocked" : `${Math.max(0, reward.days - (login.best || 0))} days to go`}</small>${unlocked ? button(equipped ? "Equipped" : "Equip", async () => { if (reward.kind === "animation") state.bonusAnimation = reward.id; else state.cosmetic = reward.id; await vault.save(); await go("shop"); companionReact("celebrate", `${reward.title} equipped!`, reward.id === "super-run" ? "run" : "twirl"); }, "small", equipped) : ""}</article>`;
  }).join("")}</div></section>`;
}
async function companionsView() {
  if (!user) return empty("Sign in to meet your companions", "Your companion friendship is saved in your encrypted workspace.");
  const state = companionState(), companion = companionById(state.selected), bond = companionLevel(), motions = [...new Set(["walk", "run", "hop", "wiggle", "shake", "twirl", "hover", "sway"])];
  return `${title("Companion home", `${companion.name}’s study nook`, `Friendship level ${bond.level} · ${bond.points} points · ${bond.next} to the next level`)}<section class="card companion-room"><div class="room-scene"><div class="room-window">☼</div><div class="room-shelf">▤ ▤ ▤</div><div class="room-plant">♧</div>${companionSprite(companion, "room-companion")}<div class="room-rug"></div></div><div><h2>Spend a moment together</h2><p>${h(companion.note)} Friendship grows from honest reviews, quizzes, focus sessions and creating study tools.</p>${progressBar((bond.points % 25) * 4, "Companion friendship")}<div class="motion-pad">${motions.map((motion) => button(motion[0].toUpperCase() + motion.slice(1), () => companionReact("wave", `${companion.name} is practicing a ${motion}!`, motion), "small")).join("")}</div><div class="actions section">${button("Choose another friend", () => go("shop"))}${button("Study together", () => go("home"), "primary")}</div></div></section>${streakRewardGallery()}`;
}
function toast(message) {
  $("#toast").textContent = message;
  $("#toast").classList.add("show");
  setTimeout(() => $("#toast").classList.remove("show"), 5000);
}
function showError(error) {
  const box = $("#page-error") || $("#auth-error");
  if (box) {
    box.innerHTML = `<div class="error" role="alert">${h(error.message || error)}</div>`;
    box.scrollIntoView({ block: "nearest" });
  } else toast(error.message || String(error));
}
function table(rows, columns) {
  return `<div class="table-scroll"><table><thead><tr>${columns.map((c) => `<th scope="col">${h(c[0])}</th>`).join("")}</tr></thead><tbody>${rows.map((row) => `<tr>${columns.map((c) => `<td>${c[2] ? c[2](row) : h(row[c[1]])}</td>`).join("")}</tr>`).join("")}</tbody></table></div>`;
}
async function downloadJSON(name, data) {
  downloadBlob(
    name,
    new Blob([JSON.stringify(data, null, 2)], { type: "application/json" }),
  );
}
function downloadBlob(name, blob) {
  const url = URL.createObjectURL(blob),
    anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = name;
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
  setTimeout(() => URL.revokeObjectURL(url), 30000);
}
async function load(path, opts) {
  try {
    return await client.request(path, { ...(user ? {} : {timeout: 1000}), ...opts });
  } catch (error) {
    if (user) throw error;
    const seed = await fetch("/starter.json").then((r) => r.json());
    if (seed[path]) return { ...seed[path], offline: true };
    throw error;
  }
}
async function modal(heading, content) {
  const dialog = $("#dialog");
  dialog.innerHTML = `<h2>${h(heading)}</h2>${content}<div class="spaced">${button("Close", () => dialog.close(), "subtle")}</div>`;
  dialog.showModal();
}
function profileAvatar() {
  const equipped=vault?.data.equipped || {};
  const companion = companionById(companionState().selected);
  return `<div class="avatar ${equipped.border==="sage"?"border-sage":""}" aria-label="Profile avatar, ${h(companion.name)} study companion${equipped.skin?", "+h(equipped.skin):""}${equipped.hat?", leaf hat":""}">${companionSprite(companion, "companion-avatar-sprite")}${equipped.hat==="leaf"?'<span class="avatar-hat" aria-hidden="true">❧</span>':""}</div>`;
}
function shell(content) {
  const items = [
    ["home", "My space"],
    ["focus", "Focus time"],
    ["library", "Study library"],
    ...(user ? [["studio", "AI Study Studio"]] : []),
    ...(user ? [["dungeon", "3D Dungeon"]] : []),
    ["progress", "My progress"],
    ["shop", "Rewards"],
  ];
  if (flag("rooms") && user) items.push(["rooms", "Study rooms"]);
  if (flag("competition") && user?.competition)
    items.push(["duel", "Quiz duels"]);
  if (["teacher", "admin"].includes(user?.role))
    items.push(["admin", "School console"]);
  items.push(["settings", "Settings"]);
  const nav = items
    .map(([id, label]) =>
      button(
        `${icon(id)}<span>${h(label)}</span>`,
        () => go(id),
        route === id ? "active" : "",
      ),
    )
    .join("");
  const pending = vault?.data.pending.length || 0,
    current = new Date().toLocaleDateString([], {
      weekday: "long",
      month: "long",
      day: "numeric",
    });
  $("#app").innerHTML =
    `<div class="shell"><aside class="sidebar"><a class="brand" href="#home"><img src="/icon.svg" alt=""><span>study arena<small>Your own pace</small></span></a><nav class="nav" aria-label="Main">${nav}</nav><div class="side-bottom"><div class="user-chip">${profileAvatar()}<div><strong>${h(user?.display_name || "Guest explorer")}</strong><p>${user ? `${band(user.band)} · private skill band` : "A little curiosity goes a long way."}</p></div></div></div></aside><div class="content"><header class="topbar"><span class="today">${h(current)}</span><div class="actions"><span class="pill">${navigator.onLine ? "● Connected" : "○ Offline study"}${pending ? ` · ${pending} waiting to sync` : ""}</span>${health.demo ? '<span class="pill">Demo · synthetic data</span>' : ""}${!user ? button("Sign in", () => authPage(), "small") : button("Lock", lock, "small subtle")}</div></header><main id="main" tabindex="-1"><div id="page-error"></div>${content}</main></div><nav class="bottom-nav" aria-label="Mobile main">${[
      ["home", "Home"],
      ["focus", "Focus"],
      ["library", "Library"],
      ["progress", "Progress"],
      ["settings", "More"],
    ]
      .map(([id, label]) =>
        button(
          `${icon(id)}<span>${label}</span>`,
          () => go(id),
          route === id ? "active" : "",
        ),
      )
      .join("")}</nav>${companionDock()}</div>`;
  setupCompanionDrag();
  document.documentElement.dataset.companionMotion = companionState().motion;
}
async function go(next, data = {}) {
  cleanup();
  cleanup = () => {};
  route = next;
  params = data;
  const n = ++generation;
  handlers = {};
  formHandlers = {};
  shell(
    '<div class="loading" aria-busy="true">Opening your study space…</div>',
  );
  try {
    if (!topics.length) topics = (await load("/api/topics")).items;
    const view = await views[next](data);
    if (n !== generation) return;
    shell(view.html ?? view);
    view.after?.();
    $("#main")?.focus({ preventScroll: true });
  } catch (error) {
    if (n === generation) {
      shell(
        `${title("Your space", "Let’s try that again", "Your local study work remains saved.")}<div class="error" role="alert">${h(error.message)}</div><div class="spaced">${button("Try again", () => go(next, data), "primary")}</div>`,
      );
    }
  }
}
async function requireLogin() {
  if (!user) {
    await authPage();
    return false;
  }
  return true;
}
async function lock() {
  if (vault) await vault.save();
  user = null;
  vault = null;
  client = new Client();
  cleanup();
  cleanup = () => {};
  await authPage();
}
async function authPage(mode = "login") {
  // A pending page load must not replace the sign-in form after navigation.
  ++generation;
  cleanup();
  cleanup = () => {};
  handlers = {};
  formHandlers = {};
  const body =
    mode === "register"
      ? form(
          "register",
          `${field("Display name", "display_name", "", "text", 'required maxlength="40" minlength="2"')}${field("School email", "email", "", "email", 'required autocomplete="email"')}${field("School ID", "school_id", "", "text", 'required maxlength="40"')}${field("Password · at least 12 characters", "password", "", "password", 'required minlength="12" maxlength="128" autocomplete="new-password"')}${select(
            "Age group",
            "age_band",
            [
              { value: "adult", label: "18 or older" },
              { value: "minor", label: "16–17" },
            ],
          )}${field("Institution consent code · required for minors", "consent_ref")}${check("I have read the privacy notice and agree to supervised participation.", "assent")}<p class="caption">We collect your email, encrypted school ID, age group and study activity to provide your workspace. Logs are private. Prizes are optional. ${button("Read privacy notice", privacy, "small subtle")}</p><button class="primary" type="submit">Create my workspace</button>`,
          async (f) => {
            if (!f.has("assent"))
              throw new Error(
                "Please read the privacy notice and confirm participation.",
              );
            const data = await client.mutate(
              "/api/auth/register",
              Object.fromEntries(f),
            );
            toast(data.message);
            await authPage("login");
          },
        )
      : mode === "reset"
        ? form(
            "resetRequest",
            `${field("School email", "email", "", "email", "required")}<button class="primary" type="submit">Send recovery link</button><p class="caption spaced">If you cannot access this inbox, ask the school coordinator for institutional identity verification.</p>`,
            async (f) => {
              const result = await client.mutate(
                "/api/auth/reset-request",
                Object.fromEntries(f),
              );
              toast(result.message);
            },
          )
        : form(
            "login",
            `${field("Email", "email", localStorage.getItem("last-email") || "", "email", 'required autocomplete="username"')}${field("Password / local workspace password", "password", "", "password", 'required maxlength="128" autocomplete="current-password"')}<p class="caption">Your study cache is encrypted on this device. Use the same password to unlock it without internet.</p><button class="primary" type="submit">Enter my study space</button>`,
            async (f) => {
              const email = f.get("email").trim().toLowerCase(),
                password = f.get("password");
              let online;
              try {
                online = await new Client().mutate("/api/auth/login", {
                  email,
                  password,
                  device: navigator.userAgent.slice(0, 80),
                });
              } catch (error) {
                if (error instanceof ApiError) throw error;
              }
              const opened = await Vault.open(email, password);
              if (!online && !opened.data.user)
                throw new Error(
                  "Sign in online once to prepare this device for offline study.",
                );
              vault = opened;
              user = online?.user || vault.data.user;
              if (online) {
                vault.data.token = online.token;
                vault.data.user = user;
                vault.data.loginStreak = online.login_streak;
                if (online.login_streak?.new_milestones?.length)
                  toast(`Login streak reward unlocked: ${online.login_streak.new_milestones.join(", ")} days!`);
              }
              client = new Client(vault);
              localStorage.setItem("last-email", email);
              await vault.save();
              document.documentElement.dataset.theme =
                vault.data.theme || "light";
              if (
                localStorage.getItem("guest-result") &&
                !vault.data.guestMigrated
              ) {
                const guest = JSON.parse(localStorage.getItem("guest-result"));
                await client.mutate(
                  `/api/quizzes/${guest.quiz_id}/offline`,
                  guest.body,
                  { queue: true, key: guest.body.id },
                );
                vault.data.guestMigrated = true;
                await vault.save();
                localStorage.removeItem("guest-result");
              }
              companionState();
              await vault.save();
              if (!user.course) await go("onboarding");
              else await go("home");
              companionReact("wave", `Welcome back! ${companionById(companionState().selected).name} is ready to study.`);
            },
          );
  $("#app").innerHTML =
    `<div class="auth"><a class="brand" href="#home"><img src="/icon.svg" alt=""><span>study arena<small>Your own pace</small></span></a><div class="card"><div class="eyebrow">A calm place to grow</div><h1>${mode === "register" ? "Make room for learning." : mode === "reset" ? "Let’s get you back in." : "Welcome to your study space."}</h1><p>One topic, one small step, one good study day.</p><div id="auth-error"></div>${body}<div class="divider"></div><div class="actions">${button(mode === "register" ? "Already registered? Sign in" : "Create an account", () => authPage(mode === "register" ? "login" : "register"), "subtle small")}${button("Forgot password", () => authPage("reset"), "subtle small")}${button("Explore as a guest", () => go("home"), "subtle small")}</div>${health.demo ? `<div class="banner spaced">Synthetic demo accounts: student@study.test, teacher@study.test, admin@study.test. Password: StudyArena!2026. ${button("Open demo email inbox", demoMail, "small")}</div>` : ""}</div></div>`;
}
async function demoMail() {
  const email = prompt(
    "Synthetic email address to inspect:",
    "student@study.test",
  );
  if (!email) return;
  const result = await client.request(
    "/api/demo/mail?email=" + encodeURIComponent(email),
    { cache: false },
  );
  await modal(
    "Demo email inbox",
    result.items
      .map(
        (item) =>
          `<h3>${h(item.subject)}</h3><p class="material-text">${h(item.body)}</p>`,
      )
      .join("") ||
      empty(
        "No messages yet",
        "Register a synthetic account or request a reset.",
      ),
  );
}
async function privacy() {
  await modal(
    "Your study data stays yours",
    `<p>Study Arena stores your email, password hash, encrypted school ID, age group, chosen profile, study activity, shared content and reward records. Your own study logs and notes are private. Teachers see aggregate cohort totals only when at least five students are active.</p><p>Your device cache uses AES-GCM encryption unlocked by your password. The institution must approve its hosting region, privacy notice and data processing basis before a real pilot. Minors need the school’s approved consent process.</p><p>Deletion revokes access immediately, queues primary-data deletion after 30 days, and preserves minimized accounting/safety records under school policy. Export your records from Settings. Optional competition, prizes and notifications can remain off.</p><p>Contact your institution’s designated privacy officer to request access, correction, an objection or a complaint. This demo contains synthetic users and original example content.</p>`,
  );
}
const views = {};
views.companions = companionsView;
views.home = async () => {
  let progress = {
    wallet: { xp: 0, coins: 0 },
    today_minutes: 0,
    week_minutes: 0,
    streak: 0,
    topics: [],
  };
  if (user) progress = await load("/api/progress");
  const decks = (await load("/api/decks")).items.slice(0, 3),
    goal = user?.daily_goal || 25,
    loginStreak = vault?.data.loginStreak?.current || 0,
    weak = progress.topics?.[0],
    remaining = Math.max(5, Math.round(goal - progress.today_minutes));
  const heroArt = `<svg class="hero-art" viewBox="0 0 200 170" role="img" aria-label="A book beside a growing plant"><ellipse cx="98" cy="151" rx="81" ry="10" fill="#d8e3cc"/><path d="M20 85q33-14 69 7 35-21 72-7v63q-36-12-72 3-35-15-69-3Z" fill="#fffdf1" stroke="#658265" stroke-width="2"/><path d="M89 94v56M34 102l39 4M34 115l39 3M104 104l40-4M104 117l40-3" fill="none" stroke="#a0ad8d" stroke-width="3"/><path d="M146 70h31l-5 30h-22Z" fill="#cc9c74"/><path d="M161 71V29" stroke="#52774e" stroke-width="3"/><path d="M160 47q-26-1-24-22 21 1 24 22M162 57q24 0 24-23-24 0-24 23" fill="#769663"/><circle cx="35" cy="35" r="17" fill="#efddac"/></svg>`;
  return `${title("My study space", `A little progress, ${user ? user.display_name.split(" ")[0] : "every day"}.`, "There’s no race here. Just a little room to learn.")}<section class="hero"><div><div class="eyebrow">Your next quiet moment</div><h2>Settle in. Pick one thing.<br>Let the rest wait.</h2><p>A short focus session is a good place to start. Your pace is the right pace.</p>${button("Start a focus session  ↗", () => (user ? go("focus") : authPage()), "primary")}${user && Object.keys(vault.data.attempts).length ? button("Resume saved quiz", () => go("quiz", { id: Object.keys(vault.data.attempts)[0] }), "small subtle") : ""}</div>${heroArt}</section><div class="grid stats"><div class="card stat"><label>Today’s focus</label><strong>${Math.round(progress.today_minutes)} <span class="caption">/ ${goal} min</span></strong>${progressBar((progress.today_minutes / goal) * 100, "Daily study goal")}<small>Your goal, your choice</small></div><div class="card stat"><label>Login streak</label><strong>${loginStreak} <span class="caption">days</span></strong><small>Free companion rewards at 3, 7, 14 and 30</small></div><div class="card stat"><label>Study coins</label><strong>${progress.wallet.coins} <span class="caption">✦</span></strong><small>Earned one small step at a time</small></div></div>${user ? `<section class="card section daily-plan"><div class="section-header"><div><div class="eyebrow">Today’s gentle plan</div><h2>Three useful next steps</h2></div><span class="pill">About ${Math.min(45, remaining + 15)} min</span></div><div class="grid"><article><strong>1 · Review</strong><p>${h(weak?.title || "A due flashcard deck")}</p>${button("Open review", () => go("library"), "small")}</article><article><strong>2 · Make meaning</strong><p>Turn one source into a reviewer or quiz.</p>${button("Open AI Studio", () => go("studio"), "small")}</article><article><strong>3 · Focus</strong><p>${remaining} quiet minutes toward today’s goal.</p>${button("Start timer", () => go("focus"), "small primary")}</article></div></section>` : ""}<div class="split section"><section><div class="section-header"><h2>Something to get you started</h2>${button("Browse all ↗", () => go("library"), "subtle small")}</div><div class="stack">${decks.map((deck, i) => `<div class="card row"><div><div class="eyebrow">${h(topics.find((t) => t.id === deck.topic_id)?.subject)}</div><h3>${h(deck.title)}</h3><span class="muted caption">${deck.card_count} flashcards · a few good minutes</span></div>${button("Study →", () => go("deck", { id: deck.id }), "small")}</div>`).join("")}</div></section><section><div class="section-header"><h2>A little extra care</h2></div><div class="card">${
    progress.topics
      .filter((t) => t.mastery !== null)
      .slice(0, 3)
      .map(
        (t, i) =>
          `<div class="topic-row"><div class="row"><div><strong>${h(t.title)}</strong><small>${h(t.label)} · ${h(t.confidence)}</small></div><span class="list-number">${i + 1}</span></div>${progressBar(t.mastery, t.title + " mastery")}</div>`,
      )
      .join("") ||
    `<div class="icon-square">${icon("library")}</div><h3>Get to know your strengths.</h3><p>A short quiz helps you see what feels familiar and what could use another look.</p>`
  }<div class="spaced">${button("See my learning plan", () => (user ? go("progress") : authPage()), "small")}</div></div><p class="quiet-note spaced">◇ Your progress is private. Always your pace.</p></section></div>${user ? `<section class="dungeon-callout"><div><div class="eyebrow">Now open · 3D learning adventure</div><h2>Enter the Dungeon of Knowledge</h2><p>Explore a medieval maze with ${h(companionById(companionState().selected).name)}, face 100 animated encounters, dodge traps, and earn a coin for every correct answer.</p>${button("Enter the 3D Dungeon  →", () => go("dungeon"), "primary")}</div><div class="dungeon-gate" aria-hidden="true"><span>✦</span><i></i><b>100 ENCOUNTERS</b></div></section>` : ""}`;
};
views.onboarding = async () =>
  `${title("Make it yours", "What are you studying?", "Choose your course and study rhythm. You can change these anytime.")}<div class="card">${profileForm(true)}</div>`;
function profileForm(onboarding = false) {
  return form(
    "profile",
    `${field("Display name", "display_name", user.display_name, "text", 'required maxlength="40"')}${select(
      "Course",
      "course",
      [
        { value: "STEM", label: "Senior high · STEM" },
        { value: "Civil Engineering", label: "BS Civil Engineering" },
        { value: "Information Technology", label: "BS Information Technology" },
        { value: "Other", label: "Other course" },
      ],
      user.course,
    )}<div class="grid two">${field("Year level", "year", user.year, "number", 'min="1" max="6" required')}${field("Timezone", "timezone", user.timezone, "text", "required")}${field("Daily focus goal · minutes", "daily_goal", user.daily_goal, "number", 'min="5" max="180" required')}${field("Weekly focus goal · minutes", "weekly_goal", user.weekly_goal, "number", 'min="5" max="1260" required')}</div><h3>Subjects to keep nearby</h3>${topics.map((t) => check(t.subject, "subject:" + t.id, user.subjects?.includes(t.id))).join("")}<div class="divider"></div><h3>Would you like to see optional quiz duels?</h3><p>Solo study unlocks every level and study reward. Saying no changes none of that.</p>${check("Show optional competition · off by default", "competition", !!user.competition)}<button class="primary" type="submit">${onboarding ? "Save my preferences" : "Save changes"}</button>`,
    async (f) => {
      const body = {
        ...Object.fromEntries(f),
        version: user.version,
        competition: f.has("competition"),
        subjects: topics
          .filter((t) => f.has("subject:" + t.id))
          .map((t) => t.id),
      };
      const result = await client.mutate("/api/me", body, { method: "PUT" });
      user = result.user;
      vault.data.user = user;
      await vault.save();
      toast("Your preferences are saved.");
      if (onboarding)
        await modal(
          "A quick starting point?",
          `<p>You can try a three-question diagnostic now, or skip it. Your initial band is Foundation until there is enough evidence. No low score is assigned for skipping.</p>${button(
            "Try a short quiz",
            () => {
              $("#dialog").close();
              go("quiz", { id: "quiz-algebra", diagnostic: true });
            },
            "primary",
          )} ${button(
            "Skip for now",
            () => {
              $("#dialog").close();
              go("home");
            },
            "subtle",
          )}`,
        );
      else await go("settings");
    },
  );
}
views.focus = async () => {
  if (!user)
    return `${title("Focus time", "A space for one thing.", "Sign in once to save your sessions and use the timer offline.")} ${button("Sign in", () => authPage(), "primary")}`;
  let timer = vault.data.timer;
  if (!timer)
    return `${title("Solo study", "Make a little room to focus.", "Five minutes counts. Your session can be as calm as you need.")}<div class="split"><div class="card">${form(
      "startFocus",
      `${select("What will you study?", "topic_id", topics)}${select(
        "Session length",
        "minutes",
        [
          { value: 10, label: "10 minutes · a small start" },
          { value: 25, label: "25 minutes · settle in" },
          { value: 45, label: "45 minutes · go a little deeper" },
          { value: 60, label: "60 minutes · steady focus" },
        ],
        25,
      )}${area("A note for this session · optional", "notes", "", 'maxlength="10000"')}<button type="submit" class="primary full">Begin focus time</button>`,
      async (f) => {
        const now = Date.now() / 1000,
          id = uuid();
        vault.data.timer = {
          id,
          topic_id: f.get("topic_id"),
          minutes: +f.get("minutes"),
          notes: f.get("notes"),
          started: now,
          elapsed: 0,
          checkpoint: now,
          state: "running",
          timezone: user.timezone,
        };
        await vault.save();
        await go("focus");
        companionReact("focus");
      },
    )}</div><div class="card"><div class="eyebrow">Exactly what you earn</div><h2>A little effort adds up.</h2><p>1 XP per minute and 1 coin per 5 minutes, after a minimum of 5 minutes.</p><p>Credit is capped at 180 minutes per session. The timer stops at four hours. Offline time is self-reported and cannot prove prize eligibility.</p><p class="caption">Daily cap: 500 XP and 100 study coins. Overlapping sessions sync as personal logs, with only one receiving credit.</p></div></div>`;
  const wallNow = Date.now() / 1000,
    gap = wallNow - timer.checkpoint;
  if (timer.state === "running") {
    if (gap < 0 || gap > 14400) {
      timer.state = "paused";
      timer.clockWarning = true;
    } else timer.elapsed = Math.min(10800, timer.elapsed + gap);
  }
  timer.checkpoint = wallNow;
  await vault.save();
  let baseline = performance.now(),
    startElapsed = timer.elapsed;
  function elapsed() {
    return Math.min(
      10800,
      startElapsed +
        (timer.state === "running" ? (performance.now() - baseline) / 1000 : 0),
    );
  }
  async function checkpoint() {
    timer.elapsed = elapsed();
    timer.checkpoint = Date.now() / 1000;
    baseline = performance.now();
    startElapsed = timer.elapsed;
    if (timer.checkpoint - timer.started >= 14400) timer.state = "paused";
    await vault.save();
  }
  async function finish() {
    await checkpoint();
    const body = {
      id: timer.id,
      topic_id: timer.topic_id,
      started: timer.started,
      ended: Date.now() / 1000,
      elapsed: timer.elapsed,
      timezone: timer.timezone,
      notes: $("#focus-notes")?.value ?? timer.notes,
    };
    await client.mutate("/api/study/offline", body, {
      queue: true,
      key: timer.id,
    });
    vault.data.history.unshift(body);
    delete vault.data.timer;
    await vault.save();
    await go("focusSummary", { session: body });
    companionFriendship(Math.max(1, Math.floor(timer.elapsed / 300)));
    companionReact(timer.elapsed < 300 ? "encourage" : "celebrate");
  }
  const html = `${title("Focus time", topics.find((t) => t.id === timer.topic_id)?.title || "Your focus session", "A small commitment to yourself.")} ${timer.clockWarning ? '<div class="banner">Your device clock changed or the app was closed too long. The timer is paused for review.</div>' : ""}<div class="card timer"><span class="pill">${h(timer.state === "paused" ? "Paused · take your time" : "Focus in progress")}</span><div id="clock" class="clock" role="timer" aria-label="Focus time remaining">00:00</div><p id="timer-status">Your ${timer.minutes}-minute study moment</p><div class="actions">${button(
    timer.state === "paused" ? "Resume" : "Pause",
    async () => {
      await checkpoint();
      timer.state = timer.state === "paused" ? "running" : "paused";
      await vault.save();
      await go("focus");
    },
    "primary",
  )}${button("Finish session", finish)}${button(
    "Discard timer",
    async () => {
      if (!confirm("Discard this timer? No study credit will be requested."))
        return;
      delete vault.data.timer;
      await vault.save();
      await go("focus");
    },
    "subtle",
  )}</div><div class="field spaced"><label for="focus-notes">What did you cover?</label><textarea id="focus-notes" maxlength="10000">${h(timer.notes)}</textarea></div><p class="caption">Notes stay private. Save a checkpoint before switching devices.</p></div>`;
  return {
    html,
    after() {
      let saved = 0;
      const tick = () => {
        const seconds = Math.max(0, timer.minutes * 60 - elapsed());
        $("#clock").textContent =
          `${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(Math.floor(seconds % 60)).padStart(2, "0")}`;
        if (seconds === 0)
          $("#timer-status").textContent =
            "Your planned time is complete. Finish when you’re ready.";
        if (++saved % 5 === 0) checkpoint().catch(showError);
      };
      tick();
      const interval = setInterval(tick, 1000);
      $("#focus-notes").addEventListener("input", (event) => {
        timer.notes = event.target.value;
        checkpoint().catch(showError);
      });
      const hidden = () => checkpoint().catch(showError);
      document.addEventListener("visibilitychange", hidden);
      cleanup = () => {
        clearInterval(interval);
        document.removeEventListener("visibilitychange", hidden);
        checkpoint().catch(() => {});
      };
    },
  };
};
views.focusSummary = async ({ session }) =>
  `${title("A moment well spent", "You showed up. That matters.", "Here’s what you covered in your study session.")}<div class="card"><div class="eyebrow">${h(topics.find((t) => t.id === session.topic_id)?.title)}</div><h2>${Math.floor(session.elapsed / 60)} minutes of focus</h2><p class="material-text">${h(session.notes || "No session notes added.")}</p><p>${session.elapsed < 300 ? "Saved as a personal log. Sessions under five minutes do not earn rewards." : vault.data.pending.some((p) => p.id === session.id) ? "Saved on this device. Credit will be confirmed when sync completes." : "Saved and submitted for validated study credit."}</p><div class="actions">${button("Back to my space", () => go("home"), "primary")}${button("View my progress", () => go("progress"))}</div></div>`;
views.library = async ({ tab = "decks", query = "" }) => {
  const endpoint =
    tab === "materials"
      ? "/api/materials"
      : tab === "quizzes"
        ? "/api/quizzes"
        : "/api/decks";
  const response = await load(
    endpoint + (query ? "?q=" + encodeURIComponent(query) : ""),
  );
  let items = response.items;
  if (tab === "decks" && vault?.data.localDecks)
    items = [
      ...Object.values(vault.data.localDecks)
        .filter((d) => !items.some((i) => i.id === d.deck.id))
        .map((d) => ({ ...d.deck, card_count: d.cards.length, local: true })),
      ...items,
    ];
  return `${title("Study library", "Find your next small step.", "Flashcards, explained quizzes and reference notes. Content comes first.", user ? button("Create a deck", () => go("deckEditor"), "primary small") : "")}<div class="tabs">${[
    ["decks", "Flashcards"],
    ["quizzes", "Quizzes"],
    ["materials", "Reference materials"],
  ]
    .map(([id, label]) =>
      button(
        label,
        () => go("library", { tab: id }),
        tab === id ? "active" : "",
      ),
    )
    .join("")}</div><div class="card">${form(
    "search",
    `<div class="row">${field("Search " + tab, "q", query, "search")}<button type="submit">Search</button></div>${
      tab === "materials"
        ? `<div class="grid two">${select("Course", "course", [{ value: "", label: "All courses" }, ...Array.from(new Set(topics.map((t) => t.course))).map((v) => ({ value: v, label: v }))])}${select(
            "File type",
            "file_type",
            [
              { value: "", label: "All formats" },
              { value: "text", label: "Study notes" },
              { value: "pdf", label: "PDF" },
              { value: "png", label: "PNG image" },
              { value: "jpeg", label: "JPEG image" },
            ],
          )}${field("Year level · optional", "year", "", "number", 'min="1" max="6"')}${select("Subject", "subject", [{ value: "", label: "All subjects" }, ...topics.map((t) => ({ value: t.subject, label: t.subject }))])}</div>`
        : ""
    }`,
    async (f) => {
      if (tab !== "materials") {
        await go("library", { tab, query: f.get("q") });
        return;
      }
      const qs = new URLSearchParams(Object.fromEntries(f)),
        result = await load("/api/materials?" + qs);
      await go("materialResults", { items: result.items });
    },
  )}</div>${response.offline ? '<p class="banner spaced">Offline results · previously saved content only.</p>' : ""}<div class="grid section">${items.map((item) => `<article class="card"><div class="icon-square">${tab === "decks" ? "▤" : tab === "quizzes" ? "✎" : "▧"}</div><div class="eyebrow">${h(topics.find((t) => t.id === item.topic_id)?.subject || "Study content")}</div><h2>${h(item.title)}</h2><p class="caption">${tab === "decks" ? `${item.card_count} cards` : tab === "quizzes" ? "Answers and explanations included" : `${h(item.file_type.toUpperCase())} · Year ${item.year}`} ${item.verified_by ? "· Source checked" : ""}${item.local ? " · Saved locally" : ""}</p>${button("Open →", () => go(tab === "decks" ? "deck" : tab === "quizzes" ? "quiz" : "material", { id: item.id }), "small")}</article>`).join("") || empty("A little quiet here", "Try another search or clear your filters.")}</div><div class="actions section">${user ? button("Contribute study notes", () => go("materialEditor")) : ""}${["teacher", "admin"].includes(user?.role) ? button("Create a quiz", () => go("quizEditor")) : ""}</div>`;
};
views.materialResults = async ({ items }) =>
  `${title("Reference materials", "Your search results", "Open a resource to read or download it.")}<div class="stack">${items.map((m) => `<div class="card row"><div><h2>${h(m.title)}</h2><p>${h(m.source)}</p></div>${button("Open", () => go("material", { id: m.id }))}</div>`).join("") || empty("No matching resources", "Try fewer filters.")}</div>${button("Change filters", () => go("library", { tab: "materials" }), "spaced")}`;
async function entireDeck(id) {
  if (vault?.data.localDecks?.[id]) return vault.data.localDecks[id];
  let result = await load(`/api/decks/${id}?limit=100`),
    cards = [...result.cards];
  while (cards.length < result.total) {
    const next = await load(
      `/api/decks/${id}?limit=100&offset=${cards.length}`,
    );
    cards.push(...next.cards);
  }
  return { ...result, cards };
}
views.deck = async ({ id }) => {
  const data = await entireDeck(id),
    deck = data.deck;
  return `${title("Flashcards", deck.title, `${data.cards.length} cards · ${h(topics.find((t) => t.id === deck.topic_id)?.title)}`)}<div class="card"><p>Turn a card over, then honestly choose “Known” or “Needs review.” Due cards earn rewards once per 24 hours.</p><div class="actions">${button("Review due cards", () => go("review", { data }), "primary", !data.cards.length)}${button("Shuffle & practice", () => go("review", { data, practice: true }), "", !data.cards.length)}${
    user
      ? button("Save for offline", async () => {
          vault.data.localDecks ??= {};
          vault.data.localDecks[id] = data;
          await vault.save();
          toast("All cards are saved for offline review.");
        })
      : ""
  }${
    user && deck.owner_id === user.id
      ? button("Edit deck", () => go("deckEditor", { data }))
      : user
        ? button("Clone to my decks", async () => {
            const result = await client.mutate(`/api/decks/${id}/clone`);
            toast("Your private copy is ready.");
            await go("deck", { id: result.deck.id });
          })
        : ""
  }</div>${!data.cards.length ? empty("Your deck is waiting for its first card", "Add a card or import a CSV file.") : ""}<div class="divider"></div><p class="caption">Source: ${h(deck.source || "Your original notes")}<br>License: ${h(deck.license || "Private study content")}</p>${user && deck.owner_id === user.id ? button("Share deck", () => shareDeck(deck), "small") : user ? button("Report content", () => report("deck", id), "small subtle") : ""}</div>`;
};
async function shareDeck(deck) {
  await modal(
    "Share this deck",
    form(
      "shareDeck",
      `${select(
        "Visibility",
        "visibility",
        [
          { value: "private", label: "Private · only me" },
          { value: "public", label: "Public · after moderation" },
          { value: "room", label: "A study room" },
        ],
        deck.visibility,
      )}${field("Room ID · for room sharing", "room_id", deck.room_id || "")}${field("Source / attribution", "source", deck.source || "Original notes by " + user.display_name, "text", "required")}${field("License / permission", "license", deck.license || "Original work · shared with permission", "text", "required")}<button type="submit" class="primary">Save sharing settings</button>`,
      async (f) => {
        await client.mutate(
          `/api/decks/${deck.id}/share`,
          Object.fromEntries(f),
        );
        $("#dialog").close();
        toast("Sharing preference saved. Public content awaits moderation.");
        await go("deck", { id: deck.id });
      },
    ),
  );
}
views.deckEditor = async ({ data } = {}) => {
  if (!user)
    return empty(
      "Sign in to create flashcards",
      "Your own decks will remain private until you share them.",
    );
  let deck = data?.deck || {
      id: uuid(),
      title: "",
      topic_id: topics[0].id,
      version: 1,
      owner_id: user.id,
    },
    cards = data?.cards?.map((c) => ({ ...c })) || [
      { id: uuid(), front: "", back: "" },
    ],
    page = 0;
  const cardInputs = () =>
    cards
      .slice(page * 20, page * 20 + 20)
      .map(
        (c, i) =>
          `<div class="card-editor"><div class="row"><h3>Card ${page * 20 + i + 1}</h3>${button(
            "Remove",
            () => {
              readCards();
              cards.splice(page * 20 + i, 1);
              paintCards();
            },
            "small subtle",
          )}</div>${area("Front", `front-${c.id}`, c.front, 'maxlength="4000" required')}${area("Back / answer", `back-${c.id}`, c.back, 'maxlength="4000" required')}</div>`,
      )
      .join("");
  function readCards() {
    for (const c of cards) {
      const front = document.getElementsByName(`front-${c.id}`)[0],
        back = document.getElementsByName(`back-${c.id}`)[0];
      if (front) c.front = front.value;
      if (back) c.back = back.value;
    }
  }
  function paintCards() {
    $("#card-inputs").innerHTML = cardInputs();
    $("#card-page").textContent =
      `${cards.length} cards · page ${page + 1} of ${Math.max(1, Math.ceil(cards.length / 20))}`;
  }
  async function importText() {
    const text = $("#import-text").value,
      result = previewCSV(
        text,
        $("#import-delimiter").value === "tab" ? "\t" : ",",
      );
    await modal(
      "Import preview",
      `<p>${result.valid.length} valid cards; ${result.errors.length} invalid rows; ${result.duplicates.length} duplicate rows.</p>${result.errors.map((e) => `<p class="error">Row ${e.row}: ${h(e.message)}</p>`).join("")}${button(
        "Import valid rows only",
        () => {
          readCards();
          const usable = result.valid.map((c) => ({
            id: uuid(),
            front: c.front,
            back: c.back,
          }));
          if (cards.length === 1 && !cards[0].front && !cards[0].back)
            cards = [];
          if (cards.length + usable.length > 500)
            throw new Error(
              "Split the import into decks of at most 500 cards.",
            );
          cards.push(...usable);
          $("#dialog").close();
          paintCards();
        },
        "primary",
        !result.valid.length,
      )}`,
    );
  }
  const html = `${title("Your flashcards", data ? "Refine your study deck." : "Make something worth remembering.", "Up to 500 cards. Text in English, Filipino and Hiligaynon stays intact.")}<div class="card">${form(
    "saveDeck",
    `${field("Deck title", "title", deck.title, "text", 'required maxlength="120"')}${select("Topic", "topic_id", topics, deck.topic_id)}<div id="card-inputs">${cardInputs()}</div><p id="card-page" class="caption">${cards.length} cards · page 1</p><div class="actions">${button(
      "← Previous cards",
      () => {
        readCards();
        page = Math.max(0, page - 1);
        paintCards();
      },
      "small",
    )}${button(
      "Next cards →",
      () => {
        readCards();
        page = Math.min(
          Math.max(0, Math.ceil(cards.length / 20) - 1),
          page + 1,
        );
        paintCards();
      },
      "small",
    )}${button(
      "Add a card",
      () => {
        readCards();
        if (cards.length >= 500)
          throw new Error("This deck has reached 500 cards.");
        cards.push({ id: uuid(), front: "", back: "" });
        page = Math.floor((cards.length - 1) / 20);
        paintCards();
      },
      "small",
    )}</div>${check("Keep duplicate cards if present", "allow_duplicates")}<div class="actions section"><button type="submit" class="primary">Save deck</button>${
      data
        ? button(
            "Delete deck",
            async () => {
              if (!confirm("Delete this deck and its card schedules?")) return;
              await client.mutate(
                "/api/decks/" + deck.id,
                {},
                { method: "DELETE", queue: true },
              );
              delete vault.data.localDecks?.[deck.id];
              await vault.save();
              await go("library");
            },
            "danger",
          )
        : ""
    }</div>`,
    async (f) => {
      readCards();
      if (cards.some((c) => !c.front.trim() || !c.back.trim()))
        throw new Error(
          "Every card needs both a front and a back. Remove empty cards.",
        );
      const body = {
        id: deck.id,
        version: deck.version,
        title: f.get("title"),
        topic_id: f.get("topic_id"),
        cards,
        allow_duplicates: f.has("allow_duplicates"),
      };
      vault.data.localDecks ??= {};
      vault.data.localDecks[deck.id] = {
        deck: { ...deck, title: body.title, topic_id: body.topic_id },
        cards,
        total: cards.length,
      };
      await vault.save();
      const result = await client.mutate(
        data ? "/api/decks/" + deck.id : "/api/decks",
        body,
        { method: data ? "PUT" : "POST", queue: true },
      );
      if (result.result?.deck) {
        const actual = result.result.deck;
        if (result.result.conflict_copy) {
          const canonical = await load(
            "/api/decks/" + actual.id + "?limit=100",
          );
          cards = canonical.cards;
        }
        delete vault.data.localDecks[deck.id];
        deck = actual;
        vault.data.localDecks[actual.id] = {
          deck: actual,
          cards,
          total: cards.length,
        };
        await vault.save();
      }
      toast(result.pending ? "Saved locally; waiting to sync." : "Deck saved.");
      await go("deck", { id: deck.id });
    },
  )}<details class="section"><summary>Import CSV or pasted text</summary><p class="caption">Two columns: front, back. Quoted commas and line breaks are supported. Preview, saving and editing work offline.</p><div class="field"><label for="import-file">Choose CSV or text file</label><input type="file" id="import-file" accept=".csv,.txt,text/csv,text/plain"></div><div class="field"><label for="import-delimiter">Separator</label><select id="import-delimiter"><option value=",">Comma</option><option value="tab">Tab</option></select></div><div class="field"><label for="import-text">Paste your cards</label><textarea id="import-text" placeholder="front,back"></textarea></div>${button("Preview import", importText)}</details></div>`;
  return {
    html,
    after() {
      $("#import-file").onchange = async (event) => {
        const f = event.target.files[0];
        if (f) {
          if (f.size > 1800000)
            return showError(
              new Error(
                "Import file is too large. Split it into smaller files.",
              ),
            );
          $("#import-text").value = await f.text();
        }
      };
    },
  };
};
views.review = async ({ data, practice = false }) => {
  let cards = data.cards.filter(
    (c) =>
      practice ||
      (!(vault?.data.reviews[c.id]?.due > Date.now()) &&
        (!c.due || c.due * 1000 <= Date.now())),
  );
  if (practice) cards = [...cards].sort(() => Math.random() - 0.5);
  let index = 0,
    flipped = false;
  const html = `${title(practice ? "Ungraded practice" : "Spaced review", data.deck.title, "No rush. Recall, turn over, and choose what feels honest.")}<div class="card"><div id="review-stage"></div></div>`;
  function paint() {
    const stage = $("#review-stage");
    if (index >= cards.length) {
      stage.innerHTML = `${empty(cards.length ? "A little more familiar." : "Nothing due right now.", cards.length ? "Your reviews are saved. Come back when these cards are due again." : "You can practice without earning repeated rewards.")}<div class="actions spaced">${button("Back to deck", () => go("deck", { id: data.deck.id }), "primary")}${button("Practice all cards", () => go("review", { data, practice: true }))}</div>`;
      return;
    }
    const card = cards[index];
    stage.innerHTML = `<div class="row"><span class="pill">Card ${index + 1} of ${cards.length}</span><span class="caption muted">${flipped ? "Answer" : "Try to recall"}</span></div><div class="spaced">${button(
      h(flipped ? card.back : card.front),
      () => {
        flipped = !flipped;
        paint();
      },
      "flashcard",
    )}</div>${card.image_id ? `<p class="caption">Image: ${h(card.image_alt || "Supporting image unavailable offline")}</p>${button("Load supporting image", () => go("material", { id: card.image_id }), "small")}` : ""}<p class="caption muted">Tap the card to turn it over.</p>${flipped ? `<div class="review-ratings"><span>${button("Again · 15 min", () => answer("again"), "rating-again")}</span><span>${button("Hard · 12 hr", () => answer("hard"))}</span><span>${button("Good · 1+ day", () => answer("good"), "primary")}</span><span>${button("Easy · 3+ days", () => answer("easy"))}</span></div>` : ""}`;
  }
  async function answer(rating) {
    const card = cards[index];
    const known = rating !== "again", delays = { again: 864000, hard: 43200000, good: 86400000, easy: 259200000 };
    if (!practice && user) {
      vault.data.reviews[card.id] = {
        known,
        rating,
        due: Date.now() + delays[rating],
      };
      await client.mutate(
        `/api/cards/${card.id}/review`,
        { known, rating, occurred: Date.now() / 1000 },
        { queue: true },
      );
    }
    companionFriendship(1);
    index++;
    flipped = false;
    paint();
    companionReact(known ? "celebrate" : "encourage");
  }
  return {
    html,
    after() {
      paint();
      if (cards.length) companionReact("think");
    },
  };
};
views.quiz = async ({ id, diagnostic = false }) => {
  if (!user && localStorage.getItem("guest-completed"))
    return `${title("Keep your progress", "Your first quiz is complete.", "Create an account to save your result and keep studying.")} ${button("Create my workspace", () => authPage("register"), "primary")}`;
  const data = await load("/api/quizzes/" + id),
    quiz = data.quiz;
  let attempt = vault?.data.attempts[id] || null,
    feedback = null;
  const html = `${title(diagnostic ? "Optional diagnostic" : "Explained quiz", quiz.title, "Understanding the answer matters more than a score.")}<div class="card"><div id="quiz-stage"></div></div>`;
  async function persist() {
    if (vault) {
      vault.data.attempts[id] = attempt;
      await vault.save();
    }
  }
  async function start(timed) {
    const qs = [...data.questions]
      .sort(() => Math.random() - 0.5)
      .map((q) => ({
        ...q,
        options: [...q.options].sort(() => Math.random() - 0.5),
      }));
    attempt = {
      id: uuid(),
      started: Date.now() / 1000,
      timed,
      duration: quiz.duration || qs.length * 60,
      questions: qs,
      answers: [],
      index: 0,
      version: quiz.version,
    };
    await persist();
    paint();
    companionReact("think");
  }
  async function finish() {
    const body = {
        id: attempt.id,
        version: attempt.version,
        started: attempt.started,
        ended: Date.now() / 1000,
        timed: attempt.timed,
        answers: attempt.answers,
      },
      score = attempt.answers.filter((a) => a.correct).length;
    const snapshot = attempt;
    if (user) {
      await client.mutate("/api/quizzes/" + id + "/offline", body, {
        queue: true,
        key: attempt.id,
      });
      delete vault.data.attempts[id];
      await vault.save();
    } else {
      localStorage.setItem(
        "guest-result",
        JSON.stringify({ quiz_id: id, body }),
      );
      localStorage.setItem("guest-completed", "1");
    }
    $("#quiz-stage").innerHTML =
      `<div class="eyebrow">A little more understanding</div><h2>${score} of ${snapshot.questions.length} correct</h2><p>Your topic progress comes from practice over time. One quiz is only one piece of evidence.</p>${snapshot.questions
        .map((q) => {
          const answer = snapshot.answers.find((a) => a.question_id === q.id);
          return `<div class="topic-row"><h3>${h(q.prompt)}</h3><p>Your answer: ${h(answer?.answer || "Unanswered")} · ${answer?.correct ? "Correct" : "Review this topic"}</p><strong>Accepted answer: ${h(q.accepted.join(" / "))}</strong><p>${h(q.explanation)}</p></div>`;
        })
        .join(
          "",
        )}<div class="actions section">${button("Retake with reshuffled questions", () => go("quiz", { id }), "primary")}${button(user ? "See my progress" : "Register and preserve this result", () => (user ? go("progress") : authPage("register")))}</div>`;
    attempt = null;
    companionReact("celebrate");
  }
  async function answer(value) {
    const q = attempt.questions[attempt.index],
      elapsed = Date.now() / 1000 - attempt.started,
      late = attempt.timed && elapsed > attempt.duration,
      normalized = (s) =>
        s.normalize("NFKC").trim().toLocaleLowerCase().replace(/\s+/g, " "),
      correct =
        !late && q.accepted.some((a) => normalized(a) === normalized(value));
    attempt.answers.push({
      question_id: q.id,
      answer: late ? "" : value,
      elapsed,
      correct,
    });
    feedback = { correct, late, q };
    attempt.index++;
    await persist();
    paint();
    companionFriendship(correct ? 2 : 1);
    companionReact(late || !correct ? "encourage" : "celebrate");
  }
  function paint() {
    const stage = $("#quiz-stage");
    if (!attempt) {
      stage.innerHTML = `<p>${data.questions.length} questions · multiple choice, true/false and identification. Each answer includes an explanation.</p><div class="actions">${button("Start untimed", () => start(false), "primary")}${button("Start timed", () => start(true))}${
        user
          ? button("Save quiz for offline", async () => {
              vault.data.cache["/api/quizzes/" + id] = { data, at: Date.now() };
              await vault.save();
              toast("Quiz and explanations saved.");
            })
          : ""
      }</div><p class="caption spaced">${h(quiz.source)} · ${h(quiz.license)}</p>`;
      return;
    }
    if (feedback) {
      stage.innerHTML = `<div class="quiz-feedback"><div class="eyebrow">${feedback.late ? "Time expired" : feedback.correct ? "That’s right" : "A chance to understand"}</div><h2>${h(feedback.q.accepted.join(" / "))}</h2><p>${h(feedback.q.explanation)}</p></div>${button(
        attempt.index >= attempt.questions.length
          ? "Finish & review"
          : "Next question",
        async () => {
          feedback = null;
          if (attempt.index >= attempt.questions.length) await finish();
          else paint();
        },
        "primary",
      )}`;
      return;
    }
    if (attempt.index >= attempt.questions.length) {
      stage.innerHTML = button("Finish & review", finish, "primary");
      return;
    }
    const q = attempt.questions[attempt.index];
    stage.innerHTML = `<div class="row"><span class="pill">Question ${attempt.index + 1} of ${attempt.questions.length}</span><span id="quiz-remaining" class="caption">${attempt.timed ? "Timed" : "Untimed · take your time"}</span></div><h2 class="spaced">${h(q.prompt)}</h2>${q.kind === "identification" ? form("identification", `${field("Your answer", "answer", "", "text", 'required maxlength="4000" autocomplete="off"')}<button type="submit" class="primary">Check answer</button>`, async (f) => answer(f.get("answer"))) : q.options.map((option) => button(h(option), () => answer(option), "answer-option")).join("")}<div class="spaced">${button(
      "Discard attempt",
      async () => {
        if (
          !confirm(
            "Discard this attempt? Your previous quiz history will remain.",
          )
        )
          return;
        if (vault) {
          delete vault.data.attempts[id];
          await vault.save();
        }
        attempt = null;
        paint();
      },
      "subtle small",
    )}</div>`;
  }
  return {
    html,
    after() {
      paint();
      const interval = setInterval(() => {
        if (!attempt?.timed) return;
        const left = Math.max(
          0,
          Math.ceil(attempt.duration - (Date.now() / 1000 - attempt.started)),
        );
        if ($("#quiz-remaining"))
          $("#quiz-remaining").textContent = `${left}s remaining`;
      }, 1000);
      cleanup = () => clearInterval(interval);
    },
  };
};
views.progress = async () => {
  if (!user)
    return `${title("Personal progress", "Measure against yourself.", "Sign in to see topic mastery and build a plan from your practice.")} ${button("Sign in", () => authPage(), "primary")}`;
  const p = await load("/api/progress"),
    sessions = await load("/api/study/sessions");
  return `${title("Personal progress", "A clearer picture of your learning.", "Your weakest topics first. These estimates are guidance, not grades.")} ${p.offline ? '<div class="banner">Last synced progress. New local work is waiting for validation.</div>' : ""}<div class="grid stats"><div class="card stat"><label>Study XP</label><strong>${p.wallet.xp}</strong><small>${p.levels_enabled ? "Level " + p.wallet.level : "Levels are currently hidden"}</small></div><div class="card stat"><label>This week</label><strong>${p.week_minutes} <span class="caption">min</span></strong><small>Goal: ${user.weekly_goal} minutes</small></div><div class="card stat"><label>Study streak</label><strong>${p.streak} <span class="caption">days</span></strong><small>One grace day / 30 days</small></div></div><div class="split section"><section class="card"><h2>Your suggested study plan</h2>${p.topics.map((t, i) => `<div class="topic-row"><div class="row"><div><h3>${i + 1}. ${h(t.title)}</h3><p class="caption">${h(t.label)} · ${t.mastery === null ? "Not assessed" : t.mastery + "% recall"} · ${t.evidence_count} pieces of evidence</p></div>${button("Practice", () => go("library", { query: t.title.split(" ")[0] }), "small")}</div>${progressBar(t.mastery, t.title + " mastery")}<p class="caption spaced">${h(t.confidence)}. Suggested: ${t.suggested_minutes} minutes, then a short explained quiz.</p></div>`).join("")}</section><section class="card"><h2>Small milestones</h2>${p.badges.length ? p.badges.map((b) => `<p><span class="badge">✦ ${h(b.badge)}</span></p>`).join("") : empty("Your first milestone is ahead", "Finish a focus session or quiz to earn a badge.")}<div class="divider"></div><h3>How progress is measured</h3><p class="caption">Recent quiz correctness and card recall contribute to topic mastery. Older evidence gradually counts less. Fewer than five observations is shown as low evidence.</p>${
    p.levels_enabled
      ? table(p.wallet.unlocks, [
          ["Level", "level"],
          ["Unlock", "title"],
        ])
      : ""
  }</section></div><section class="card section progress-story"><div>${companionSprite(companionById(companionState().selected), "story-companion")}</div><div><div class="eyebrow">Your weekly progress story</div><h2>${p.week_minutes ? `You made ${p.week_minutes} minutes of room for learning.` : "This week’s first chapter is ready."}</h2><p>${p.topics[0] ? `${companionById(companionState().selected).name} noticed that ${h(p.topics[0].title)} deserves the next gentle review. Your evidence grows one honest attempt at a time.` : "Complete a quiz or card review and your companion will help narrate what is improving."}</p></div></section><section class="card section"><h2>Quiz progress over time</h2>${
    p.history.length
      ? table(p.history, [
          ["Date", "started", (r) => h(date(r.started))],
          ["Quiz", "quiz_id"],
          ["Correct", "score"],
          ["Questions", "total"],
        ])
      : empty("No quiz history yet", "Try a short quiz from the library.")
  }</section><section class="card section"><h2>Your private session history</h2>${
    sessions.items.length
      ? table(sessions.items, [
          ["When", "started", (r) => h(date(r.started))],
          ["Topic", "topic_id"],
          ["Credited minutes", "credited"],
          ["Status", "state"],
          ["Notes", "notes"],
        ])
      : empty(
          "No synced sessions yet",
          "Your first focus session will appear here after syncing.",
        )
  }</section>`;
};
views.dungeon = async () => {
  if (!user)
    return `${title("3D learning game", "Enter the Dungeon of Knowledge", "Sign in to launch the local medieval maze.")}${button("Sign in", () => authPage(), "primary")}`;
  const companion = companionById(companionState().selected);
  const difficultyOptions = [
    { value: "easy", label: "Easy · 30 min · 10 mistakes · 2-coin hints" },
    { value: "average", label: "Average · 45 min · 7 mistakes · 3-coin hints" },
    { value: "hard", label: "Hard · 60 min · 5 mistakes · 4-coin hints" },
    { value: "hell", label: "Hell · 80 min · 3 mistakes · 5-coin hints" },
  ];
  return `${title("3D learning game", "Dungeon of Knowledge", "Explore a medieval maze, answer 100 encounters and survive its traps.")}<div class="split"><section class="card"><div class="eyebrow">Your selected companion</div><div class="dungeon-companion-preview">${companionSprite(companion, "story-companion")}<div><h2>${h(companion.name)}</h2><p>${h(companion.note)}</p><p class="caption">The dungeon launches with this companion automatically.</p></div></div></section><section class="card"><h2>Choose difficulty and enter</h2>${form("launchDungeon", `${select("Difficulty", "difficulty", difficultyOptions)}<button type="submit" class="primary full">Play 3D Dungeon</button>`, async (f) => {
    const result = await client.mutate("/api/dungeon/launch", {
      companion: companionState().selected,
      difficulty: f.get("difficulty"),
    }, { timeout: 20000 });
    toast(result.already_running ? "The dungeon is already open." : `Opening ${companion.name}’s dungeon…`);
    companionReact("celebrate", `${companion.name} is ready for the dungeon!`, "hop");
  })}</section></div><section class="card section"><h2>Controls</h2><div class="grid"><p><strong>WASD</strong><br><span class="caption">Move your companion</span></p><p><strong>Shift + WASD</strong><br><span class="caption">Run</span></p><p><strong>Arrow keys</strong><br><span class="caption">Move the camera</span></p><p><strong>M</strong><br><span class="caption">Open the map</span></p></div></section>`;
};
function chunkBase64(bytes) {
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += 0x8000)
    binary += String.fromCharCode(...bytes.subarray(offset, offset + 0x8000));
  return btoa(binary);
}
async function uploadStudioFile(file, titleValue) {
  if (!file) throw new Error("Choose a file first.");
  if (!file.size || file.size > 25 * 1024 * 1024)
    throw new Error("Choose a non-empty file no larger than 25 MB.");
  const bytes = new Uint8Array(await file.arrayBuffer()),
    sha256 = await digest(bytes),
    created = await client.mutate("/api/studio/sources", {
      title: titleValue.trim() || file.name,
      filename: file.name,
      mime: file.type || "application/octet-stream",
      bytes: file.size,
      sha256,
    }),
    id = created.source.id,
    size = 512 * 1024;
  for (let offset = 0; offset < bytes.length; offset += size) {
    const chunk = bytes.subarray(offset, Math.min(bytes.length, offset + size));
    await client.mutate(`/api/studio/sources/${id}/chunks`, {
      offset,
      base64: chunkBase64(chunk),
      complete: offset + chunk.length === bytes.length,
    }, { timeout: 30000 });
    const meter = $("#studio-upload-progress");
    if (meter) meter.value = ((offset + chunk.length) / bytes.length) * 100;
  }
  return id;
}
views.studio = async () => {
  if (!user)
    return `${title("AI Study Studio", "Turn your own files into study tools.", "Sign in to keep every upload private to your account.")}${button("Sign in", () => authPage(), "primary")}`;
  const data = await client.request("/api/studio", { cache: false });
  return `${title("Your private sources", "AI Study Studio", "Upload a source once, then make a reviewer, presentation, quiz, Quizlet set, flashcards, transcript or study plan.", `<span class="pill">${data.ai_enabled ? "AI ready" : "Local text mode"}</span>`)}${!data.ai_enabled ? '<div class="banner">AI is not configured on this server yet. Plain-text files can use the local draft generator; documents and audio remain safely stored until the server owner adds an OpenAI API key.</div>' : ""}<section class="card studio-upload"><h2>Add a private source</h2>${form("studioUpload", `${field("Source title", "title", "", "text", 'maxlength="120" placeholder="e.g. Biology finals reviewer"')}<div class="field"><label for="studio-file">File · any type, up to 25 MB</label><input id="studio-file" name="file" type="file" required><small>Files are stored as inert data and are never executed. AI processing supports common documents, images and audio formats.</small></div><progress id="studio-upload-progress" max="100" value="0" aria-label="Upload progress"></progress><button type="submit" class="primary">Upload source</button>`, async (f) => {
    const id = await uploadStudioFile(f.get("file"), f.get("title"));
    toast("Private source uploaded.");
    companionFriendship(1);
    companionReact("celebrate", "New notes! I’m ready to help turn them into something useful.");
    await go("studioSource", { id });
  })}</section><section class="section"><div class="section-header"><h2>Your sources</h2><span class="caption">${data.sources.length} private files</span></div><div class="grid studio-grid">${data.sources.map((source) => `<article class="card"><div class="icon-square">▧</div><h3>${h(source.title)}</h3><p class="caption">${h(source.filename)} · ${bytesLabel(source.bytes)} · ${h(source.state)}</p><div class="actions">${button("Create study tool", () => go("studioSource", { id: source.id }), "primary small")}${button("Delete", async () => { if (!confirm("Delete this source and every generated artifact?")) return; await client.mutate(`/api/studio/sources/${source.id}`, {}, { method: "DELETE" }); await go("studio"); }, "small danger")}</div></article>`).join("") || empty("No sources yet", "Upload lecture notes, a PDF, slides, a photo, audio or another private study file.")}</div></section><section class="section"><div class="section-header"><h2>Generated study tools</h2></div><div class="grid studio-grid">${data.artifacts.map((artifact) => `<article class="card"><span class="badge">${h(artifact.kind.replaceAll("_", " "))}</span><h3 class="spaced">${h(artifact.title)}</h3><p class="caption">${artifact.ai ? "AI generated" : "Local draft"} · ${h(date(artifact.created))}</p>${button("Open", () => go("studioArtifact", { id: artifact.id }), "small")}</article>`).join("") || empty("Nothing generated yet", "Choose a source and create the format that helps you study.")}</div></section>`;
};
views.studioSource = async ({ id }) => {
  const data = await client.request("/api/studio", { cache: false }), source = data.sources.find((x) => x.id === id);
  if (!source) return empty("Source unavailable", "It may have been deleted.");
  return `${title("AI Study Studio", source.title, `${source.filename} · ${bytesLabel(source.bytes)}`)}<section class="card"><h2>What should we make?</h2><p>Every result stays grounded in this source. Check generated content before relying on it for an exam.</p>${form("studioGenerate", `${select("Study tool", "kind", STUDIO_KINDS)}${area("Optional instructions", "instructions", "", 'maxlength="1000" placeholder="Focus on definitions, formulas, and likely exam questions."')}<button type="submit" class="primary">Generate study tool</button>`, async (f) => {
    const result = await client.mutate("/api/studio/generate", { source_id: id, kind: f.get("kind"), instructions: f.get("instructions") }, { timeout: 190000 });
    companionFriendship(2);
    companionReact("celebrate", "Done! Let’s check it together before exam day.");
    await go("studioArtifact", { id: result.artifact.id });
  })}</section><div class="actions section">${button("Back to Studio", () => go("studio"))}</div>`;
};
views.studioArtifact = async ({ id }) => {
  const result = await client.request(`/api/studio/artifacts/${id}`, { cache: false }), artifact = result.artifact;
  const parsed = (() => { try { return JSON.parse(artifact.body); } catch { return null; } })();
  return `${title(artifact.ai ? "AI-generated draft" : "Local draft", artifact.title, "Review against the source. You decide what belongs in your study materials.")}<section class="card studio-artifact">${artifactPreview(artifact, h)}</section><div class="actions section">${button("Download", () => { const file = artifactFile(artifact); downloadBlob(file.name, file.blob); }, "primary")}${["flashcards", "quizlet"].includes(artifact.kind) && Array.isArray(parsed) ? button("Edit as a Study Arena deck", () => go("deckEditor", { data: { deck: { id: uuid(), title: artifact.title, topic_id: topics[0].id, version: 1, owner_id: user.id }, cards: parsed.slice(0, 500).map((x) => ({ id: uuid(), front: String(x.front || ""), back: String(x.back || "") })) } })) : ""}${button("Back to Studio", () => go("studio"))}${button("Delete", async () => { if (!confirm("Delete this generated study tool?")) return; await client.mutate(`/api/studio/artifacts/${id}`, {}, { method: "DELETE" }); await go("studio"); }, "danger")}</div>`;
};
views.material = async ({ id }) => {
  let result;
  try {
    result = await load("/api/materials/" + id);
  } catch (error) {
    if (error.code === "CONTENT_LOCKED")
      return `${title("Optional study content", "An extra resource to earn.", error.message)}${button("Browse study rewards", () => go("shop"), "primary")}`;
    throw error;
  }
  const m = result.material;
  return `${title("Reference material", m.title, `${h(topics.find((t) => t.id === m.topic_id)?.subject)} · Year ${m.year} · ${m.file_type.toUpperCase()}`)}<article class="card"><p class="caption">Source: ${h(m.source)}<br>License: ${h(m.license)}${m.verified_by ? "<br>✓ Source and permission checked by a moderator" : ""}</p>${m.file_type === "text" ? `<div class="material-text">${h(m.body)}</div>` : `<p>This file is ${Math.ceil(m.bytes / 1024)} KB. Download it before opening to verify the complete file.</p>`}<div class="actions section">${button("Save / download for offline", () => downloadMaterial(id), "primary")}${user ? button("Report a copyright or content concern", () => report("material", id), "subtle small") : ""}</div></article>`;
};
async function downloadMaterial(id) {
  if (!vault) throw new Error("Sign in to save offline material.");
  let first = await load("/api/materials/" + id),
    m = first.material;
  if (m.file_type === "text") {
    vault.data.downloads[id] = { material: m, body: m.body, complete: true };
    await vault.save();
    downloadBlob(
      m.title.replace(/[^a-z0-9-]/gi, "_") + ".txt",
      new Blob([m.body], { type: "text/plain;charset=utf-8" }),
    );
    toast("Study notes saved for offline reading.");
    return;
  }
  const estimate = await navigator.storage?.estimate?.();
  if (estimate && estimate.quota - estimate.usage < m.bytes * 3)
    throw new Error(
      "Not enough device storage. Free space before downloading.",
    );
  let record = vault.data.downloads[id];
  if (!record || record.material.sha256 !== m.sha256)
    record = { material: m, chunks: [], offset: 0, complete: false };
  vault.data.downloads[id] = record;
  while (!record.complete) {
    const response =
      record.offset === 0
        ? first
        : await client.request(`/api/materials/${id}?offset=${record.offset}`, {
            cache: false,
          });
    if (response.material.sha256 !== m.sha256)
      throw new Error("The file changed during download. Restart it.");
    record.chunks.push(response.base64);
    record.offset = response.next_offset;
    record.complete = response.complete;
    await vault.save();
    toast(`Downloading ${Math.round((record.offset / m.bytes) * 100)}%`);
  }
  const arrays = record.chunks.map((text) =>
      Uint8Array.from(atob(text), (c) => c.charCodeAt(0)),
    ),
    bytes = new Uint8Array(arrays.reduce((n, a) => n + a.length, 0));
  let offset = 0;
  for (const part of arrays) {
    bytes.set(part, offset);
    offset += part.length;
  }
  if ((await digest(bytes)) !== m.sha256) {
    delete vault.data.downloads[id];
    await vault.save();
    throw new Error("File checksum failed. Please download it again.");
  }
  record.verified = true;
  await vault.save();
  downloadBlob(
    m.title.replace(/[^a-z0-9-]/gi, "_") + "." + m.file_type,
    new Blob([bytes], {
      type: m.file_type === "pdf" ? "application/pdf" : "image/" + m.file_type,
    }),
  );
}
views.materialEditor = async () =>
  `${title("Contribute content", "Good notes deserve good context.", "Include the original source and permission. Shared materials require review.")}<div class="card">${form(
    "material",
    `${field("Title", "title", "", "text", 'required maxlength="120"')}${select("Topic", "topic_id", topics)}${field("Year level", "year", 1, "number", 'min="1" max="6" required')}${area("Study notes / file description", "body", "", 'required maxlength="100000"')}${field("Source URL or attribution", "source", "", "text", 'required maxlength="500"')}${field("License or permission", "license", "", "text", 'required maxlength="120"')}<div class="field"><label for="material-file">Optional PDF, PNG or JPEG · up to 10 MB</label><input id="material-file" type="file" accept="application/pdf,image/png,image/jpeg"></div><button type="submit" class="primary">Submit for review</button>`,
    async (f) => {
      const file = $("#material-file").files[0];
      if (file && file.size > 10 * 1024 * 1024)
        throw new Error("File exceeds 10 MB.");
      const result = await client.mutate(
        "/api/materials",
        Object.fromEntries(f),
      );
      if (file) {
        const bytes = new Uint8Array(await file.arrayBuffer()),
          sha256 = await digest(bytes),
          type =
            file.type === "application/pdf"
              ? "pdf"
              : file.type === "image/png"
                ? "png"
                : "jpeg";
        for (let offset = 0; offset < bytes.length; offset += 256 * 1024) {
          const part = bytes.slice(offset, offset + 256 * 1024);
          let binary = "";
          for (const b of part) binary += String.fromCharCode(b);
          await client.mutate(
            "/api/materials/" + result.material.id + "/file",
            {
              offset,
              base64: btoa(binary),
              complete: offset + part.length === bytes.length,
              sha256,
              file_type: type,
            },
            { key: uuid() },
          );
          toast(
            `Uploading ${Math.round(((offset + part.length) / bytes.length) * 100)}%`,
          );
        }
      }
      toast("Submitted. A moderator will review your source and content.");
      await go("library", { tab: "materials" });
    },
  )}</div>`;
views.quizEditor = async () => {
  let questions = [{key: uuid(),kind:"mcq",prompt:"",options:"Option A\nOption B",accepted:"Option A",explanation:""}];
  function collect() { for (const q of questions) for (const field of ["kind","prompt","options","accepted","explanation"]) { const input=document.getElementsByName(`q-${q.key}-${field}`)[0];if(input)q[field]=input.value; } }
  function items() {return questions.map((q,i)=>`<section class="card-editor"><div class="row"><h3>Question ${i+1}</h3>${button("Remove",()=>{collect();if(questions.length===1)throw new Error("Keep at least one question.");questions=questions.filter(item=>item.key!==q.key);paint();},"small subtle")}</div>${select("Question type",`q-${q.key}-kind`,[{value:"mcq",label:"Multiple choice"},{value:"boolean",label:"True or false"},{value:"identification",label:"Identification"}],q.kind)}${area("Question",`q-${q.key}-prompt`,q.prompt,'required maxlength="4000"')}${area("Choices · one per line; leave empty for identification",`q-${q.key}-options`,q.options)}${area("Accepted answers · one per line",`q-${q.key}-accepted`,q.accepted,'required')}<p class="caption">For true/false questions use True and False as the two choices. Accepted answers must match the choices exactly.</p>${area("Explain why this answer is correct",`q-${q.key}-explanation`,q.explanation,'required maxlength="4000"')}</section>`).join("");}
  function paint(){ $("#question-editor").innerHTML=items(); }
  const html=`${title("Teacher publishing","Write an explained quiz.","Every question needs a useful explanation, not just a marked answer.")}<div class="card">${form("quizEditor",`${field("Quiz title","title","","text","required maxlength=120")}${select("Topic","topic_id",topics)}${field("Timed duration · seconds","duration",180,"number","min=30 max=7200")}${field("Source / attribution","source","Original instructor-written questions","text","required")}${field("License / permission","license","Original work · shared with permission","text","required")}<div id="question-editor">${items()}</div><div class="actions section">${button("Add a question",()=>{collect();if(questions.length>=100)throw new Error("A quiz can contain at most 100 questions.");questions.push({key:uuid(),kind:"mcq",prompt:"",options:"Option A\nOption B",accepted:"Option A",explanation:""});paint();})}<button type="submit" class="primary">Submit quiz for review</button></div>`,async f=>{collect();const lines=value=>value.split(/\r?\n/).map(v=>v.trim()).filter(Boolean);await client.mutate("/api/quizzes",{title:f.get("title"),topic_id:f.get("topic_id"),duration:+f.get("duration"),source:f.get("source"),license:f.get("license"),questions:questions.map(q=>({kind:q.kind,prompt:q.prompt,options:q.kind==="identification"?[]:lines(q.options),accepted:lines(q.accepted),explanation:q.explanation}))});toast("Quiz submitted for independent review.");await go("library",{tab:"quizzes"});})}</div>`;
  return {html,after(){ $("#question-editor").addEventListener("change",event=>{if(!event.target.name?.endsWith("-kind"))return;collect();const key=event.target.name.slice(2,-5),q=questions.find(q=>q.key===key);if(q?.kind==="boolean"){q.options="True\nFalse";q.accepted="True";}if(q?.kind==="identification"){q.options="";q.accepted="";}paint();}); }};
};
async function report(kind, target_id) {
  await modal(
    "Report a concern",
    form(
      "report",
      `${area("What should the moderator review?", "reason", "", 'required minlength="5" maxlength="2000"')}<p class="caption">Include the source of a copyright concern if known. Moderators can review the content; your private study notes are never attached.</p><button type="submit" class="primary">Send report</button>`,
      async (f) => {
        await client.mutate("/api/reports", {
          kind,
          target_id,
          reason: f.get("reason"),
        });
        $("#dialog").close();
        toast("Report received. You can track its status in Settings.");
      },
    ),
  );
}
views.shop = async () => {
  if (!user)
    return `${title("Study rewards", "Small rewards for steady effort.", "Earn cosmetics and study items without paying or competing.")} ${button("Sign in", () => authPage(), "primary")}`;
  const data = await load("/api/shop");
  vault.data.equipped=Object.fromEntries(data.inventory.filter(i=>i.equipped&&!i.consumed).map(i=>[i.kind,i.value]));await vault.save();
  return `${title("A little well-earned joy", "Make this space feel like you.", "Fixed prices. No paid entry, no random boxes, no cash payouts.", `<span class="pill">✦ ${data.wallet.coins} study coins</span>`)}${companionGallery()}${streakRewardGallery()}<div class="grid section">${data.items
    .map((item) => {
      const own = data.inventory.find(
          (i) => i.item_id === item.id && !i.consumed,
        ),
        claim = data.claims.find((c) => c.item_id === item.id);
      return `<article class="card shop-item"><div class="item-art" aria-hidden="true">${{ hat: "🌿", border: "◇", theme: "☾", skin: "🦊", freeze: "❄", prize: "▣", content: "▤" }[item.kind]}</div><h2>${h(item.title)}</h2><p>${item.price} coins · ${h(item.kind)}${item.stock !== null ? " · " + item.stock + " available" : ""}</p>${
        item.kind === "prize"
          ? button(
              "Read rules & eligibility",
              () => claimPrize(item),
              "primary small",
              item.stock === 0 || !!claim,
            )
          : own
            ? item.kind === "freeze"
              ? button(
                  "Protect yesterday’s streak",
                  async () => {
                    await client.mutate(`/api/inventory/${item.id}/freeze`);
                    toast("Yesterday is protected.");
                    await go("shop");
                  },
                  "small",
                )
              : button(
                  own.equipped ? "Equipped" : "Equip",
                  async () => {
                    await client.mutate(`/api/inventory/${item.id}/equip`);
                    if (item.kind === "theme") {
                      vault.data.theme = item.value;
                      document.documentElement.dataset.theme = item.value;
                      await vault.save();
                    }
                    toast("Your item is equipped.");
                    await go("shop");
                    companionReact("celebrate");
                  },
                  "small",
                  !!own.equipped,
                )
            : button(
                "Get for " + item.price + " coins",
                async () => {
                  await client.mutate(`/api/shop/${item.id}/purchase`);
                  toast("Added to your inventory.");
                  await go("shop");
                },
                "primary small",
                item.stock === 0,
              )
      }${claim ? `<p class="caption spaced">Claim: ${h(claim.state)}</p>` : ""}</article>`;
    })
    .join(
      "",
    )}</div><section class="card section"><h2>Prize claim history</h2><p class="caption">The school verifies age, eligibility and funding. Submission is not approval. Fulfillment is manual and always recorded.</p>${
    data.claims.length
      ? data.claims
          .map(
            (c) =>
              `<div class="topic-row"><div class="row"><div><strong>${h(c.title)}</strong><p>${h(c.state)} · ${h(c.reason)}</p></div>${
                ["pending", "approved"].includes(c.state)
                  ? button(
                      "Cancel & refund",
                      async () => {
                        if (
                          !confirm(
                            "Cancel this claim? Reserved stock and coins will be returned.",
                          )
                        )
                          return;
                        await client.mutate("/api/claims/" + c.id + "/cancel");
                        await go("shop");
                      },
                      "small",
                    )
                  : ""
              }</div></div>`,
          )
          .join("")
      : empty(
          "No prize claims",
          "Core study rewards are always available without a prize track.",
        )
  }</section>`;
};
async function claimPrize(item) {
  await modal(
    "Published prize rules",
    `<p class="material-text">${h(item.rules)}</p><p><strong>Sponsor:</strong> ${h(item.sponsor)}<br><strong>Rule version:</strong> ${item.rules_version}<br><strong>Age:</strong> ${item.adult_only ? "Verified adults only" : "Institution-approved eligibility and minor consent required"}</p>${button(
      "I accept these rules · submit claim",
      async () => {
        await client.mutate(`/api/shop/${item.id}/purchase`, {
          rules_version: item.rules_version,
        });
        $("#dialog").close();
        toast("Claim submitted for school review.");
        await go("shop");
      },
      "primary",
    )}`,
  );
}
views.rooms = async () => {
  if (!user)
    return empty(
      "Sign in to join a study room",
      "Solo study remains available.",
    );
  const data = await load("/api/rooms");
  return `${title("Study alongside others", "A little company, at your level.", "Rooms match your skill band. Studying together never requires competing.")}<div class="grid two"><div class="card"><h2>Create a small study room</h2>${form(
    "createRoom",
    `${field("Room name", "title", "", "text", 'required maxlength="80"')}${select("Topic", "topic_id", topics)}<button type="submit" class="primary">Create room</button>`,
    async (f) => {
      const result = await client.mutate("/api/rooms", Object.fromEntries(f));
      await go("room", { id: result.room.id });
      await modal(
        "Your room invite",
        `<p>Share this code with peers in the ${band(user.band)} band. It expires in 24 hours.</p><p><strong>${h(result.code)}</strong></p>`,
      );
    },
  )}</div><div class="card"><h2>Have an invite?</h2>${form(
    "joinRoom",
    `${field("Invite code", "code", "", "text", 'required maxlength="20"')}<button type="submit">Join room</button>`,
    async (f) => {
      const result = await client.mutate(
        "/api/rooms/join",
        Object.fromEntries(f),
      );
      await go("room", { id: result.room.id });
    },
  )}<p class="caption spaced">Each room holds up to 10 students. Invalid and expired codes receive the same response.</p></div></div><section class="section"><h2>Your rooms</h2><div class="grid">${
    data.mine
      .map(
        (r) =>
          `<div class="card"><h3>${h(r.title)}</h3><p>${h(r.state)} · ${band(r.band)}</p>${
            r.state === "active"
              ? button("Open room", () => go("room", { id: r.id }))
              : r.owner_id === user.id
                ? button("Restore room", async () => {
                    await client.mutate(
                      "/api/rooms/" + r.id,
                      { action: "restore" },
                      { method: "PUT" },
                    );
                    await go("rooms");
                  })
                : ""
          }</div>`,
      )
      .join("") ||
    empty(
      "No rooms yet",
      "Study alone, create a room, or join one when you feel like it.",
    )
  }</div></section><section class="section"><h2>Same-band study rooms</h2><div class="grid">${
    data.matching
      .filter((r) => !data.mine.some((m) => m.id === r.id))
      .map(
        (r) =>
          `<div class="card"><h3>${h(r.title)}</h3><p>${r.members} / 10 members · ${band(r.band)}</p>${button(
            "Join",
            async () => {
              const result = await client.mutate("/api/rooms/join", {
                room_id: r.id,
              });
              await go("room", { id: result.room.id });
            },
          )}</div>`,
      )
      .join("") ||
    empty(
      "No matching rooms right now",
      "You can create one or enjoy a solo study session.",
    )
  }</div></section>`;
};
views.room = async ({ id }) => {
  let data = await load("/api/rooms/" + id);
  const owner = data.room.owner_id === user.id;
  const [shareDecks,shareMaterials] = await Promise.all([load("/api/decks"),load("/api/materials")]);
  const shareChoices=[...shareDecks.items.map(d=>({value:"deck:"+d.id,label:"Flashcards · "+d.title})),...shareMaterials.items.filter(m=>m.status==="approved").map(m=>({value:"material:"+m.id,label:"Reference · "+m.title}))];
  function discussion() {
    return (
      data.messages
        .slice()
        .reverse()
        .map(
          (m) =>
            `<div class="chat-message"><div class="row"><strong>${h(m.display_name || "Former student")}</strong><small>${h(date(m.created))}</small></div><p>${h(m.body)}</p>${
              m.user_id !== user.id
                ? `<div class="actions">${button("Report", () => report("message", m.id), "small subtle")}${button(
                    "Block author",
                    async () => {
                      await client.mutate(
                        "/api/users/" + m.user_id + "/block",
                        { blocked: true },
                      );
                      await go("room", { id });
                    },
                    "small subtle",
                  )}</div>`
                : ""
            }</div>`,
        )
        .join("") ||
      empty(
        "A quiet room",
        "Ask a study question or start a shared focus time.",
      )
    );
  }
  const html = `${title("Your study room", data.room.title, `${band(data.room.band)} band · ${data.roster.length} / 10 members`)}<div class="split"><div class="stack"><section class="card"><h2>Study in parallel</h2><p id="group-clock">${data.room.timer_end ? Math.max(0, Math.ceil((data.room.timer_end - Date.now() / 1000) / 60)) + " minutes left in shared timer" : "No shared timer is running."}</p><p class="caption">Shared time keeps the room in rhythm. Start your own focus session to save private study credit.</p><div class="actions">${button("Start my focus session", () => go("focus"), "primary")}${
    owner
      ? button("Start 25-minute group timer", async () => {
          await client.mutate(
            "/api/rooms/" + id,
            { action: "timer", minutes: 25 },
            { method: "PUT" },
          );
          await go("room", { id });
        })
      : ""
  }</div><p class="caption spaced">Scheduled: ${data.room.scheduled ? h(date(data.room.scheduled)) : "No scheduled session"}</p>${
    owner
      ? form(
          "schedule",
          `${field("Schedule a session", "when", "", "datetime-local", "required")}<button type="submit" class="small">Save schedule</button>`,
          async (f) => {
            await client.mutate(
              "/api/rooms/" + id,
              {
                action: "schedule",
                scheduled: new Date(f.get("when")).getTime() / 1000,
              },
              { method: "PUT" },
            );
            await go("room", { id });
          },
        )
      : ""
  }</section><section class="card"><h2>Room discussion</h2><div id="room-messages">${discussion()}</div><div class="spaced">${form(
    "chat",
    `${area("Your message", "body", "", 'required maxlength="2000"')}<button type="submit" class="primary">Send message</button>`,
    async (f, el) => {
      const result = await client.mutate(
        "/api/rooms/" + id + "/messages",
        Object.fromEntries(f),
      );
      el.reset();
      if (result.support)
        await modal("Support is available", `<p>${h(result.support)}</p>`);
      data = await load("/api/rooms/" + id, { cache: false });
      $("#room-messages").innerHTML = discussion();
    },
  )}</div><p class="caption">Be kind. Block, leave or report at any time. Do not share personal or sensitive information.</p></section></div><div class="stack"><section class="card"><h2>People in your room</h2>${data.roster
    .map(
      (m) =>
        `<div class="topic-row"><strong>${h(m.display_name)}${m.id === data.room.owner_id ? " · owner" : ""}</strong><p class="caption">${band(m.band)}</p>${
          owner && m.id !== user.id
            ? `<div class="actions">${button(
                "Transfer ownership",
                async () => {
                  if (
                    !confirm(
                      "Transfer room ownership to " + m.display_name + "?",
                    )
                  )
                    return;
                  await client.mutate(
                    "/api/rooms/" + id,
                    { action: "transfer", user_id: m.id },
                    { method: "PUT" },
                  );
                  await go("room", { id });
                },
                "small",
              )}${button(
                "Remove",
                async () => {
                  if (!confirm("Remove this member from the room?")) return;
                  await client.mutate(
                    "/api/rooms/" + id,
                    { action: "remove", user_id: m.id },
                    { method: "PUT" },
                  );
                  await go("room", { id });
                },
                "small danger",
              )}</div>`
            : ""
        }</div>`,
    )
    .join("")}<div class="actions section">${
    owner
      ? button(
          "New invite code",
          async () => {
            const result = await client.mutate(
              "/api/rooms/" + id,
              { action: "rotate" },
              { method: "PUT" },
            );
            await modal(
              "New room invite",
              `<p><strong>${h(result.code)}</strong></p><p>Valid for 24 hours. Previous code is revoked.</p>`,
            );
          },
          "small",
        )
      : ""
  }${button(
    "Leave room",
    async () => {
      await client.mutate("/api/rooms/" + id + "/leave");
      await go("rooms");
    },
    "small",
  )}${
    owner
      ? button(
          "Disband room",
          async () => {
            if (!confirm("Archive this room and end member access?")) return;
            await client.mutate(
              "/api/rooms/" + id,
              { action: "disband" },
              { method: "PUT" },
            );
            await go("rooms");
          },
          "danger small",
        )
      : ""
  }</div></section><section class="card"><h2>Shared study resources</h2>${data.resources.map((resource) => `<p>${button(h(resource.kind + " · " + resource.resource_id), () => go(resource.kind === "deck" ? "deck" : "material", { id: resource.resource_id }), "small")}</p>`).join("") || "<p>No shared resources yet.</p>"}${form(
    "resource",
    `${select("Choose a study resource", "resource", shareChoices)}<button type="submit" class="small">Share resource</button>`,
    async (f) => {
      await client.mutate(
        "/api/rooms/" + id + "/resources",
        {kind:f.get("resource").split(":")[0],resource_id:f.get("resource").split(":").slice(1).join(":")},
      );
      await go("room", { id });
    },
  )}</section></div></div>`;
  return {
    html,
    after() {
      let busy = false;
      const poll = setInterval(async () => {
        if (document.hidden || busy || !navigator.onLine) return;
        busy = true;
        try {
          data = await client.request("/api/rooms/" + id, {
            cache: false,
            timeout: 5000,
          });
          $("#room-messages").innerHTML = discussion();
          $("#group-clock").textContent = data.room.timer_end
            ? Math.max(
                0,
                Math.ceil((data.room.timer_end - Date.now() / 1000) / 60),
              ) + " minutes left in shared timer"
            : "No shared timer is running.";
        } catch (error) {
          if (error instanceof ApiError && [403, 404].includes(error.status)) {
            clearInterval(poll);
            showError(
              new Error(
                "You no longer have access to this room. Your private timer remains available.",
              ),
            );
          }
        } finally {
          busy = false;
        }
      }, 5000);
      cleanup = () => clearInterval(poll);
    },
  };
};
views.duel = async () => {
  if (!user || !user.competition || !flag("competition"))
    return empty(
      "Optional competition is hidden",
      "Enable it in Settings if you want to try it. Solo study is always enough.",
    );
  let state = await client.request("/api/duels/current", { cache: false }),
    busy = false,
    selected = 0;
  function render() {
    if (state.duel) {
      const duel = state.duel,
        closed = duel.state !== "active",
        answered = new Set(state.answers.map((a) => a.question_id));
      selected = state.questions.findIndex((q) => !answered.has(q.id));
      const q = state.questions[selected];
      return `${title(duel.bot ? "Clearly labeled practice bot" : "Optional same-band duel", closed ? "A practice round, complete." : "One question at a time.", `${h(duel.opponent_name)} · ${band(user.band)} band`)}<div class="card"><div class="row"><span class="pill">${h(duel.state)}</span><span>${Math.max(0, Math.ceil(duel.deadline - state.server_time))}s remaining</span></div>${
        closed
          ? `<h2 class="spaced">${h(duel.result)}</h2><p>Player A: ${duel.a_score} · Player B: ${duel.b_score}. You were player ${h(duel.your_side.toUpperCase())}.</p>${state.questions.map((q) => `<div class="topic-row"><h3>${h(q.prompt)}</h3><p>Answer: ${h(q.accepted.join(" / "))}</p><p>${h(q.explanation)}</p></div>`).join("")}<div class="actions section">${button("Back to solo study", () => go("home"), "primary")}${button(
              "Find another round",
              async () => {
                state = { queued: false };
                shell(render());
              },
            )}${button("Report duel", () => report("duel", duel.id), "small")}</div>`
          : q
            ? `<h2 class="spaced">${h(q.prompt)}</h2>${form(
                "duelAnswer",
                `${field("Your answer", "answer", "", "text", 'required maxlength="4000" autocomplete="off"')}<button type="submit" class="primary">Submit answer</button>`,
                async (f) => {
                  const result = await client.mutate(
                    "/api/duels/" + duel.id + "/answer",
                    { question_id: q.id, answer: f.get("answer") },
                  );
                  state = result.duel;
                  shell(render());
                },
              )}`
            : '<p class="spaced">Your answers are submitted. Waiting for the other player…</p>'
      }${
        !closed
          ? button(
              "Forfeit round",
              async () => {
                if (!confirm("Forfeit this round?")) return;
                state = await client.mutate(
                  "/api/duels/" + duel.id + "/forfeit",
                );
                shell(render());
              },
              "subtle small",
            )
          : ""
      }</div>`;
    }
    if (state.queued)
      return `${title("Same-band matchmaking", "Looking for a study peer.", "You can leave at any time. We never widen your band automatically.")}<div class="card"><p>Searching for ${state.wait_seconds}s in ${band(user.band)}.</p><div class="actions">${button(
        "Cancel search",
        async () => {
          await client.mutate("/api/duels/queue", {}, { method: "DELETE" });
          state = { queued: false };
          shell(render());
        },
      )}${
        state.wait_seconds >= 20
          ? button(
              "Try a labeled practice bot",
              async () => {
                state = await client.mutate("/api/duels/queue", {
                  topic_id: topics[0].id,
                  bot: true,
                });
                shell(render());
              },
              "primary",
            )
          : ""
      }</div></div>`;
    return `${title("Optional competition", "A friendly round, if you feel like it.", "Matches use your private skill band. Competition earns no exclusive progression rewards.")}<div class="card">${form(
      "queueDuel",
      `${select("Topic", "topic_id", topics)}<p>Keep this screen open during the duel. Both players get 90 seconds plus the same two-second transport allowance. A lost connection has a 20-second return window.</p><button type="submit" class="primary">Find a same-band peer</button>`,
      async (f) => {
        state = await client.mutate("/api/duels/queue", Object.fromEntries(f));
        shell(render());
      },
    )}</div>`;
  }
  return {
    html: render(),
    after() {
      const poll = setInterval(async () => {
        if (
          busy ||
          document.hidden ||
          (!state.queued && !state.duel) ||
          (state.duel && state.duel.state !== "active")
        )
          return;
        busy = true;
        try {
          const next = await client.request("/api/duels/current", {
            cache: false,
            timeout: 5000,
          });
          if (next.duel || state.queued) {
            const typing = $(
              '[data-form="duelAnswer"] input[name="answer"]',
            )?.value;
            const unchanged =
              state.duel?.id === next.duel?.id &&
              state.duel?.state === next.duel?.state &&
              JSON.stringify(state.answers) === JSON.stringify(next.answers);
            state = next;
            if (!unchanged) {
              shell(render());
              if (typing && $('[data-form="duelAnswer"] input[name="answer"]'))
                $('[data-form="duelAnswer"] input[name="answer"]').value =
                  typing;
            }
          }
        } catch (error) {
          toast(
            "Connection interrupted. Return within 20 seconds to continue.",
          );
        } finally {
          busy = false;
        }
      }, 2000);
      cleanup = () => clearInterval(poll);
    },
  };
};
views.settings = async () => {
  if (!user)
    return `${title("Your preferences", "A study space that fits you.", "Sign in to customize reminders, privacy and your learning rhythm.")}<div class="actions">${button("Sign in", () => authPage(), "primary")}${button("Read privacy notice", privacy)}${button(
      "Switch light / dark",
      () => {
        document.documentElement.dataset.theme =
          document.documentElement.dataset.theme === "dark" ? "light" : "dark";
      },
    )}</div>`;
  const notifications = await load("/api/notifications"),
    settings = notifications.settings,
    devices = await load("/api/me/devices"),
    reports = await load("/api/reports");
  return `${title("Your preferences", "Make this space your own.", "Your goals, your privacy, your choice.")}<div class="tabs">${button("Rewards", () => go("shop"))}${flag("rooms") ? button("Study rooms", () => go("rooms")) : ""}${flag("competition") && user.competition ? button("Quiz duels", () => go("duel")) : ""}${["teacher", "admin"].includes(user.role) ? button("School console", () => go("admin")) : ""}</div><div class="split"><section class="card"><h2>Profile & study rhythm</h2>${profileForm()}<div class="divider"></div>${button(
    "Switch light / dark",
    async () => {
      vault.data.theme = vault.data.theme === "dark" ? "light" : "dark";
      document.documentElement.dataset.theme = vault.data.theme;
      await vault.save();
    },
  )}<p class="caption spaced">Display name is the only personal identity shown to room peers. Your school ID, email and study logs stay private.</p>${
    !user.verified
      ? button("Resend verification email", async () => {
          const result = await client.mutate("/api/auth/resend");
          toast(result.message);
        })
      : '<span class="badge">Email verified</span>'
  }</section><section class="card"><h2>Reminders without pressure</h2>${form(
    "notifications",
    `${["reminders", "streak", "invitations", "challenges", "rewards"].map((k) => check({ reminders: "Study reminders", streak: "Streak warnings", invitations: "Room invitations", challenges: "Duel challenges", rewards: "Reward events" }[k], k, !!settings[k])).join("")}${field("Reminder time", "reminder_time", settings.reminder_time, "time", "required")}<div class="grid two">${field("Quiet hours start · hour", "quiet_start", settings.quiet_start, "number", 'min="0" max="23"')}${field("Quiet hours end · hour", "quiet_end", settings.quiet_end, "number", 'min="0" max="23"')}</div>${field("Maximum notifications per day", "daily_cap", settings.daily_cap, "number", 'min="0" max="3"')}<button type="submit" class="primary">Save notification preferences</button>`,
    async (f) => {
      const body = Object.fromEntries(f);
      for (const k of [
        "reminders",
        "streak",
        "invitations",
        "challenges",
        "rewards",
      ])
        body[k] = f.has(k);
      const result = await client.mutate("/api/notifications/settings", body, {
        method: "PUT",
      });
      const scheduled = await reminders(result.settings);
      toast(
        scheduled.message ||
          (scheduled.denied
            ? "Notification preferences saved. Enable Android reminder permission to receive them."
            : "Reminder preferences saved."),
      );
    },
  )}<div class="spaced">${button("Enable Android push notifications", async () => toast((await pushRegistration(client)) ? "Android push registration requested." : "Push notifications need the configured Android app."), "small")}</div><p class="caption spaced">Quiet hours and a hard cap of three per day apply. Turning competition off also disables duel alerts.</p></section></div><section class="card section"><h2>Companion comfort</h2><p>Choose how lively your hand-drawn friend feels. Reduced-motion system settings always take priority.</p>${form("companionSettings", `${select("Movement", "motion", [{ value: "full", label: "Full movement" }, { value: "gentle", label: "Gentle movement" }, { value: "off", label: "Still" }], companionState().motion)}${select("Spoken reactions", "reactions", [{ value: "lively", label: "Lively" }, { value: "balanced", label: "Balanced" }, { value: "quiet", label: "Quiet" }], companionState().reactions)}<button type="submit" class="primary">Save companion settings</button>`, async (f) => { const state = companionState(); state.motion = f.get("motion"); state.reactions = f.get("reactions"); await vault.save(); document.documentElement.dataset.companionMotion = state.motion; toast("Companion settings saved."); await go("settings"); })}<div class="actions spaced">${button("Open companion room", () => go("companions"), "small")}${button("Reset companion position", async () => { delete companionState().position; await vault.save(); await go("settings"); }, "small")}</div></section><section class="card section"><h2>Sync & offline storage</h2><p>${vault.data.pending.length} operations waiting to sync. Your cache and queue are encrypted on this device.</p><div class="actions">${button(
    "Sync now",
    async () => {
      for (const op of vault.data.pending) op.error = null;
      await vault.save();
      await client.sync();
      await go("settings");
    },
    "primary",
  )}${button("Export local workspace", () => downloadJSON("Study_Arena_Local_Export.json", Object.fromEntries(Object.entries(vault.data).filter(([k]) => k !== "token"))))}${button(
    "Clear downloaded media",
    async () => {
      if (
        !confirm(
          "Clear downloaded media? Your unsynced study work and decks will remain.",
        )
      )
        return;
      vault.data.downloads = {};
      await vault.save();
      toast("Downloaded media cleared.");
    },
  )}</div>${vault.data.pending
    .map(
      (op) =>
        `<div class="topic-row"><strong>${h(op.method + " " + op.path)}</strong><p class="caption">${h(op.error || "Waiting to sync")}</p>${
          op.error
            ? button(
                "Archive blocked operation",
                async () => {
                  if (
                    !confirm(
                      "Archive this operation? It will stay in the local export but stop retrying.",
                    )
                  )
                    return;
                  vault.data.archivedOps ??= [];
                  vault.data.archivedOps.push(op);
                  vault.data.pending = vault.data.pending.filter(
                    (p) => p.id !== op.id,
                  );
                  await vault.save();
                  await go("settings");
                },
                "small",
              )
            : ""
        }</div>`,
    )
    .join(
      "",
    )}</section><section class="card section"><h2>Your notifications</h2>${
    notifications.items
      .map(
        (n) =>
          `<div class="topic-row"><p>${h(n.body)}</p><span class="caption">${h(date(n.created))}</span>${
            !n.read
              ? button(
                  "Mark read",
                  async () => {
                    await client.mutate("/api/notifications/" + n.id + "/read");
                    await go("settings");
                  },
                  "small subtle",
                )
              : ""
          }</div>`,
      )
      .join("") ||
    empty("Nothing asking for your attention", "A quiet inbox is a good thing.")
  }</section><section class="card section"><h2>Signed-in devices</h2>${devices.items
    .map(
      (d) =>
        `<div class="topic-row row"><div><strong>${d.current ? "This device" : "Other device"}</strong><p class="caption">${h(d.device)} · expires ${h(date(d.expires))}</p></div>${button(
          "Revoke",
          async () => {
            await client.mutate(
              "/api/me/devices/" + d.id,
              {},
              { method: "DELETE" },
            );
            if (d.current) await lock();
            else await go("settings");
          },
          "small",
        )}</div>`,
    )
    .join(
      "",
    )}</section><section class="card section"><h2>Reports you submitted</h2>${
    reports.items.length
      ? table(reports.items, [
          ["Type", "kind"],
          ["Status", "state"],
          ["Concern", "reason"],
          ["Outcome", "action"],
        ])
      : empty(
          "No reports",
          "Report unsafe or unlicensed content from its own screen.",
        )
  }</section><section class="card section"><h2>Privacy & account</h2><p>Export before deleting. Transfer or disband active rooms and resolve prize claims first. Virtual currency has no cash value.</p><div class="actions">${button("Privacy notice", privacy)}${button("Export server data", async () => downloadJSON("Study_Arena_Data_Export.json", await client.request("/api/me/export", { cache: false })))}${button(
    "Sign out & lock",
    async () => {
      try {
        await client.mutate("/api/auth/logout");
      } catch {}
      await lock();
    },
  )}${button(
    "Delete account",
    async () => {
      const confirm = prompt(
        "Type DELETE to revoke access and schedule account deletion in 30 days.",
      );
      if (confirm !== "DELETE") return;
      const result = await client.mutate("/api/me/delete", { confirm });
      toast(result.message);
      await lock();
    },
    "danger",
  )}</div></section>`;
};
views.admin = async () => {
  if (!["teacher", "admin"].includes(user?.role))
    return empty(
      "School console",
      "Teacher or administrator access is required.",
    );
  const data = await client.request("/api/admin", { cache: false }),
    admin = user.role === "admin";
  async function reasonAction(path, body, method = "POST") {
    const reason = prompt(
      "Reason for this action (recorded in the audit log):",
    );
    if (!reason) return;
    await client.mutate(path, { ...body, reason }, { method });
    toast("Action recorded.");
    await go("admin");
  }
  return `${title(admin ? "Administrator console" : "Teacher workspace", "Help learning stay safe and useful.", "Private student notes and individual study histories are never included here.")}<div class="card"><h2>Aggregate pilot usage</h2>${data.aggregate.suppressed ? `<p>${h(data.aggregate.message)}</p>` : `<div class="grid stats"><div class="stat"><label>Active students · 7 days</label><strong>${data.aggregate.active_students_7d}</strong></div><div class="stat"><label>Study minutes · 7 days</label><strong>${data.aggregate.study_minutes_7d}</strong></div><div class="stat"><label>Completed quizzes · 7 days</label><strong>${data.aggregate.completed_quizzes_7d}</strong></div></div>`}</div><div class="actions section">${button("Write reference notes", () => go("materialEditor"), "primary")}${button("Author a quiz", () => go("quizEditor"))}</div><section class="card section"><h2>Content moderation queue</h2>${
    data.content_queue.length
      ? data.content_queue
          .map(
            (item) =>
              `<div class="topic-row"><h3>${h(item.title)} <span class="badge">${h(item.kind)} · ${h(item.status)}</span></h3><p class="caption">${h(item.source)} · ${h(item.license)}</p><div class="actions">${button(
                "Inspect",
                async () => {
                  const result = await client.request(
                    `/api/admin/content/${item.kind}/${item.id}`,
                    { cache: false },
                  );
                  await modal(
                    "Review content",
                    `<pre class="material-text">${h(JSON.stringify(result, null, 2))}</pre>`,
                  );
                },
                "small",
              )}${button("Approve", () => reasonAction(`/api/admin/content/${item.kind}/${item.id}`, { status: "approved" }), "small primary")}${button("Quarantine", () => reasonAction(`/api/admin/content/${item.kind}/${item.id}`, { status: "quarantined" }), "small danger")}</div></div>`,
          )
          .join("")
      : empty(
          "You’re caught up",
          "No content is waiting in your assigned queue.",
        )
  }</section><section class="card section"><h2>Abuse & copyright reports</h2>${data.reports.map((r) => `<div class="topic-row"><h3>${h(r.kind)} · ${h(r.target_id)}</h3><p>${h(r.reason)}</p><p class="caption">Reported content: ${h(r.evidence)}</p><div class="actions">${["dismiss", "hide", "warn"].map((action) => button(action, () => reasonAction("/api/admin/reports/" + r.id, { action }), "small")).join("")}</div></div>`).join("") || empty("No pending reports", "Submitted concerns will appear here for authorized review.")}</section>${
    admin
      ? `<section class="card section"><h2>Feature flags</h2><p class="caption">The competition switch removes competitive surfaces globally. Levels never affect access to core learning.</p>${data.flags.map((f) => `<div class="topic-row row"><strong>${h(f.name)} · ${f.enabled ? "enabled" : "hidden"}</strong>${button(f.enabled ? "Disable" : "Enable", () => reasonAction("/api/admin/flags/" + f.name, { enabled: !f.enabled }, "PUT"), "small")}</div>`).join("")}</section><section class="card section"><h2>Prize claims</h2>${
          data.claims
            .map(
              (c) =>
                `<div class="topic-row"><h3>${h(c.title)} · ${h(c.state)}</h3><p class="caption">Student ${h(c.user_id)} · accepted rules v${c.rules_version}</p><div class="actions">${
                  c.state === "pending"
                    ? button(
                        "Verify & approve",
                        async () => {
                          const eligibility_ref = prompt(
                            "Institution record confirming age, consent, enrollment and study eligibility:",
                          );
                          if (eligibility_ref)
                            await reasonAction("/api/admin/claims/" + c.id, {
                              action: "approve",
                              eligibility_ref,
                            });
                        },
                        "primary small",
                      )
                    : ""
                }${["pending", "approved"].includes(c.state) ? button("Deny & refund", () => reasonAction("/api/admin/claims/" + c.id, { action: "deny" }), "small") : ""}${
                  c.state === "approved"
                    ? button(
                        "Record fulfillment",
                        async () => {
                          const receipt = prompt(
                            "Receipt / handover evidence reference:",
                          );
                          if (receipt)
                            await reasonAction("/api/admin/claims/" + c.id, {
                              action: "fulfill",
                              receipt,
                            });
                        },
                        "small",
                      )
                    : ""
                }</div></div>`,
            )
            .join("") ||
          empty(
            "No claims yet",
            "No cash transfers or automatic payouts are performed.",
          )
        }</section><section class="card section"><h2>User access & integrity</h2>${table(
          data.users,
          [
            ["Display name", "display_name"],
            ["Role", "role"],
            ["Age band", "age_band"],
            ["Restricted", "suspended"],
            [
              "Actions",
              "",
              (u) =>
                `<div class="actions">${button("Warn", () => reasonAction("/api/admin/users/" + u.id, { action: "warn" }), "small")}${button(u.suspended ? "Restore" : "Suspend", () => reasonAction("/api/admin/users/" + u.id, { action: u.suspended ? "restore" : "suspend" }), "small")}${button(
                  "Assign role",
                  async () => {
                    const role = prompt(
                      "Role: student, teacher, or admin",
                      u.role,
                    );
                    if (role)
                      await reasonAction("/api/admin/users/" + u.id, {
                        action: "role",
                        role,
                      });
                  },
                  "small",
                )}${button(
                  "Review skill band",
                  async () => {
                    const value = prompt(
                      "Reset band after reviewed evidence: 0 Foundation, 1 Developing, 2 Proficient, 3 Advanced",
                    );
                    if (value !== null)
                      await reasonAction("/api/admin/users/" + u.id, {
                        action: "reset_band",
                        band: +value,
                      });
                  },
                  "small",
                )}</div>`,
            ],
          ],
        )}</section><section class="card section"><h2>Review signals</h2><p class="caption">Signals are not accusations. Review evidence, warn, void the affected reward, reset band if justified, and suspend only under school policy. Students can appeal through the coordinator.</p>${
          data.risk.length
            ? table(data.risk, [
                ["Student", "user_id"],
                ["Signal", "signal"],
                ["Evidence reference", "evidence"],
              ])
            : empty(
                "No pending signals",
                "No suspicious activity has been queued.",
              )
        }</section><section class="card section"><h2>Append-only reward ledger</h2>${table(
          data.ledger,
          [
            ["Student", "user_id"],
            ["XP", "xp"],
            ["Coins", "coins"],
            ["Reason", "reason"],
            ["When", "created", (r) => h(date(r.created))],
          ],
        )}<details class="section"><summary>Record a reviewed compensation</summary>${form(
          "ledger",
          `${field("Student ID", "user_id", "", "text", "required")}${field("XP adjustment", "xp", 0, "number", 'min="-100000" max="100000"')}${field("Coin adjustment", "coins", 0, "number", 'min="-100000" max="100000"')}${field("Unique case reference", "origin", "", "text", 'required minlength="8"')}${area("Evidence and reason", "reason", "", 'required minlength="5"')}<button type="submit">Record compensating entry</button>`,
          async (f) => {
            await client.mutate("/api/admin/ledger", Object.fromEntries(f));
            await go("admin");
          },
        )}</details></section><section class="card section"><h2>Catalog & stock</h2>${table(
          data.catalog,
          [
            ["Item", "title"],
            ["Kind", "kind"],
            ["Price", "price"],
            ["Stock", "stock"],
            [
              "Actions",
              "",
              (item) =>
                button(
                  "Update stock",
                  async () => {
                    const stock = prompt("Remaining stock:", item.stock ?? 0);
                    if (stock !== null)
                      await reasonAction(
                        "/api/admin/catalog/" + item.id,
                        { stock: +stock, active: !!item.active },
                        "PUT",
                      );
                  },
                  "small",
                ),
            ],
          ],
        )}<details class="section"><summary>Create a fixed reward</summary>${form(
          "catalog",
          `${field("Title", "title", "", "text", "required")}${select(
            "Kind",
            "kind",
            [
              "skin",
              "border",
              "hat",
              "theme",
              "content",
              "freeze",
              "prize",
            ].map((v) => ({ value: v, label: v })),
          )}${field("Price in earned coins", "price", 10, "number", 'min="0"')}${field("Available stock", "stock", 10, "number", 'min="0"')}${check("Adults only", "adult_only", true)}${field("School or organization sponsor", "sponsor")}${area("Published rules · no paid entry, cash or chance", "rules")}${field("Rules version", "rules_version", 1, "number", 'min="1"')}${field("Cosmetic value or content resource ID", "value")}${area("Audit reason", "reason", "", 'required minlength="5"')}<button type="submit" class="primary">Create catalog item</button>`,
          async (f) => {
            await client.mutate("/api/admin/catalog", {
              ...Object.fromEntries(f),
              adult_only: f.has("adult_only"),
            });
            await go("admin");
          },
        )}</details></section><section class="card section"><h2>Assign teacher cohorts</h2>${form(
          "cohort",
          `${field("Cohort ID", "cohort_id", "pilot", "text", "required")}${field("Cohort title", "title", "Pilot cohort", "text", "required")}${field("Student or teacher user ID", "user_id", "", "text", "required")}${check("Assign as cohort moderator", "moderator")}${field("Audit reason", "reason", "", "text", 'required minlength="5"')}<button type="submit">Assign cohort</button>`,
          async (f) => {
            await client.mutate("/api/admin/cohorts", {
              ...Object.fromEntries(f),
              moderator: f.has("moderator"),
            });
            await go("admin");
          },
        )}</section><section class="card section"><h2>Audit trail</h2>${table(
          data.audit,
          [
            ["Action", "action"],
            ["Target", "target"],
            ["Reason", "reason"],
            ["When", "created", (r) => h(date(r.created))],
          ],
        )}</section>`
      : ""
  }`;
};

// Delegated events survive screen updates, and all user text is escaped before rendering.
document.addEventListener("click", async (event) => {
  const buttonEl = event.target.closest("[data-action]");
  if (!buttonEl) return;
  const action = handlers[buttonEl.dataset.action];
  if (!action) return;
  buttonEl.disabled = true;
  try {
    await action();
  } catch (error) {
    showError(error);
  } finally {
    if (buttonEl.isConnected) buttonEl.disabled = false;
  }
});
document.addEventListener("submit", async (event) => {
  const el = event.target.closest("[data-form]");
  if (!el) return;
  event.preventDefault();
  const handler = formHandlers[el.dataset.form];
  if (!handler) return;
  const buttonEl = el.querySelector("[type=submit]");
  if (buttonEl) buttonEl.disabled = true;
  try {
    await handler(new FormData(el), el);
  } catch (error) {
    showError(error);
  } finally {
    if (buttonEl?.isConnected) buttonEl.disabled = false;
  }
});
window.addEventListener("online", () => {
  client
    .sync()
    .then(() => toast("Connection restored. Saved work is syncing."));
});
window.addEventListener("hashchange", async () => {
  if (
    location.hash.startsWith("#verify?") ||
    location.hash.startsWith("#reset?")
  )
    await handleLink();
  else if (location.hash === "#home") await go("home");
});
async function handleLink() {
  const [action, query] = location.hash.slice(1).split("?"),
    token = new URLSearchParams(query).get("token");
  if (action === "verify") {
    try {
      const result = await client.mutate("/api/auth/verify", { token });
      history.replaceState(null, "", location.pathname);
      toast(result.message);
      await authPage();
    } catch (error) {
      showError(error);
    }
  } else if (action === "reset") {
    await modal(
      "Set a new password",
      form(
        "passwordReset",
        `${field("New password", "password", "", "password", 'required minlength="12" maxlength="128"')}<button type="submit" class="primary">Reset password</button>`,
        async (f) => {
          const result = await client.mutate("/api/auth/reset", {
            token,
            password: f.get("password"),
          });
          $("#dialog").close();
          history.replaceState(null, "", location.pathname);
          toast(result.message);
          await authPage();
        },
      ),
    );
  }
}
async function boot() {
  if ("serviceWorker" in navigator && !window.Capacitor?.isNativePlatform?.()) {
    let refreshing = false;
    navigator.serviceWorker.addEventListener("controllerchange", () => {
      if (!refreshing) { refreshing = true; location.reload(); }
    });
    navigator.serviceWorker.register("/sw.js").then((registration) => registration.update()).catch(() => {});
  }
  try {
    [health, config] = await Promise.all([
      client.request("/api/health", { timeout: 1000 }),
      client.request("/api/config", { timeout: 1000 }),
    ]);
  } catch {}
  if (
    location.hash.startsWith("#verify?") ||
    location.hash.startsWith("#reset?")
  ) {
    await authPage();
    await handleLink();
  } else await go("home");
}
setInterval(() => {
  if (vault && !document.hidden) {
    client.sync().catch(() => {});
    if (navigator.onLine) client.request("/api/config", {cache:false,timeout:3000}).then(next => {
      const wasCompetition = flag("competition"); config = next;
      if (wasCompetition && !flag("competition")) {
        if (route === "duel") go("home");
        else document.querySelectorAll("button").forEach(el => {if (el.textContent.includes("Quiz duels")) el.remove();});
      }
    }).catch(() => {});
  }
}, 15000);
boot().catch(showError);
