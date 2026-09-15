import { spawn } from "node:child_process";
import { mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
export async function server(port = 8181) {
  const dir = await mkdtemp(path.join(os.tmpdir(), "arena-test-"));
  const origin = `http://127.0.0.1:${port}`;
  let logs = "";
  const child = spawn(
    process.env.JAVA_BIN || "java",
    process.env.ARENA_TEST_JAR ? ["-Xmx256m", "-jar", "dist/study-arena.jar", "--demo"] : [
      "-Xmx256m",
      "-cp",
      `build/classes${path.delimiter}.deps/*`,
      "ph.edu.wit.studyarena.Main",
      "--demo",
    ],
    {
      env: {
        ...process.env,
        PORT: String(port),
        APP_ORIGIN: origin,
        DATA_DIR: dir,
      },
      stdio: ["ignore", "pipe", "pipe"],
    },
  );
  child.stdout.on("data", (b) => (logs += b));
  child.stderr.on("data", (b) => (logs += b));
  for (let i = 0; i < 150; i++) {
    try {
      const r = await fetch(`${origin}/api/health`);
      if (r.ok)
        return {
          url: origin,
          dir,
          logs: () => logs,
          stop: async () => {
            child.kill();
            await new Promise((ok) => child.once("exit", ok));
            await rm(dir, { recursive: true, force: true });
          },
        };
    } catch {}
    if (child.exitCode !== null) throw new Error(logs);
    await new Promise((ok) => setTimeout(ok, 100));
  }
  child.kill();
  throw new Error("Server did not start: " + logs);
}
