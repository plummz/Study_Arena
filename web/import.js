/** Offline CSV preview. Keeps invalid rows separate until the student explicitly confirms valid rows. */
export function previewCSV(text, delimiter = ",") {
  const records = [],
    errors = [],
    valid = [],
    duplicates = [],
    seen = new Set();
  let row = [],
    field = "",
    quoted = false,
    closed = false,
    record = 1,
    malformed = false;
  function endField() {
    row.push(field.replace(/\r$/, ""));
    field = "";
    closed = false;
  }
  function endRow() {
    endField();
    records.push({ row, record, malformed });
    row = [];
    record++;
    malformed = false;
  }
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (char === '"') {
      if (quoted && text[i + 1] === '"') {
        field += '"';
        i++;
      } else if (quoted) {
        quoted = false;
        closed = true;
      } else if (field.length === 0 && !closed) {
        quoted = true;
      } else {
        malformed = true;
        field += char;
      }
    } else if (char === delimiter && !quoted) endField();
    else if (char === "\n" && !quoted) endRow();
    else {
      if (closed && char !== "\r" && char !== " ") malformed = true;
      field += char;
    }
  }
  if (row.length || field.length || quoted) {
    if (quoted) malformed = true;
    endRow();
  }
  for (const item of records) {
    const cells = item.row;
    if (
      item.record === 1 &&
      cells[0]?.replace(/^\uFEFF/, "").toLowerCase() === "front" &&
      cells[1]?.toLowerCase() === "back"
    )
      continue;
    if (
      item.malformed ||
      cells.length !== 2 ||
      cells.some((c) => !c.trim() || [...c].length > 4000)
    ) {
      errors.push({
        row: item.record,
        message:
          "Expected two nonempty fields, valid CSV quoting, and at most 4,000 characters per side.",
      });
      continue;
    }
    const fingerprint = cells
      .map((c) =>
        c.normalize("NFKC").trim().toLocaleLowerCase().replace(/\s+/g, " "),
      )
      .join("\0");
    if (seen.has(fingerprint)) duplicates.push(item.record);
    seen.add(fingerprint);
    valid.push({ front: cells[0], back: cells[1], row: item.record });
  }
  return { valid, errors, duplicates };
}
