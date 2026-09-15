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
    System.out.println(passed + " domain/security assertions passed.");
  }
}
