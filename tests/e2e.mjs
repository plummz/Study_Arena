import { chromium } from "playwright";
import { server } from "./server.mjs";
import assert from "node:assert/strict";
import { mkdir, writeFile } from "node:fs/promises";
const app = await server(8282);
let browser;
const errors = [],
  results = [];
try {
  let options = { headless: true };
  if (process.env.CHROMIUM_PACKAGE) {
    const mod = await import(process.env.CHROMIUM_PACKAGE);
    options = {
      ...options,
      executablePath:
        process.env.CHROMIUM_EXECUTABLE || (await mod.default.executablePath()),
      args: mod.default.args.filter(a => !["--disable-web-security","--allow-running-insecure-content"].includes(a)),
    };
  }
  if (process.env.CHROMIUM_EXECUTABLE && !process.env.CHROMIUM_PACKAGE) options.executablePath = process.env.CHROMIUM_EXECUTABLE;
  browser = await chromium.launch(options);
  results.push = (...items) => { console.log(...items); return Array.prototype.push.apply(results, items); };
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1040 },
  });
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  cdp.on("Runtime.exceptionThrown", ({ exceptionDetails }) =>
    console.error("Browser exception details:", JSON.stringify(exceptionDetails)),
  );
  await cdp.send("Runtime.enable");
  page.on("pageerror", (e) => errors.push(e.stack || e.message));
  await page.goto(app.url);
  try {
    await page.getByRole("heading", { name: /A little progress/ }).waitFor();
  } catch (error) {
    console.error("Browser startup errors:", errors);
    throw error;
  }
  assert.equal(
    await page.getByRole("button", { name: "Quiz duels", exact: true }).count(),
    0,
  );
  results.push("E2E01 Guest dashboard loads; competition hidden");
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await page.getByLabel("Email", { exact: true }).fill("student@study.test");
  await page
    .getByLabel("Password / local workspace password")
    .fill("StudyArena!2026");
  await page.getByRole("button", { name: "Enter my study space" }).click();
  const studentOnboarding = page.getByRole("heading", {
    name: "What are you studying?",
  });
  const studentHome = page.getByRole("heading", {
    name: /A little progress/,
  });
  const studentStudio = page.getByRole("button", {
    name: "AI Study Studio",
    exact: true,
  });
  await studentOnboarding.or(studentStudio).first().waitFor();
  if (await studentOnboarding.isVisible()) {
    await page.getByRole("button", { name: "Save my preferences" }).click();
    await page.getByRole("button", { name: "Skip for now" }).click();
  }
  await studentHome.waitFor();
  await studentStudio.waitFor();
  results.push(
    "E2E02 Login, encrypted workspace, onboarding and skip diagnostic",
  );
  await studentStudio.click();
  await page.getByLabel("Source title").fill("Motion and force notes");
  await page.getByLabel(/File · any type/).setInputFiles({
    name: "motion.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("Force is mass multiplied by acceleration. Acceleration is the change in velocity over time. Net force is the vector sum of all forces acting on an object."),
  });
  await page.getByRole("button", { name: "Upload source" }).click();
  await page.getByRole("heading", { name: "What should we make?" }).waitFor();
  await page.getByRole("button", { name: "Generate study tool" }).click();
  await page.getByText("Recall prompts").waitFor();
  results.push("E2E02A Private text upload creates and opens a local reviewer");
  await page.getByRole("button", { name: "My space", exact: true }).click();
  await mkdir("docs/screenshots", { recursive: true });
  await page.locator("#toast").evaluate((el) => el.classList.remove("show"));
  await page.screenshot({
    path: "docs/screenshots/desktop-home.png",
    fullPage: true,
  });
  await page
    .getByRole("button", { name: "Study library", exact: true })
    .click();
  await page.getByRole("button", { name: "Quizzes", exact: true }).click();
  await page
    .locator("article")
    .filter({
      has: page.getByRole("heading", { name: "algebra · quick practice" }),
    })
    .getByRole("button", { name: "Open →" })
    .click();
  await page.getByRole("button", { name: "Save quiz for offline" }).click();
  await page.getByRole("button", { name: "Start untimed" }).click();
  await page.getByRole("heading").last().waitFor();
  const offlineAttempt = await page.evaluate(async () => {
    const r = await new Promise((ok, no) => {
      const q = indexedDB.open("study-arena-v1");
      q.onsuccess = () => ok(q.result);
      q.onerror = () => no(q.error);
    });
    const row = await new Promise((ok) => {
      const q = r
        .transaction("vaults")
        .objectStore("vaults")
        .get("student@study.test");
      q.onsuccess = () => ok(q.result);
    });
    return {
      encrypted: row.encrypted instanceof ArrayBuffer,
      plain: JSON.stringify(row).includes("StudyArena!2026"),
    };
  });
  assert.equal(offlineAttempt.encrypted, true);
  assert.equal(offlineAttempt.plain, false);
  results.push(
    "E2E03 Quiz downloaded; password absent from plaintext IndexedDB record",
  );
  await context.setOffline(true);
  const choice = page.locator(".answer-option").first();
  if (await choice.count()) await choice.click();
  else {
    await page.getByLabel("Your answer", { exact: true }).fill("4");
    await page.getByRole("button", { name: "Check answer" }).click();
  }
  await page.locator(".quiz-feedback").waitFor();
  results.push("E2E04 Solo answer and explanation work without network");
  await page.reload();
  // "Keep me signed in" (on by default) reopens the encrypted workspace without the password,
  // even offline.
  await page
    .getByRole("button", { name: "AI Study Studio", exact: true })
    .waitFor();
  await page.getByRole("heading", { name: /A little progress/ }).waitFor();
  assert.equal(await page.getByRole("button", { name: "Sign in", exact: true }).count(), 0);
  results.push(
    "E2E05 Offline reload through the service worker resumes the remembered encrypted workspace without re-entering the password",
  );
  await context.setOffline(false);
  await page
    .getByRole("button", { name: "Study library", exact: true })
    .click();
  await page.getByRole("button", { name: "Quizzes", exact: true }).click();
  await page
    .locator("article")
    .filter({
      has: page.getByRole("heading", { name: "algebra · quick practice" }),
    })
    .getByRole("button", { name: "Open →" })
    .click();
  await page.getByText("Question 2 of 3", { exact: true }).waitFor();
  results.push("E2E06 Quiz resumes from the saved next question");
  await page.getByRole("button", { name: "Focus time", exact: true }).click();
  await page
    .getByLabel("A note for this session · optional")
    .fill("E2E private focus notes");
  await page.getByRole("button", { name: "Begin focus time" }).click();
  await page.getByRole("button", { name: "Pause", exact: true }).click();
  await page.getByRole("button", { name: "Resume", exact: true }).waitFor();
  await page
    .getByRole("button", { name: "Finish session", exact: true })
    .click();
  await page
    .getByRole("heading", { name: "You showed up. That matters." })
    .waitFor();
  results.push(
    "E2E07 Focus start/pause/finish; short session saved without reward",
  );
  await page.setViewportSize({ width: 360, height: 800 });
  await page.getByRole("button", { name: "Home", exact: true }).click();
  await page.getByRole("heading", { name: /A little progress/ }).waitFor();
  assert.ok(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth + 1,
    ),
  );
  await page.locator("#toast").evaluate((el) => el.classList.remove("show"));
  await page.screenshot({
    path: "docs/screenshots/mobile-home.png",
    fullPage: true,
  });
  results.push("E2E08 360px mobile reflow without horizontal overflow");
  await page.getByRole("button", { name: "More", exact: true }).click();
  await page.getByLabel("Display theme", { exact: true }).selectOption("dark");
  await page.getByRole("button", { name: "Apply theme", exact: true }).click();
  assert.equal(await page.locator("html").getAttribute("data-theme"), "dark");
  await page.screenshot({
    path: "docs/screenshots/mobile-settings-dark.png",
    fullPage: true,
  });
  results.push("E2E09 Dark mode saved in the encrypted workspace");

  // Exercise the final contributor form changes through real UI submissions.
  // A separate browser profile, so the student's remembered sign-in is not resumed here.
  const teacherContext = await browser.newContext({ viewport: { width: 1440, height: 1040 } });
  const teacherPage = await teacherContext.newPage();
  teacherPage.on("pageerror", e => errors.push(e.message));
  await teacherPage.goto(app.url);
  await teacherPage.getByRole("heading",{name:/A little progress/}).waitFor();
  await teacherPage.getByRole("button",{name:"Sign in",exact:true}).click();
  await teacherPage.getByLabel("Email",{exact:true}).fill("teacher@study.test");
  await teacherPage.getByLabel("Password / local workspace password").fill("StudyArena!2026");
  await teacherPage.getByRole("button",{name:"Enter my study space"}).click();
  await teacherPage.getByRole("heading",{name:"What are you studying?"})
    .or(teacherPage.getByRole("button",{name:"AI Study Studio",exact:true}))
    .first()
    .waitFor();
  if(await teacherPage.getByRole("heading",{name:"What are you studying?"}).isVisible()){
    await teacherPage.getByRole("button",{name:"Save my preferences"}).click();
    await teacherPage.getByRole("button",{name:"Skip for now"}).click();
  }
  await teacherPage.getByRole("button",{name:"AI Study Studio",exact:true}).waitFor();
  await teacherPage.getByRole("button",{name:"Study library",exact:true}).click();
  await teacherPage.getByRole("button",{name:"Create a quiz",exact:true}).click();
  await teacherPage.getByLabel("Quiz title",{exact:true}).fill("Browser authored explained quiz");
  await teacherPage.getByLabel("Question type",{exact:true}).selectOption("boolean");
  assert.equal(await teacherPage.getByLabel("Accepted answers · one per line").inputValue(),"True");
  await teacherPage.getByLabel("Question",{exact:true}).fill("Two plus two equals four.");
  await teacherPage.getByLabel("Explain why this answer is correct").fill("Adding two objects to two objects gives four objects.");
  const submitted = teacherPage.waitForResponse(r => r.url().endsWith("/api/quizzes") && r.request().method()==="POST");
  await teacherPage.getByRole("button",{name:"Submit quiz for review"}).click();
  const quizResponse = await submitted;
  assert.equal(quizResponse.status(),200,await quizResponse.text());
  results.push("E2E11 Teacher authors and submits an explained true/false quiz through labeled fields");
  await teacherPage.getByRole("button",{name:"Study rooms",exact:true}).click();
  await teacherPage.getByLabel("Room name",{exact:true}).fill("Browser study room");
  await teacherPage.getByRole("button",{name:"Create room",exact:true}).click();
  await teacherPage.getByRole("heading",{name:"Your room invite"}).waitFor();
  await teacherPage.keyboard.press("Escape");
  const choices=teacherPage.getByLabel("Choose a study resource",{exact:true});
  assert.ok(await choices.locator("option").count()>0);
  await teacherPage.getByRole("button",{name:"Share resource",exact:true}).click();
  results.push("E2E12 Room resource sharing selects a named resource and submits successfully");
  async function call(route, body, token){
    const r=await fetch(app.url+route,{method:body?"POST":"GET",headers:{...(body?{"Content-Type":"application/json","Idempotency-Key":crypto.randomUUID()}:{}),...(token?{Authorization:"Bearer "+token}:{})},...(body?{body:JSON.stringify(body)}:{})});
    const data=await r.json();assert.equal(r.status,200,JSON.stringify(data));return data;
  }
  const adminAuth=await call("/api/auth/login",{email:"admin@study.test",password:"StudyArena!2026"});
  const studentAuth=await call("/api/auth/login",{email:"student@study.test",password:"StudyArena!2026"});
  await call("/api/admin/ledger",{user_id:studentAuth.user.id,xp:0,coins:100,origin:crypto.randomUUID(),reason:"Browser cosmetic test funding"},adminAuth.token);
  const shop=await call("/api/shop",null,studentAuth.token);
  const hat=shop.items.find(i=>i.kind==="hat");
  await page.setViewportSize({width:1440,height:1040});
  await page.getByRole("navigation",{name:"Main",exact:true}).getByRole("button",{name:"Rewards",exact:true}).click();
  await page.locator(".companion-card").first().waitFor();
  assert.equal(await page.locator(".companion-card").count(),18);
  const coralCard=page.locator("article.companion-card").filter({has:page.getByRole("heading",{name:"Coral",exact:true})});
  await coralCard.getByRole("button",{name:"Unlock Coral free",exact:true}).click();
  await page.locator('#companion-dock[aria-label^="Coral,"]').waitFor();
  await page.waitForFunction(() => document.querySelector("#companion-bubble")?.textContent?.includes("Coral joined"));
  assert.match(await page.locator("#companion-bubble").textContent(),/Coral joined/);
  assert.ok((await page.locator("article.companion-card.selected").getByRole("heading").textContent()).includes("Coral"));
  await page.screenshot({path:"docs/screenshots/desktop-companions.png",fullPage:true});
  results.push("E2E14 Eighteen free companions render; Coral unlocks, equips and reacts");
  const dock=page.locator("#companion-dock"),
    beforeDrag=await dock.boundingBox();
  assert.ok(beforeDrag);
  await page.mouse.move(beforeDrag.x+beforeDrag.width/2,beforeDrag.y+beforeDrag.height/2);
  await page.mouse.down();
  await page.mouse.move(Math.max(160,beforeDrag.x-320),Math.max(170,beforeDrag.y-150),{steps:10});
  await page.mouse.up();
  const afterDrag=await dock.boundingBox();
  assert.ok(afterDrag);
  assert.ok(Math.abs(afterDrag.x-beforeDrag.x)>60 || Math.abs(afterDrag.y-beforeDrag.y)>60);
  await dock.evaluate((element)=>element.dataset.dragged="false");
  await page.getByRole("button",{name:/Talk to Coral/}).click();
  assert.equal(await dock.getAttribute("data-motion"),"run");
  assert.match(await page.locator("#companion-bubble").textContent(),/Zoom! Catch me/);
  await page.getByRole("navigation",{name:"Main",exact:true}).getByRole("button",{name:"My space",exact:true}).click();
  await page.getByRole("heading",{name:/A little progress/}).waitFor();
  const afterRender=await page.locator("#companion-dock").boundingBox();
  assert.ok(afterRender);
  assert.ok(Math.abs(afterRender.x-afterDrag.x)<5 && Math.abs(afterRender.y-afterDrag.y)<5);
  results.push("E2E15 Companion drags within the app, saves its position and uses character-specific movement speech");
  await page.getByRole("navigation",{name:"Main",exact:true}).getByRole("button",{name:"Rewards",exact:true}).click();
  await page.locator(".companion-card").first().waitFor();
  const hatCard=page.locator("article").filter({has:page.getByRole("heading",{name:hat.title,exact:true})});
  await hatCard.getByRole("button",{name:"Get for "+hat.price+" coins"}).click();
  await hatCard.getByRole("button",{name:"Equip",exact:true}).click();
  await page.locator('.avatar[aria-label*="leaf hat"]').waitFor();
  results.push("E2E13 Purchased hat equips and appears on the profile avatar");
  const coinsIn = async (selector) => Number((await page.locator(selector).textContent()).match(/\d+/)[0]);
  const shopCoins = await coinsIn("#shop-coins");
  await page.getByRole("navigation",{name:"Main",exact:true}).getByRole("button",{name:"My space",exact:true}).click();
  await page.locator("#home-coins").waitFor();
  assert.equal(await coinsIn("#home-coins"), shopCoins);
  assert.equal(shopCoins, (await call("/api/wallet", null, studentAuth.token)).wallet.coins);
  results.push("E2E16 Home and Rewards show the same server-confirmed coin balance after coins arrive from outside the page");
  const reward = async (title, price) => {
    await page.getByRole("navigation",{name:"Main",exact:true}).getByRole("button",{name:"Rewards",exact:true}).click();
    const card = page.locator("article").filter({has:page.getByRole("heading",{name:title,exact:true})});
    await card.getByRole("button",{name:`Get for ${price} coins`}).click();
    await card.getByRole("button",{name:"Equip",exact:true}).click();
  };
  await reward("Gentle confetti", 15);
  const layer = page.locator(".celebration-layer.celebration-confetti");
  await layer.waitFor({ state: "attached" });
  assert.equal(await layer.getAttribute("aria-hidden"), "true");
  assert.equal(await layer.evaluate((el) => getComputedStyle(el).display), "block");
  await page.emulateMedia({ reducedMotion: "reduce" });
  assert.equal(await layer.evaluate((el) => getComputedStyle(el).display), "none");
  await page.emulateMedia({ reducedMotion: "no-preference" });
  results.push("E2E17 Purchased confetti plays on celebrate and is hidden under reduced motion");
  await reward("Warm paper theme", 20);
  await page.waitForFunction(() => document.documentElement.dataset.theme === "sepia");
  await page.getByRole("navigation",{name:"Main",exact:true}).getByRole("button",{name:"Settings",exact:true}).click();
  const themeSelect = page.getByLabel("Display theme", { exact: true });
  await themeSelect.waitFor();
  assert.deepEqual(await themeSelect.locator("option").allTextContents(), ["Light", "Dark", "High contrast", "Warm paper"]);
  await themeSelect.selectOption("contrast");
  await page.getByRole("button", { name: "Apply theme", exact: true }).click();
  await page.waitForFunction(() => document.documentElement.dataset.theme === "contrast");
  await page.getByLabel("Display theme", { exact: true }).selectOption("light");
  await page.getByRole("button", { name: "Apply theme", exact: true }).click();
  results.push("E2E18 Warm paper theme bought and equipped; free high-contrast theme applied from Settings");
  await page.getByRole("navigation",{name:"Main",exact:true}).getByRole("button",{name:"My space",exact:true}).click();
  await page.getByRole("button", { name: "Add a note to self", exact: true }).click();
  await page.getByLabel("Your note", { exact: true }).fill("Synthetic reminder: <b>lab</b> report due Friday");
  await page.getByRole("button", { name: "Save note", exact: true }).click();
  await page.locator(".home-note-text").waitFor();
  assert.equal(await page.locator(".home-note-text").textContent(), "Synthetic reminder: <b>lab</b> report due Friday");
  await page.locator(".home-note").getByRole("button", { name: "Edit note", exact: true }).click();
  await page.getByLabel("Show on my Home screen").uncheck();
  await page.getByRole("button", { name: "Save note", exact: true }).click();
  await page.getByRole("button", { name: "Show note to self", exact: true }).waitFor();
  assert.equal(await page.locator(".home-note").count(), 0);
  results.push("E2E19 Private note to self is written, shown as text, and hidden from Home");
  const phone = await browser.newContext({ viewport: { width: 375, height: 667 }, isMobile: true, hasTouch: true });
  const phonePage = await phone.newPage();
  phonePage.on("pageerror", (e) => errors.push(e.message));
  await phonePage.goto(app.url);
  await phonePage.getByRole("heading", { name: /A little progress/ }).waitFor();
  await phonePage.getByRole("button", { name: "Sign in", exact: true }).click();
  const authCard = phonePage.locator(".auth");
  await authCard.waitFor();
  const password = phonePage.getByLabel("Password / local workspace password");
  await password.fill("Synthetic-secret-1");
  await phonePage.getByRole("button", { name: "Show password" }).click();
  assert.equal(await password.getAttribute("type"), "text");
  await phonePage.getByRole("button", { name: "Hide password" }).click();
  assert.equal(await password.getAttribute("type"), "password");
  assert.equal(await phonePage.getByLabel("Keep me signed in on this device").isChecked(), true);
  results.push("E2E22 Password Show/Hide toggle works; “Keep me signed in” is offered and on by default");
  const cardBox = await authCard.boundingBox();
  assert.ok(Math.abs(cardBox.x - (375 - cardBox.x - cardBox.width)) <= 1, "login card is horizontally centred");
  assert.ok(await phonePage.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
  await phonePage.setViewportSize({ width: 375, height: 600 });
  assert.equal((await authCard.boundingBox()).y, cardBox.y, "card stays put when the visible height shrinks");
  let notch = "unsupported";
  try {
    const phoneCdp = await phone.newCDPSession(phonePage);
    await phoneCdp.send("Emulation.setSafeAreaInsetsOverride", { insets: { top: 47, left: 0, bottom: 34, right: 0 } });
    notch = await phonePage.locator(".auth-screen").evaluate((el) => getComputedStyle(el).paddingTop);
  } catch {}
  await phonePage.screenshot({ path: "docs/screenshots/mobile-login.png", fullPage: true });
  results.push(`E2E20 375px login card is centred, stable when the viewport height changes, no overflow; notch top padding: ${notch}`);
  await phone.close();
  // A fresh context: a full-page screenshot after a CDP override drops Chromium's touch emulation.
  const wide = await browser.newContext({ viewport: { width: 932, height: 430 }, isMobile: true, hasTouch: true });
  const widePage = await wide.newPage();
  widePage.on("pageerror", (e) => errors.push(e.message));
  await widePage.goto(app.url);
  await widePage.getByRole("heading", { name: /A little progress/ }).waitFor();
  const landscape = await widePage.evaluate(() => ({
    width: innerWidth,
    nav: getComputedStyle(document.querySelector(".bottom-nav")).display,
    sidebar: getComputedStyle(document.querySelector(".sidebar")).display,
  }));
  assert.deepEqual(landscape, { width: 932, nav: "flex", sidebar: "none" });
  const navButton = await widePage.locator(".bottom-nav button").first().boundingBox();
  assert.ok(navButton.height >= 56, `bottom-nav buttons are at least 56px tall (${navButton.height})`);
  results.push("E2E21 932px landscape phone uses the mobile bottom navigation");
  await wide.close();
  await teacherPage.close();

  assert.deepEqual(errors, []);
  results.push("E2E10 No uncaught browser exceptions");
  console.log(results.join("\n"));
  await writeFile(
    "docs/e2e-results.json",
    JSON.stringify({ passed: results, errors }, null, 2),
  );
} catch (error) {
  if (browser) {
    const pages = browser.contexts().flatMap((c) => c.pages());
    if (pages[0]) {
      await mkdir("docs/screenshots", { recursive: true });
      await pages[0].screenshot({
        path: "docs/screenshots/e2e-failure.png",
        fullPage: true,
      });
      for (const p of pages) console.error((await p.locator("body").innerText()).slice(0, 4500));
    }
  }
  console.error(app.logs());
  throw error;
} finally {
  await browser?.close();
  await app.stop();
}
