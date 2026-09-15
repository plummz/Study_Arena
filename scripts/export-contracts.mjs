import { server } from "../tests/server.mjs";
import { writeFile } from "node:fs/promises";
const app = await server(8383);
try {
  const paths = [
    "/api/topics",
    "/api/decks",
    "/api/quizzes",
    "/api/materials",
    "/api/config",
  ];
  for (const topic of ["algebra", "calculus", "computing"])
    paths.push(
      `/api/decks/starter-${topic}?limit=100`,
      `/api/quizzes/quiz-${topic}`,
      `/api/materials/notes-${topic}`,
    );
  const seed = {};
  for (const p of paths)
    seed[p] = await fetch(app.url + p).then((r) => r.json());
  await writeFile("web/starter.json", JSON.stringify(seed));
  await writeFile(
    "docs/api-contract.json",
    JSON.stringify(
      await fetch(app.url + "/api/contracts").then((r) => r.json()),
      null,
      2,
    ),
  );
  console.log("Exported starter content and implementation API contracts.");
} finally {
  await app.stop();
}
