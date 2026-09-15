package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.time.*;
import java.util.*;

final class Auth {
  final Api a;
  final Db d;
  final String dummy = password(token());

  Auth(Api a) {
    this.a = a;
    d = a.db;
    a.add(
        "POST",
        "/api/auth/register",
        "public",
        false,
        "{email,password,school_id,display_name,age_band,consent_ref?}",
        "{message}",
        "VALIDATION,REGISTRATION_UNAVAILABLE,CONSENT_REQUIRED",
        r -> {
          String email = text(r.body, "email", 5, 254).toLowerCase(Locale.ROOT),
              pw = text(r.body, "password", 12, 128),
              school = text(r.body, "school_id", 3, 40),
              name = text(r.body, "display_name", 2, 40),
              age = choice(r.body, "age_band", "minor", "adult");
          require(
              email.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+"),
              422,
              "VALIDATION",
              "Enter a valid email address.");
          require(
              school.matches("[\\p{L}\\p{N} -]{3,40}"),
              422,
              "VALIDATION",
              "School ID may contain letters, digits, spaces and hyphens.");
          // Consent is institution-issued, never inferred from a checkbox or a typed arbitrary
          // reference.
          if (age.equals("minor"))
            require(
                a.demo
                    || Objects.equals(
                            System.getenv("MINOR_CONSENT_CODE"), str(r.body, "consent_ref"))
                        && !str(r.body, "consent_ref").isBlank(),
                403,
                "CONSENT_REQUIRED",
                "Ask the school coordinator for an approved pilot consent code.");
          String sh = hash(Base64.getEncoder().encodeToString(a.key) + normalized(school));
          require(
              d.one("SELECT id FROM users WHERE email=? OR school_hash=?", email, sh) == null,
              409,
              "REGISTRATION_UNAVAILABLE",
              "Unable to register these details. Try signing in or contact your school"
                  + " coordinator.");
          String id = id();
          d.insert(
              "users",
              map(
                  "id",
                  id,
                  "email",
                  email,
                  "password_hash",
                  password(pw),
                  "school_hash",
                  sh,
                  "school_cipher",
                  crypt(school, a.key, true),
                  "display_name",
                  name,
                  "age_band",
                  age,
                  "consent_ref",
                  age.equals("minor") ? "institution-pilot" : "adult-assent",
                  "created",
                  now()));
          d.insert("notification_settings", map("user_id", id));
          verification(id, email, "verify");
          return map("message", "Account created. Check your email to verify it.");
        });
    a.add(
        "POST",
        "/api/auth/login",
        "public",
        false,
        "{email,password,device?}",
        "{token,expires,user}",
        "INVALID_CREDENTIALS",
        r -> {
          Map<String, Object> u =
              d.one(
                  "SELECT * FROM users WHERE email=? AND delete_after IS NULL AND suspended=0",
                  str(r.body, "email"));
          boolean valid =
              verify(text(r.body, "password", 1, 128), u == null ? dummy : str(u, "password_hash"));
          require(
              u != null && valid, 401, "INVALID_CREDENTIALS", "Email or password is incorrect.");
          String t = token();
          double expires = now() + 86400 * 7;
          d.insert(
              "auth_sessions",
              map(
                  "token_hash",
                  hash(t),
                  "user_id",
                  u.get("id"),
                  "device",
                  Objects.toString(r.body.getOrDefault("device", "Browser"))
                      .substring(
                          0,
                          Math.min(
                              80,
                              Objects.toString(r.body.getOrDefault("device", "Browser")).length())),
                  "created",
                  now(),
                  "expires",
                  expires,
                  "recent_auth",
                  now()));
          return map("token", t, "expires", expires, "user", profile(u), "login_streak", loginStreak(u));
        });
    a.add(
        "POST",
        "/api/auth/verify",
        "public",
        false,
        "{token}",
        "{message}",
        "TOKEN_INVALID",
        r -> {
          Map<String, Object> t = validToken(r.body, "verify");
          d.exec("UPDATE users SET verified=1 WHERE id=?", t.get("user_id"));
          d.exec("DELETE FROM auth_tokens WHERE token_hash=?", t.get("token_hash"));
          return map("message", "Email verified.");
        });
    a.add(
        "POST",
        "/api/auth/reset-request",
        "public",
        false,
        "{email}",
        "{message}",
        "RATE_LIMITED",
        r -> {
          Map<String, Object> u =
              d.one(
                  "SELECT * FROM users WHERE email=? AND delete_after IS NULL",
                  str(r.body, "email"));
          if (u != null) verification(str(u, "id"), str(u, "email"), "reset");
          return map(
              "message",
              "If an active account matches, recovery instructions will arrive. If your inbox is"
                  + " unavailable, contact the school coordinator for institutional identity"
                  + " verification.");
        });
    a.add(
        "POST",
        "/api/auth/reset",
        "public",
        false,
        "{token,password}",
        "{message}",
        "TOKEN_INVALID,VALIDATION",
        r -> {
          Map<String, Object> t = validToken(r.body, "reset");
          d.exec(
              "UPDATE users SET password_hash=? WHERE id=?",
              password(text(r.body, "password", 12, 128)),
              t.get("user_id"));
          d.exec("DELETE FROM auth_sessions WHERE user_id=?", t.get("user_id"));
          d.exec("DELETE FROM auth_tokens WHERE user_id=?", t.get("user_id"));
          return map("message", "Password changed. Sign in on each device.");
        });
    a.add(
        "POST",
        "/api/auth/resend",
        "student",
        true,
        "{}",
        "{message}",
        "RATE_LIMITED",
        r -> {
          verification(r.uid(), str(r.user, "email"), "verify");
          return map("message", "Verification email queued.");
        });
    a.add(
        "POST",
        "/api/auth/logout",
        "student",
        false,
        "{}",
        "{ok}",
        "",
        r -> {
          d.exec("DELETE FROM auth_sessions WHERE token_hash=?", hash(r.token));
          return map("ok", true);
        });
    a.add("GET", "/api/me", "student", false, "—", "{user}", "", r -> map("user", profile(r.user)));
    a.add(
        "PUT",
        "/api/me",
        "student",
        true,
        "{version,display_name,course,year,subjects[],timezone,daily_goal,weekly_goal,competition}",
        "{user}",
        "VERSION_CONFLICT,VALIDATION",
        r -> {
          require(
              integer(r.body, "version", 1, Integer.MAX_VALUE, 0) == num(r.user, "version"),
              409,
              "VERSION_CONFLICT",
              "Profile changed on another device. Reload before saving.");
          String tz = text(r.body, "timezone", 1, 80);
          try {
            ZoneId.of(tz);
          } catch (Exception e) {
            throw new Fault(422, "VALIDATION", "Use a valid IANA timezone.");
          }
          Object subjects = r.body.getOrDefault("subjects", List.of());
          require(
              subjects instanceof List<?> && ((List<?>) subjects).size() <= 20,
              422,
              "VALIDATION",
              "Choose at most 20 subjects.");
          d.exec(
              "UPDATE users SET"
                  + " display_name=?,course=?,year=?,subjects=?,timezone=?,daily_goal=?,weekly_goal=?,competition=?,version=version+1"
                  + " WHERE id=?",
              text(r.body, "display_name", 2, 40),
              text(r.body, "course", 0, 80),
              integer(r.body, "year", 1, 6, 1),
              json(subjects),
              tz,
              integer(r.body, "daily_goal", 5, 180, 25),
              integer(r.body, "weekly_goal", 5, 1260, 125),
              yes(r.body, "competition") ? 1 : 0,
              r.uid());
          if (!yes(r.body, "competition")) {
            d.exec("DELETE FROM duel_queue WHERE user_id=?", r.uid());
            d.exec("UPDATE notification_settings SET challenges=0 WHERE user_id=?", r.uid());
            d.exec(
                "UPDATE duels SET state='void',result='Competition turned off' WHERE state='active'"
                    + " AND (a_id=? OR b_id=?)",
                r.uid(),
                r.uid());
          }
          return map("user", profile(d.need("SELECT * FROM users WHERE id=?", r.uid())));
        });
    a.add(
        "GET",
        "/api/me/devices",
        "student",
        false,
        "—",
        "{items:[{id,device,created,expires,current}]}",
        "",
        r -> {
          List<Map<String, Object>> out =
              d.all(
                  "SELECT token_hash AS id,device,created,expires FROM auth_sessions WHERE"
                      + " user_id=?",
                  r.uid());
          for (Map<String, Object> s : out) s.put("current", str(s, "id").equals(hash(r.token)));
          return map("items", out);
        });
    a.add(
        "DELETE",
        "/api/me/devices/{id}",
        "student",
        true,
        "{}",
        "{ok}",
        "",
        r -> {
          d.exec("DELETE FROM auth_sessions WHERE token_hash=? AND user_id=?", r.p(), r.uid());
          return map("ok", true);
        });
    a.add(
        "GET",
        "/api/me/export",
        "student",
        false,
        "—",
        "{profile,sessions,attempts,answers,reviews,decks,cards,materials,memberships,inventory,ledger,claims,evidence,settings,badges,streak_days,login_days,studio_sources,studio_artifacts}",
        "REAUTH_REQUIRED",
        r -> {
          r.recent();
          Map<String, Object> out = map("profile", profile(r.user));
          out.put("school_id", crypt(str(r.user, "school_cipher"), a.key, false));
          for (String table :
              List.of(
                  "study_sessions",
                  "attempts",
                  "review_events",
                  "memberships",
                  "inventory",
                  "ledger",
                  "claims",
                  "evidence",
                  "notification_settings",
                  "badges",
                  "streak_days",
                  "login_days"))
            out.put(table, d.all("SELECT * FROM " + table + " WHERE user_id=?", r.uid()));
          for (String table : List.of("decks", "materials", "studio_sources", "studio_artifacts"))
            out.put(table, d.all("SELECT * FROM " + table + " WHERE owner_id=?", r.uid()));
          out.put(
              "cards",
              d.all(
                  "SELECT c.* FROM cards c JOIN decks x ON c.deck_id=x.id WHERE x.owner_id=?",
                  r.uid()));
          out.put(
              "answers",
              d.all(
                  "SELECT a.* FROM answers a JOIN attempts t ON a.attempt_id=t.id WHERE"
                      + " t.user_id=?",
                  r.uid()));
          for (Map<String, Object> s : (List<Map<String, Object>>) out.get("study_sessions")) {
            s.put("notes", crypt(str(s, "notes_cipher"), a.key, false));
            s.remove("notes_cipher");
          }
          d.audit(r.uid(), "data_export", r.uid(), "Student requested export");
          return out;
        });
    a.add(
        "POST",
        "/api/me/delete",
        "student",
        false,
        "{confirm:'DELETE'}",
        "{message,delete_after}",
        "REAUTH_REQUIRED,ACTIVE_ROOM,PENDING_CLAIM",
        r -> {
          r.recent();
          require(
              str(r.body, "confirm").equals("DELETE"),
              422,
              "VALIDATION",
              "Type DELETE to confirm.");
          require(
              d.scalar("SELECT count(*) FROM rooms WHERE owner_id=? AND state='active'", r.uid())
                  == 0,
              409,
              "ACTIVE_ROOM",
              "Transfer ownership or disband your active rooms first.");
          require(
              d.scalar(
                      "SELECT count(*) FROM claims WHERE user_id=? AND state IN"
                          + " ('pending','approved')",
                      r.uid())
                  == 0,
              409,
              "PENDING_CLAIM",
              "Resolve or cancel pending prize claims first.");
          double after = now() + 30 * 86400;
          d.exec("UPDATE users SET delete_after=? WHERE id=?", after, r.uid());
          d.exec("DELETE FROM auth_sessions WHERE user_id=?", r.uid());
          d.exec("DELETE FROM duel_queue WHERE user_id=?", r.uid());
          d.exec(
              "UPDATE duels SET state='void',result='Account closed' WHERE state='active' AND"
                  + " (a_id=? OR b_id=?)",
              r.uid(),
              r.uid());
          d.audit(r.uid(), "deletion_requested", r.uid(), "Student confirmed deletion");
          return map(
              "message",
              "Access revoked. Contact the institution within 30 days to withdraw the request."
                  + " Currency has no cash value.",
              "delete_after",
              after);
        });
  }

