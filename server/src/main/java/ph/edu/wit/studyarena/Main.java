package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import com.sun.net.httpserver.HttpServer;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

public final class Main {
  public static void main(String[] args) throws Exception {
    boolean demo = Arrays.asList(args).contains("--demo");
    int port = Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));
    String origin = System.getenv().getOrDefault("APP_ORIGIN", "http://localhost:" + port);
    Path data = Path.of(System.getenv().getOrDefault("DATA_DIR", "data")),
        web = Path.of(System.getenv().getOrDefault("WEB_DIR", "web"));
    Files.createDirectories(data.resolve("files"));
    String configured = System.getenv("DATA_KEY");
    byte[] key;
    if (configured != null) {
      key = Base64.getDecoder().decode(configured);
      require(key.length == 32, 500, "CONFIGURATION", "DATA_KEY must decode to 32 bytes.");
    } else {
      require(demo, 500, "CONFIGURATION", "Set DATA_KEY and APP_ORIGIN before production startup.");
      Path p = data.resolve("demo.key");
      if (!Files.exists(p)) {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        Files.write(p, bytes);
        try {
          Files.setPosixFilePermissions(
              p,
              Set.of(
                  java.nio.file.attribute.PosixFilePermission.OWNER_READ,
                  java.nio.file.attribute.PosixFilePermission.OWNER_WRITE));
        } catch (UnsupportedOperationException ignored) {
        }
      }
      key = Files.readAllBytes(p);
    }
    require(
        demo || origin.startsWith("https://"),
        500,
        "CONFIGURATION",
        "Production requires an HTTPS APP_ORIGIN behind a reverse proxy.");
    Db db = new Db(data.resolve("arena.db").toString());
    db.schema();
    Api api = new Api(db, key, demo, origin, web, data.resolve("files"));
    seed(api);
    Auth auth = new Auth(api);
    Content content = new Content(api);
    Economy economy = new Economy(api);
    new Study(api, content, economy);
    new Studio(api);
    new Dungeon(api);
    Social social = new Social(api, content, economy);
    new Admin(api, economy, content);
    api.add(
        "POST",
        "/api/push/register",
        "student",
        true,
        "{token,platform:android}",
        "{ok}",
        "VALIDATION",
        r -> {
          String token = text(r.body, "token", 20, 4096);
          choice(r.body, "platform", "android");
          db.exec(
              "INSERT INTO push_tokens VALUES(?,?,?,?) ON CONFLICT(token) DO UPDATE SET"
                  + " user_id=excluded.user_id,updated=excluded.updated",
              token,
              r.uid(),
              "android",
              now());
          return map("ok", true);
        });
    api.add(
        "GET",
        "/api/health",
        "public",
        false,
        "—",
        "{status,demo,server_time}",
        "",
        r -> map("status", "ok", "demo", demo, "server_time", now()));
    api.add(
        "GET",
        "/api/config",
        "public",
        false,
        "—",
        "{flags,earning_rules,support,api_origin}",
        "",
        r ->
            map(
                "flags",
                db.all("SELECT * FROM flags"),
                "earning_rules",
                map(
                    "study",
                    "1 XP/minute + 1 coin/5 minutes; minimum 5 minutes",
                    "reviews",
                    "2 XP + 1 coin per due card, once/24h",
                    "quizzes",
                    "5 XP + 2 coins per new correct-answer improvement",
                    "daily_caps",
                    "500 XP and 100 earned coins per rolling 24h",
                    "levels",
                    "100 XP per level; maximum level 50; solo study unlocks every level"),
                "support",
                "Contact your school guidance office or a trusted person. For immediate danger in"
                    + " the Philippines, call 911.",
                "api_origin",
                origin));
    api.add(
        "GET",
        "/api/contracts",
        "public",
        false,
        "—",
        "{endpoints:[EndpointContract]}",
        "",
        r -> map("endpoints", api.contracts()));
    if (demo)
      api.add(
          "GET",
          "/api/demo/mail",
          "public",
          false,
          "?email=synthetic address",
          "{items:[{subject,body}]}",
          "",
          r -> {
            List<Map<String, Object>> out = new ArrayList<>();
            for (Map<String, Object> mail :
                db.all(
                    "SELECT o.* FROM outbox o JOIN users u ON o.user_id=u.id WHERE u.email=? ORDER"
                        + " BY created DESC LIMIT 5",
                    r.q("email")))
              out.add(
                  map(
                      "subject",
                      mail.get("subject"),
                      "body",
                      crypt(str(mail, "body_cipher"), key, false)));
            return map("items", out);
          });
    if (Arrays.asList(args).contains("--contracts")) {
      System.out.println(json(map("endpoints", api.contracts())));
      db.close();
      return;
    }
    // A bounded pool limits both JVM memory pressure and slow-client resource use.
    HttpServer server =
        HttpServer.create(
            new InetSocketAddress(System.getenv().getOrDefault("BIND", "127.0.0.1"), port), 64);
    ThreadPoolExecutor pool =
        new ThreadPoolExecutor(
            4,
            16,
            30,
            TimeUnit.SECONDS,
            new ArrayBlockingQueue<>(64),
            new ThreadPoolExecutor.CallerRunsPolicy());
    server.setExecutor(pool);
    server.createContext("/", api::handle);
    ScheduledExecutorService worker = Executors.newSingleThreadScheduledExecutor();
    worker.scheduleWithFixedDelay(
        () -> {
          try {
            synchronized (db) {
              db.c.setAutoCommit(false);
              try {
                maintenance(api, economy, social);
                db.c.commit();
              } catch (Exception ex) {
                db.c.rollback();
                throw ex;
              } finally {
                db.c.setAutoCommit(true);
              }
            }
            if (!demo) {
              Mail.deliver(api);
              Push.deliver(api);
            }
          } catch (Exception ex) {
            System.err.println("maintenance_error=" + ex.getClass().getSimpleName());
          }
        },
        30,
        30,
        TimeUnit.SECONDS);
    Runtime.getRuntime()
        .addShutdownHook(
            new Thread(
                () -> {
                  server.stop(2);
                  worker.shutdown();
                  pool.shutdown();
                  try {
                    db.close();
                  } catch (Exception ignored) {
                  }
                }));
    server.start();
    System.out.println("Study Arena ready at " + origin + (demo ? " — SYNTHETIC DEMO MODE" : ""));
  }

  static void seed(Api a) {
    Db d = a.db;
    for (String name : List.of("rooms", "competition", "levels", "prizes"))
      d.exec(
          "INSERT OR IGNORE INTO flags VALUES(?,?)",
          name,
          (name.equals("rooms") || name.equals("competition")) ? 1 : 0);
    if (d.one("SELECT id FROM users WHERE id='deleted-user'") == null)
      d.insert(
          "users",
          map(
              "id",
              "deleted-user",
              "email",
              "deleted@invalid.test",
              "password_hash",
              password(token()),
              "school_hash",
              hash("tombstone"),
              "school_cipher",
              crypt("", a.key, true),
              "display_name",
              "Former student",
              "age_band",
              "adult",
              "created",
              now(),
              "suspended",
              1));
    for (String[] t :
        List.of(
            new String[] {"algebra", "Mathematics", "Linear equations", "STEM"},
            new String[] {
              "calculus", "Engineering Mathematics", "Differentiation", "Civil Engineering"
            },
            new String[] {
              "computing", "Computer Science", "Binary and algorithms", "Information Technology"
            })) d.exec("INSERT OR IGNORE INTO topics VALUES(?,?,?,?)", (Object[]) t);
    if (d.scalar("SELECT count(*) FROM decks") == 0) {
      List<List<String>> fronts =
          List.of(
              List.of(
                  "What operation solves 3x = 12?",
                  "What is the slope in y = 2x + 5?",
                  "Solve x + 7 = 10."),
              List.of(
                  "Differentiate x².",
                  "What is the derivative of a constant?",
                  "What does a derivative measure?"),
              List.of(
                  "What is binary 101 in decimal?",
                  "What is an algorithm?",
                  "What is the time complexity of scanning n items once?"));
      List<List<String>> backs =
          List.of(
              List.of(
                  "Divide both sides by 3; x = 4.",
                  "2. In y = mx + b, m is the slope.",
                  "Subtract 7 from both sides; x = 3."),
              List.of(
                  "2x, using the power rule.",
                  "Zero: a constant does not change.",
                  "The instantaneous rate of change of a function."),
              List.of(
                  "5: 1×4 + 0×2 + 1×1.",
                  "A finite, ordered sequence of steps for solving a problem.",
                  "O(n), linear time."));
      int n = 0;
      for (String topic : List.of("algebra", "calculus", "computing")) {
        String deck = "starter-" + topic, quiz = "quiz-" + topic;
        d.insert(
            "decks",
            map(
                "id",
                deck,
                "title",
                topic.equals("calculus")
                    ? "Engineering essentials"
                    : topic.equals("computing")
                        ? "A gentle start to computing"
                        : "Algebra foundations",
                "topic_id",
                topic,
                "visibility",
                "public",
                "status",
                "approved",
                "updated",
                now(),
                "source",
                "Original Study Arena instructional examples",
                "license",
                "CC BY 4.0"));
        d.insert(
            "quizzes",
            map(
                "id",
                quiz,
                "title",
                topic + " · quick practice",
                "topic_id",
                topic,
                "status",
                "approved",
                "duration",
                180,
                "updated",
                now(),
                "source",
                "Original Study Arena instructional examples",
                "license",
                "CC BY 4.0"));
        for (int i = 0; i < 3; i++)
          d.insert(
              "cards",
              map(
                  "id",
                  deck + "-" + i,
                  "deck_id",
                  deck,
                  "front",
                  fronts.get(n).get(i),
                  "back",
                  backs.get(n).get(i),
                  "fingerprint",
                  hash(fronts.get(n).get(i)),
                  "position",
                  i));
        List<Map<String, Object>> qs;
        if (topic.equals("algebra"))
          qs =
              List.of(
                  question(
                      "mcq",
                      "Solve 3x = 12.",
                      List.of("2", "3", "4", "6"),
                      List.of("4"),
                      "Divide both sides by 3: x = 12 ÷ 3 = 4."),
                  question(
                      "boolean",
                      "The slope of y = 2x + 5 is 5.",
                      List.of("True", "False"),
                      List.of("False"),
                      "The coefficient of x is the slope, so it is 2."),
                  question(
                      "identification",
                      "Solve x + 7 = 10. Enter x.",
                      List.of(),
                      List.of("3"),
                      "Subtract 7 from both sides: x = 3."));
        else if (topic.equals("calculus"))
          qs =
              List.of(
                  question(
                      "mcq",
                      "What is the derivative of x²?",
                      List.of("x", "2x", "2", "x³"),
                      List.of("2x"),
                      "The power rule gives d(xⁿ)/dx = nxⁿ⁻¹."),
                  question(
                      "boolean",
                      "The derivative of a constant is zero.",
                      List.of("True", "False"),
                      List.of("True"),
                      "A constant has no change, so its rate of change is zero."),
                  question(
                      "identification",
                      "For f(x)=3x², find f′(2).",
                      List.of(),
                      List.of("12"),
                      "f′(x)=6x, and 6×2=12."));
        else
          qs =
              List.of(
                  question(
                      "mcq",
                      "Convert binary 101 to decimal.",
                      List.of("3", "4", "5", "6"),
                      List.of("5"),
                      "The place values are 4, 2 and 1: 4+0+1=5."),
                  question(
                      "boolean",
                      "An algorithm is a finite sequence of steps.",
                      List.of("True", "False"),
                      List.of("True"),
                      "Algorithms specify ordered steps that terminate for their intended inputs."),
                  question(
                      "identification",
                      "A single loop over n items has which Big-O complexity?",
                      List.of(),
                      List.of("O(n)", "linear"),
                      "Work grows proportionally with n, so the complexity is O(n)."));
        int i = 0;
        for (Map<String, Object> q : qs)
          d.insert(
              "questions",
              map(
                  "id",
                  quiz + "-" + (i++),
                  "quiz_id",
                  quiz,
                  "kind",
                  q.get("kind"),
                  "prompt",
                  q.get("prompt"),
                  "options",
                  json(q.get("options")),
                  "accepted",
                  json(q.get("accepted")),
                  "explanation",
                  q.get("explanation"),
                  "topic_id",
                  topic,
                  "position",
                  i));
        String body = "# " + topic + " study notes\n\n";
        for (i = 0; i < 3; i++) body += fronts.get(n).get(i) + "\n" + backs.get(n).get(i) + "\n\n";
        body +=
            "Practice: write one example of your own, then explain each step aloud. These short"
                + " original notes are starter content, not a textbook or verified course"
                + " syllabus.";
        d.insert(
            "materials",
            map(
                "id",
                "notes-" + topic,
                "title",
                topic.equals("calculus")
                    ? "Engineering reference · derivative rules"
                    : topic + " reference notes",
                "topic_id",
                topic,
                "year",
                1,
                "file_type",
                "text",
                "body",
                body,
                "bytes",
                body.getBytes(StandardCharsets.UTF_8).length,
                "sha256",
                hash(body),
                "source",
                "Original Study Arena instructional notes; instructor review recommended",
                "license",
                "CC BY 4.0",
                "status",
                "approved",
                "created",
                now()));
        n++;
      }
    }
    if (d.scalar("SELECT count(*) FROM catalog") == 0) {
      for (Object[] row :
          List.of(
              new Object[] {"hat-leaf", "Little leaf hat", "hat", 10, "leaf"},
              new Object[] {"border-sage", "Sage profile border", "border", 15, "sage"},
              new Object[] {"theme-night", "Moonlit theme", "theme", 20, "dark"},
              new Object[] {"skin-fox", "Study fox", "skin", 25, "fox"},
              new Object[] {"streak-freeze", "Streak freeze", "freeze", 30, "freeze"}))
        d.insert(
            "catalog",
            map("id", row[0], "title", row[1], "kind", row[2], "price", row[3], "value", row[4]));
      d.insert(
          "catalog",
          map(
              "id",
              "school-kit",
              "title",
              "School study kit · pilot",
              "kind",
              "prize",
              "price",
              50,
              "stock",
              5,
              "adult_only",
              1,
              "rules",
              "DEMO RULES v1. No purchase or payment required. One fixed study kit per eligible"
                  + " verified adult student. No cash, wagering, random draw or paid entry. School"
                  + " coordinator verifies age, enrollment, study eligibility and available funding"
                  + " before approval. Manual collection with receipt. Submit appeals to the school"
                  + " coordinator. Demo offers have no real-world value. Replace these rules and"
                  + " sponsor details before a funded pilot.",
              "sponsor",
              "Demonstration only — no committed school funding",
              "value",
              "physical study kit"));
    }
    d.exec(
        "INSERT OR IGNORE INTO seasons VALUES(?,?,?,?)",
        "pilot",
        "Pilot season",
        now() - 86400,
        now() + 90 * 86400);
    if (a.demo) {
      for (String role : List.of("student", "teacher", "admin")) {
        String id = "demo-" + role;
        if (d.one("SELECT id FROM users WHERE id=?", id) == null)
          d.insert(
              "users",
              map(
                  "id",
                  id,
                  "email",
                  role + "@study.test",
                  "password_hash",
                  password("StudyArena!2026"),
                  "school_hash",
                  hash(id),
                  "school_cipher",
                  crypt("DEMO-" + role, a.key, true),
                  "display_name",
                  role.equals("student")
                      ? "Alex"
                      : role.equals("teacher") ? "Teacher Jamie" : "Admin Morgan",
                  "age_band",
                  "adult",
                  "role",
                  role,
                  "verified",
                  1,
                  "created",
                  now()));
        d.exec("INSERT OR IGNORE INTO notification_settings(user_id) VALUES(?)", id);
      }
      d.exec("INSERT OR IGNORE INTO cohorts VALUES('pilot','Synthetic pilot cohort')");
      d.exec("INSERT OR IGNORE INTO cohort_members VALUES('pilot','demo-student')");
      d.exec("INSERT OR IGNORE INTO cohort_moderators VALUES('pilot','demo-teacher')");
    }
    String adminEmail = System.getenv("BOOTSTRAP_ADMIN_EMAIL"),
        adminPassword = System.getenv("BOOTSTRAP_ADMIN_PASSWORD");
    if (!a.demo
        && d.scalar("SELECT count(*) FROM users WHERE role='admin'") == 0
        && adminEmail != null
        && adminPassword != null) {
      require(
          adminPassword.length() >= 16,
          500,
          "CONFIGURATION",
          "Administrator password must be at least 16 characters.");
      String id = id();
      d.insert(
          "users",
          map(
              "id",
              id,
              "email",
              adminEmail,
              "password_hash",
              password(adminPassword),
              "school_hash",
              hash(id),
              "school_cipher",
              crypt("Institution administrator", a.key, true),
              "display_name",
              "School administrator",
              "age_band",
              "adult",
              "role",
              "admin",
              "verified",
              1,
              "created",
              now()));
      d.insert("notification_settings", map("user_id", id));
    }
  }

  static Map<String, Object> question(
      String kind, String prompt, List<String> options, List<String> answers, String explanation) {
    return map(
        "kind",
        kind,
        "prompt",
        prompt,
        "options",
        options,
        "accepted",
        answers,
        "explanation",
        explanation);
  }

  static void maintenance(Api a, Economy e, Social social) {
    Db d = a.db;
    double t = now();
    d.exec("DELETE FROM auth_sessions WHERE expires<?", t);
    d.exec("DELETE FROM auth_tokens WHERE expires<?", t);
    d.exec("DELETE FROM rate_limits WHERE window<?", t - 86400);
    d.exec("DELETE FROM duel_queue WHERE heartbeat<?", t - 60);
    for (Map<String, Object> duel : d.all("SELECT * FROM duels WHERE state='active'"))
      social.settle(duel);
    for (Map<String, Object> room :
        d.all("SELECT * FROM rooms WHERE state='active' AND last_active<?", t - 29 * 86400)) {
      if (num(room, "warned") == 0) {
        e.notify(
            str(room, "owner_id"),
            "invitations",
            "Your inactive room will be archived in one day.");
        d.exec("UPDATE rooms SET warned=1 WHERE id=?", room.get("id"));
      }
      if (num(room, "last_active") < t - 30 * 86400)
        d.exec(
            "UPDATE rooms SET state='archived',archived=?,timer_end=NULL WHERE id=?",
            t,
            room.get("id"));
    }
    d.exec(
        "DELETE FROM messages WHERE created<? AND room_id IN (SELECT id FROM rooms WHERE"
            + " state='archived')",
        t - 365 * 86400);
    d.exec("DELETE FROM notifications WHERE created<?", t - 90 * 86400);
    d.exec("DELETE FROM outbox WHERE delivered IS NOT NULL AND delivered<?", t - 86400);
    d.exec("DELETE FROM risk_events WHERE resolved=1 AND created<?", t - 365 * 86400);
    for (Map<String, Object> user :
        d.all("SELECT id FROM users WHERE delete_after IS NOT NULL AND delete_after<?", t)) {
      String uid = str(user, "id");
      for (Map<String, Object> room : d.all("SELECT * FROM rooms WHERE owner_id=?", uid)) {
        Map<String, Object> heir =
            d.one(
                "SELECT m.user_id FROM memberships m JOIN users u ON m.user_id=u.id WHERE"
                    + " m.room_id=? AND m.user_id!=? AND u.delete_after IS NULL AND u.suspended=0"
                    + " ORDER BY m.joined LIMIT 1",
                room.get("id"),
                uid);
        d.exec(
            "UPDATE rooms SET owner_id=?,state=? WHERE id=?",
            heir == null ? "deleted-user" : heir.get("user_id"),
            heir == null ? "archived" : room.get("state"),
            room.get("id"));
      }
      d.exec("DELETE FROM duel_answers WHERE user_id=?", uid);
      d.exec("UPDATE duels SET a_id='deleted-user' WHERE a_id=?", uid);
      d.exec("UPDATE duels SET b_id='deleted-user' WHERE b_id=?", uid);
      for (Map<String, Object> material :
          d.all("SELECT file_key FROM materials WHERE owner_id=?", uid))
        if (material.get("file_key") != null)
          try {
            Files.deleteIfExists(a.files.resolve(str(material, "file_key")));
          } catch (Exception ex) {
            throw new IllegalStateException(ex);
          }
      for (Map<String, Object> source :
          d.all("SELECT id,file_key FROM studio_sources WHERE owner_id=?", uid))
        try {
          if (source.get("file_key") != null)
            Files.deleteIfExists(a.files.resolve(str(source, "file_key")));
          Files.deleteIfExists(a.files.resolve("studio-" + str(source, "id") + ".partial"));
        } catch (Exception ex) {
          throw new IllegalStateException(ex);
        }
      d.audit(
          null,
          "deletion_completed",
          hash(uid),
          "30-day recovery window elapsed; primary identity erased");
      d.exec("DELETE FROM users WHERE id=?", uid);
    }
  }
}
