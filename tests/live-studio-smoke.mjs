import { chromium } from "playwright";
import assert from "node:assert/strict";

const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.CHROMIUM_EXECUTABLE,
});
const errors = [];
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto(process.env.STUDY_ARENA_URL || "http://localhost:8080");
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await page.getByLabel("Email", { exact: true }).fill("student@study.test");
  await page.getByLabel("Password / local workspace password").fill("StudyArena!2026");
  await page.getByRole("button", { name: "Enter my study space" }).click();
  const onboarding = page.getByRole("heading", { name: "What are you studying?" });
  const home = page.getByRole("heading", { name: /A little progress/ });
  await Promise.race([onboarding.waitFor(), home.waitFor()]);
  if (await onboarding.isVisible()) {
    await page.getByRole("button", { name: "Save my preferences" }).click();
    await page.getByRole("button", { name: "Skip for now" }).click();
  }
  await home.waitFor();
  await page.getByRole("button", { name: "AI Study Studio", exact: true }).click();
  await page.getByLabel("Source title").fill("Browser smoke source");
  await page.getByLabel(/File · any type/).setInputFiles({
    name: "browser-smoke.txt",
    mimeType: "text/plain",
    buffer: Buffer.from("Force is mass multiplied by acceleration. Acceleration measures velocity change over time. Net force is the vector sum of forces acting on an object."),
  });
  await page.getByRole("button", { name: "Upload source" }).click();
  await page.getByRole("heading", { name: "What should we make?" }).waitFor();
  await page.getByRole("button", { name: "Generate study tool" }).click();
  await page.getByText("Recall prompts").waitFor();
  console.log("WIN01 Private upload and reviewer generation passed");

  await page.getByRole("button", { name: "Rewards", exact: true }).click();
  assert.equal(await page.locator("article.companion-card").count(), 8);
  assert.match(await page.locator(".streak-rewards").innerText(), /days together/i);
  await page.getByRole("button", { name: "Visit companion room" }).click();
  await page.getByRole("button", { name: "Run", exact: true }).click();
  assert.equal(await page.locator("#companion-dock").getAttribute("data-motion"), "run");
  console.log("WIN02 Eight companions, streak rewards and movement room passed");
  assert.deepEqual(errors, []);
  console.log("WIN03 No uncaught browser errors");
} finally {
  await browser.close();
}