  Map<String, Object> loginStreak(Map<String, Object> u) {
    ZoneId zone;
    try {
      zone = ZoneId.of(str(u, "timezone"));
    } catch (Exception ignored) {
      zone = ZoneId.of("Asia/Manila");
    }
    LocalDate today = LocalDate.now(zone);
    int inserted =
        d.exec(
            "INSERT OR IGNORE INTO login_days(user_id,day,created) VALUES(?,?,?)",
            u.get("id"),
            today.toString(),
            now());
    Set<LocalDate> days = new HashSet<>();
    for (Map<String, Object> row :
        d.all("SELECT day FROM login_days WHERE user_id=? ORDER BY day", u.get("id")))
      days.add(LocalDate.parse(str(row, "day")));
    int current = 0;
    for (LocalDate day = today; days.contains(day); day = day.minusDays(1)) current++;
    int best = 0, run = 0;
    LocalDate previous = null;
    List<LocalDate> ordered = new ArrayList<>(days);
    Collections.sort(ordered);
    for (LocalDate day : ordered) {
      run = previous != null && day.equals(previous.plusDays(1)) ? run + 1 : 1;
      best = Math.max(best, run);
      previous = day;
    }
    List<Integer> milestones = List.of(3, 7, 14, 30);
    List<Integer> fresh = new ArrayList<>();
    if (inserted == 1 && milestones.contains(current)) {
      fresh.add(current);
      d.exec(
          "INSERT OR IGNORE INTO badges(user_id,badge,earned) VALUES(?,?,?)",
          u.get("id"),
          current + "-day login streak",
          now());
    }
    List<String> unlocks = new ArrayList<>();
    if (best >= 3) unlocks.add("sparkles");
    if (best >= 7) unlocks.add("star-trail");
    if (best >= 14) unlocks.add("study-crown");
    if (best >= 30) unlocks.add("super-run");
    return map(
        "current", current,
        "best", best,
        "recorded_today", inserted == 1,
        "new_milestones", fresh,
        "unlocks", unlocks);
  }

