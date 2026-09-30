package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.util.*;

public final class DomainTests {
  static int passed;

  static void check(boolean ok, String label) {
    if (!ok) throw new AssertionError(label);
    passed++;
    System.out.println("PASS " + label);
  }

  public static void main(String[] args) throws Exception {
    String password = Util.password("A long password for tests!");
    check(
        Util.verify("A long password for tests!", password),
        "SEC01 PBKDF2 validates correct password");
    check(!Util.verify("incorrect", password), "SEC02 wrong password rejected");
    byte[] key = new byte[32];
    RANDOM.nextBytes(key);
    String cipher = crypt("Private pagtuon notes 📖", key, true);
    check(
        crypt(cipher, key, false).equals("Private pagtuon notes 📖"),
        "SEC03 Unicode AES-GCM roundtrip");
    byte[] wrong = new byte[32];
    boolean rejected = false;
    try {
      crypt(cipher, wrong, false);
    } catch (IllegalStateException e) {
      rejected = true;
    }
    check(rejected, "SEC04 incorrect encryption key rejected");
    check(normalized("  O(N)  ").equals("o(n)"), "QUIZ01 normalized identification answers");
    check(
        !Study.correct(Util.map("accepted", List.of("12")), "13"),
        "QUIZ02 near answers not silently accepted");
    var csv = Content.csv("front,back\n\"Comma, question\",\"line 1\nline 2\"\nQ,A\nQ,A", ',');
    check(((List<?>) csv.get("valid")).size() == 3, "CSV01 quoted comma and newline");
    check(((List<?>) csv.get("duplicates")).size() == 1, "CSV02 duplicate warning");
    check(
        !((List<?>) Content.csv("\"unclosed,field", ',').get("errors")).isEmpty(),
        "CSV03 unclosed quote rejected");
    try (Db db = new Db(":memory:")) {
      db.schema();
      db.insert(
          "users",
          map(
              "id",
              "u",
              "email",
              "u@test.edu",
              "password_hash",
              password,
              "school_hash",
              "school",
              "school_cipher",
              cipher,
              "display_name",
              "User",
              "age_band",
              "adult",
              "created",
              now()));
      db.insert(
          "topics", map("id", "topic", "subject", "Math", "title", "Algebra", "course", "STEM"));
      db.insert(
          "ledger",
          map(
              "id",
              "entry",
              "user_id",
              "u",
              "xp",
              10,
              "coins",
              2,
              "origin",
              "study:test",
              "reason",
              "Test evidence",
              "created",
              now()));
      rejected = false;
      try {
        db.exec("UPDATE ledger SET coins=100 WHERE id='entry'");
      } catch (Exception e) {
        rejected = true;
      }
      check(rejected, "DB01 ledger update rejected");
      rejected = false;
      try {
        db.exec("DELETE FROM ledger WHERE id='entry'");
      } catch (Exception e) {
        rejected = true;
      }
      check(rejected, "DB02 ledger delete rejected");
      db.audit("u", "test", "entry", "Recorded evidence");
      rejected = false;
      try {
        db.exec("UPDATE audit SET reason='rewrite'");
      } catch (Exception e) {
        rejected = true;
      }
      check(rejected, "DB03 audit rewrite rejected");
      db.c.setAutoCommit(false);
      db.exec("INSERT INTO flags VALUES('rollback',1)");
      db.c.rollback();
      db.c.setAutoCommit(true);
      check(db.one("SELECT * FROM flags WHERE name='rollback'") == null, "DB04 rollback atomicity");
      rejected = false;
      try {
        db.insert("inventory", map("user_id", "u", "item_id", "missing", "acquired", now()));
      } catch (Exception e) {
        rejected = true;
      }
      check(rejected, "DB05 foreign key enforced");
    }
    java.nio.file.Path legacy = java.nio.file.Files.createTempFile("arena-legacy-", ".db");
    try {
      try (Db db = new Db(legacy.toString())) {
        db.schema();
        // Recreate the catalog as released before the 'effect' kind existed.
        db.exec("PRAGMA foreign_keys=OFF");
        db.exec(
            "CREATE TABLE catalog_old (id TEXT PRIMARY KEY, title TEXT NOT NULL, kind TEXT NOT NULL"
                + " CHECK(kind IN ('skin','border','hat','theme','content','freeze','prize')),"
                + " price INTEGER NOT NULL CHECK(price>=0), stock INTEGER CHECK(stock>=0), adult_only"
                + " INTEGER NOT NULL DEFAULT 0, rules TEXT NOT NULL DEFAULT '', rules_version INTEGER NOT"
                + " NULL DEFAULT 1, sponsor TEXT NOT NULL DEFAULT '', active INTEGER NOT NULL DEFAULT 1,"
                + " value TEXT NOT NULL DEFAULT '')");
        db.exec("DROP TABLE catalog");
        db.exec("ALTER TABLE catalog_old RENAME TO catalog");
        db.exec("PRAGMA foreign_keys=ON");
        db.insert("users", map("id", "u", "email", "u@test.edu", "password_hash", password,
            "school_hash", "school", "school_cipher", cipher, "display_name", "Synthetic student",
            "age_band", "adult", "created", now()));
        db.insert("catalog", map("id", "hat", "title", "Hat", "kind", "hat", "price", 1, "value", "leaf"));
        db.insert("inventory", map("user_id", "u", "item_id", "hat", "acquired", now()));
      }
      try (Db db = new Db(legacy.toString())) {
        db.schema();
        check(
            str(db.one("SELECT sql FROM sqlite_master WHERE name='catalog'"), "sql").contains("'effect'"),
            "DB06 legacy catalog upgraded to allow effect items");
        db.insert("catalog", map("id", "fx", "title", "Confetti", "kind", "effect", "price", 1, "value", "confetti"));
        check(
            db.one("SELECT * FROM inventory WHERE user_id='u' AND item_id='hat'") != null,
            "DB07 owned items survive the catalog upgrade");
        rejected = false;
        try {
          db.insert("inventory", map("user_id", "u", "item_id", "missing", "acquired", now()));
        } catch (Exception e) {
          rejected = true;
        }
        check(rejected, "DB08 inventory foreign key still enforced after upgrade");
      }
    } finally {
      for (String suffix : List.of("", "-wal", "-shm"))
        java.nio.file.Files.deleteIfExists(java.nio.file.Path.of(legacy + suffix));
    }
    check(
        Studio.geminiText(obj("{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"plan\",\"thought\":true},"
            + "{\"text\":\"# Reviewer\"},{\"text\":\"\\n- key idea\"}]}}]}")).equals("# Reviewer\n- key idea"),
        "AI01 Gemini answer text joined without thought summaries");
    String code = "";
    try {
      Studio.geminiText(obj("{\"promptFeedback\":{\"blockReason\":\"SAFETY\"}}"));
    } catch (Fault f) {
      code = f.code;
    }
    check(code.equals("AI_BLOCKED"), "AI02 blocked Gemini answer becomes a clear error, not an empty tool");
    Map<Integer, String> expected = new LinkedHashMap<>();
    expected.put(403, "AI_KEY_REJECTED");
    expected.put(429, "AI_RATE_LIMITED");
    expected.put(404, "AI_MODEL_UNAVAILABLE");
    expected.put(503, "AI_BUSY");
    expected.put(502, "AI_UNAVAILABLE");
    for (var entry : expected.entrySet()) {
      code = "";
      try {
        Studio.requireAiSuccess(entry.getKey(), "{}", "gemini-test");
      } catch (Fault f) {
        code = f.code;
      }
      check(code.equals(entry.getValue()), "AI03 Gemini HTTP " + entry.getKey() + " maps to " + entry.getValue());
    }
    code = "";
    try {
      Studio.requireAiSuccess(400, "{\"error\":{\"details\":[{\"reason\":\"API_KEY_INVALID\"}]}}", "gemini-test");
    } catch (Fault f) {
      code = f.code;
    }
    check(code.equals("AI_KEY_REJECTED"), "AI04 Gemini invalid-key 400 is reported as a rejected key");
    check(
        Studio.unfence("```json\n[{\"front\":\"a\"}]\n```").equals("[{\"front\":\"a\"}]")
            && Studio.unfence("[1]").equals("[1]"),
        "AI05 fenced JSON study tools are unwrapped; plain JSON is untouched");
    System.out.println(passed + " domain/security assertions passed.");
  }
}
