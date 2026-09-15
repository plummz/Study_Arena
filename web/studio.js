export const STUDIO_KINDS = [
  { value: "reviewer", label: "Reviewer", note: "Key ideas, examples and recall prompts" },
  { value: "summary", label: "Summary", note: "A short source-grounded overview" },
  { value: "study_plan", label: "Study plan", note: "A focused sequence of study tasks" },
  { value: "flashcards", label: "Flashcards", note: "Question-and-answer cards you can import" },
  { value: "quizlet", label: "Quizlet set", note: "Term/definition CSV for Quizlet import" },
  { value: "quiz", label: "Practice quiz", note: "Questions, answers and explanations" },
  { value: "slides", label: "Presentation", note: "A PowerPoint-readable slide outline" },
  { value: "transcript", label: "Audio transcript", note: "Speech converted to text" },
];

export function bytesLabel(bytes = 0) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

export function safeJSON(body) {
  try {
    return JSON.parse(body);
  } catch {
    return null;
  }
}

export function artifactPreview(artifact, escape) {
  const parsed = safeJSON(artifact.body);
  if (!Array.isArray(parsed))
    return `<div class="studio-document">${escape(artifact.body)}</div>`;
  if (["flashcards", "quizlet"].includes(artifact.kind))
    return `<div class="studio-cards">${parsed.map((card, i) => `<article><span>${i + 1}</span><h3>${escape(card.front)}</h3><p>${escape(card.back)}</p></article>`).join("")}</div>`;
  if (artifact.kind === "quiz")
    return parsed.map((q, i) => `<details class="studio-question"><summary>${i + 1}. ${escape(q.prompt)}</summary><p>${(q.options || []).map(escape).join(" · ")}</p><strong>Answer: ${escape(q.answer)}</strong><p>${escape(q.explanation)}</p></details>`).join("");
  if (artifact.kind === "slides")
    return `<div class="studio-slides">${parsed.map((slide, i) => `<article><span>Slide ${i + 1}</span><h2>${escape(slide.title)}</h2><ul>${(slide.bullets || []).map((line) => `<li>${escape(line)}</li>`).join("")}</ul></article>`).join("")}</div>`;
  return `<div class="studio-plan">${parsed.map((item, i) => `<article><strong>${i + 1}. ${escape(item.task || item.title || "Study task")}</strong><p>${escape(item.reason || "")}${item.minutes ? ` · ${escape(item.minutes)} minutes` : ""}</p></article>`).join("")}</div>`;
}

function fileStem(title) {
  return String(title || "Study_Arena")
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/gi, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 70) || "Study_Arena";
}

function csvCell(value) {
  return `"${String(value ?? "").replaceAll('"', '""')}"`;
}

export function artifactFile(artifact) {
  const parsed = safeJSON(artifact.body), stem = fileStem(artifact.title);
  if (["flashcards", "quizlet"].includes(artifact.kind) && Array.isArray(parsed)) {
    const csv = "\ufeffTerm,Definition\r\n" + parsed.map((x) => `${csvCell(x.front)},${csvCell(x.back)}`).join("\r\n");
    return { name: `${stem}.csv`, blob: new Blob([csv], { type: "text/csv;charset=utf-8" }) };
  }
  if (artifact.kind === "quiz" && Array.isArray(parsed))
    return { name: `${stem}.json`, blob: new Blob([JSON.stringify(parsed, null, 2)], { type: "application/json" }) };
  if (artifact.kind === "slides" && Array.isArray(parsed)) {
    const slides = parsed.map((slide) => `<section class="slide"><h1>${htmlEscape(slide.title)}</h1><ul>${(slide.bullets || []).map((x) => `<li>${htmlEscape(x)}</li>`).join("")}</ul><footer>Created in Study Arena</footer></section>`).join("");
    const document = `<!doctype html><html><head><meta charset="utf-8"><title>${htmlEscape(artifact.title)}</title><style>@page{size:13.333in 7.5in;margin:0}.slide{box-sizing:border-box;width:13.333in;height:7.5in;padding:.8in 1in;page-break-after:always;font:28pt Arial;color:#223c32;background:#fffdf5}.slide h1{font-size:36pt;color:#356b50}.slide li{margin:.25in 0}.slide footer{position:absolute;bottom:.35in;font-size:12pt;color:#667}</style></head><body>${slides}</body></html>`;
    return { name: `${stem}.ppt`, blob: new Blob([document], { type: "application/vnd.ms-powerpoint" }) };
  }
  const extension = artifact.kind === "transcript" ? "txt" : "md";
  return { name: `${stem}.${extension}`, blob: new Blob([artifact.body], { type: "text/plain;charset=utf-8" }) };
}

function htmlEscape(value) {
  return String(value ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}