  Map<String, Object> profile(Map<String, Object> u) {
    Map<String, Object> out = new LinkedHashMap<>(u);
    for (String k : List.of("password_hash", "school_hash", "school_cipher", "consent_ref"))
      out.remove(k);
    out.put("subjects", list(str(u, "subjects")));
    return out;
  }

  void verification(String uid, String email, String purpose) {
    d.rate("mail:" + uid, 3, 300);
    String t = token();
    d.exec("DELETE FROM auth_tokens WHERE user_id=? AND purpose=?", uid, purpose);
    d.insert(
        "auth_tokens",
        map(
            "token_hash",
            hash(t),
            "user_id",
            uid,
            "purpose",
            purpose,
            "expires",
            now() + (purpose.equals("verify") ? 86400 : 1800)));
    String body =
        "Study Arena: "
            + a.origin
            + "/#"
            + purpose
            + "?token="
            + t
            + "\nIf you did not request this, ignore it.";
    d.insert(
        "outbox",
        map(
            "id",
            id(),
            "user_id",
            uid,
            "recipient_cipher",
            crypt(email, a.key, true),
            "subject",
            "Study Arena " + purpose,
            "body_cipher",
            crypt(body, a.key, true),
            "created",
            now()));
  }

  Map<String, Object> validToken(Map<String, Object> b, String purpose) {
    Map<String, Object> t =
        d.one(
            "SELECT * FROM auth_tokens WHERE token_hash=? AND purpose=? AND expires>?",
            hash(text(b, "token", 20, 100)),
            purpose,
            now());
    require(t != null, 400, "TOKEN_INVALID", "This link expired or has already been used.");
    return t;
  }
}
