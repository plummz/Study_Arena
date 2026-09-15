package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.util.*;

final class Admin {
  final Api a;
  final Db d;
  final Economy e;

  Admin(Api a, Economy e, Content content) {
    this.a = a;
    d = a.db;
    this.e = e;
    a.add(
        "POST",
        "/api/reports",
        "student",
        true,
        "{kind,target_id,reason}",
        "{report}",
        "NOT_FOUND,RATE_LIMITED",
        r -> {
          d.rate("reports:" + r.uid(), 5, 3600);
          String
              kind = choice(r.body, "kind", "deck", "quiz", "material", "message", "user", "duel"),
              target = text(r.body, "target_id", 1, 80),
              table =
                  switch (kind) {
                    case "deck" -> "decks";
                    case "quiz" -> "quizzes";
                    case "material" -> "materials";
                    case "message" -> "messages";
                    case "duel" -> "duels";
                    default -> "users";
                  };
          Map<String, Object> object = d.need("SELECT * FROM " + table + " WHERE id=?", target);
          if (kind.equals("deck")) content.deck(target, r.uid());
          if (kind.equals("quiz")) content.quiz(target, r.uid());
          if (kind.equals("material")) content.material(target, r.uid());
          if (kind.equals("duel"))
            require(
                str(object, "a_id").equals(r.uid()) || str(object, "b_id").equals(r.uid()),
                404,
                "NOT_FOUND",
                "Duel unavailable.");
          String evidence =
              switch (kind) {
                case "message" -> str(object, "body");
                case "user" -> str(object, "display_name");
                default -> str(object, "title");
              };
          if (kind.equals("message"))
            d.need(
                "SELECT * FROM memberships WHERE room_id=? AND user_id=?",
                object.get("room_id"),
                r.uid());
          String id = id();
          d.insert(
              "reports",
              map(
                  "id",
                  id,
                  "reporter",
                  r.uid(),
                  "kind",
                  kind,
                  "target_id",
                  target,
                  "reason",
                  text(r.body, "reason", 5, 2000),
                  "evidence",
                  evidence,
                  "created",
                  now()));
          return map("report", d.need("SELECT id,state,created FROM reports WHERE id=?", id));
        });
    a.add(
        "GET",
        "/api/reports",
        "student",
        false,
        "—",
        "{items:[own reports]}",
        "",
        r ->
            map(
                "items",
                d.all(
                    "SELECT id,kind,target_id,reason,state,created,action FROM reports WHERE"
                        + " reporter=? ORDER BY created DESC LIMIT 100",
                    r.uid())));
    a.add(
        "GET",
        "/api/admin",
        "moderator",
        false,
        "—",
        "{content_queue,reports,aggregate,flags?,users?,claims?,catalog?,ledger?,audit?,risk?}",
        "FORBIDDEN",
        r -> {
          boolean admin = str(r.user, "role").equals("admin");
          List<Object> queue = new ArrayList<>();
          for (String table : List.of("decks", "quizzes", "materials")) {
            List<Map<String, Object>> entries =
                d.all(
                    "SELECT id,title,owner_id,status,source,license FROM "
                        + table
                        + " WHERE status IN ('pending','quarantined') LIMIT 100");
            for (Map<String, Object> row : entries)
              if (admin || assigned(r.uid(), str(row, "owner_id"))) {
                row.put("kind", table);
                queue.add(row);
              }
          }
          List<Map<String, Object>> reports =
              d.all("SELECT * FROM reports WHERE state='pending' LIMIT 100");
          if (!admin) reports.removeIf(row -> !assigned(r.uid(), str(row, "reporter")));
          List<Map<String, Object>> users =
              admin
                  ? d.all(
                      "SELECT id,display_name,role,age_band,verified,suspended,delete_after FROM"
                          + " users WHERE id!='deleted-user' LIMIT 100")
                  : List.of();
          String condition =
              admin
                  ? "1=1"
                  : "user_id IN (SELECT cm.user_id FROM cohort_members cm JOIN cohort_moderators"
                      + " mod ON cm.cohort_id=mod.cohort_id WHERE mod.user_id=?)";
          Object[] args = admin ? new Object[] {} : new Object[] {r.uid()};
          double active =
              d.scalar(
                  "SELECT count(DISTINCT user_id) FROM study_sessions WHERE"
                      + " started>strftime('%s','now')-604800 AND "
                      + condition,
                  args);
          Map<String, Object> aggregate =
              active >= 5
                  ? map(
                      "suppressed",
                      false,
                      "active_students_7d",
                      active,
                      "study_minutes_7d",
                      d.scalar(
                          "SELECT sum(credited) FROM study_sessions WHERE"
                              + " started>strftime('%s','now')-604800 AND "
                              + condition,
                          args),
                      "completed_quizzes_7d",
                      d.scalar(
                          "SELECT count(*) FROM attempts WHERE state='completed' AND"
                              + " started>strftime('%s','now')-604800 AND "
                              + condition,
                          args))
                  : map(
                      "suppressed",
                      true,
                      "message",
                      "At least five active students are needed to display aggregate progress.");
          Map<String, Object> result =
              map("content_queue", queue, "reports", reports, "aggregate", aggregate);
          if (admin) {
            result.put("users", users);
            result.put("flags", d.all("SELECT * FROM flags"));
            result.put(
                "claims",
                d.all(
                    "SELECT c.*,x.title FROM claims c JOIN catalog x ON c.item_id=x.id ORDER BY"
                        + " c.created DESC LIMIT 100"));
            result.put("catalog", d.all("SELECT * FROM catalog"));
            result.put("ledger", d.all("SELECT * FROM ledger ORDER BY created DESC LIMIT 100"));
            result.put("audit", d.all("SELECT * FROM audit ORDER BY rowid DESC LIMIT 100"));
            result.put(
                "risk",
                d.all(
                    "SELECT * FROM risk_events WHERE resolved=0 ORDER BY created DESC LIMIT 100"));
          }
          return result;
        });
    a.add(
        "GET",
        "/api/admin/content/{kind}/{id}",
        "moderator",
        false,
        "—",
        "{item,cards?|questions?}",
        "FORBIDDEN",
        r -> {
          String table = r.params.get(0), id = r.params.get(1);
          require(
              Set.of("decks", "quizzes", "materials").contains(table),
              404,
              "NOT_FOUND",
              "Unknown content type.");
          Map<String, Object> item = d.need("SELECT * FROM " + table + " WHERE id=?", id);
          allow(r, str(item, "owner_id"));
          Map<String, Object> out = map("item", item);
          if (table.equals("decks"))
            out.put("cards", d.all("SELECT * FROM cards WHERE deck_id=?", id));
          if (table.equals("quizzes"))
            out.put("questions", d.all("SELECT * FROM questions WHERE quiz_id=?", id));
          return out;
        });
    a.add(
        "POST",
        "/api/admin/content/{kind}/{id}",
        "moderator",
        true,
        "{status:'approved'|'quarantined',reason}",
        "{ok}",
        "FORBIDDEN,SELF_APPROVAL,EMPTY_CONTENT",
        r -> {
          r.recent();
          String table = r.params.get(0), id = r.params.get(1);
          require(
              Set.of("decks", "quizzes", "materials").contains(table),
              404,
              "NOT_FOUND",
              "Unknown content type.");
          Map<String, Object> item = d.need("SELECT * FROM " + table + " WHERE id=?", id);
          allow(r, str(item, "owner_id"));
          String status = choice(r.body, "status", "approved", "quarantined"),
              reason = text(r.body, "reason", 5, 2000);
          if (status.equals("approved")) {
            require(
                !str(item, "owner_id").equals(r.uid()),
                403,
                "SELF_APPROVAL",
                "A second moderator must approve your content.");
            if (table.equals("decks"))
              require(
                  d.scalar("SELECT count(*) FROM cards WHERE deck_id=?", id) > 0,
                  409,
                  "EMPTY_CONTENT",
                  "Empty decks cannot be published.");
            if (table.equals("quizzes"))
              require(
                  d.scalar("SELECT count(*) FROM questions WHERE quiz_id=?", id) > 0,
                  409,
                  "EMPTY_CONTENT",
                  "Empty quizzes cannot be published.");
          }
          d.exec("UPDATE " + table + " SET status=? WHERE id=?", status, id);
          if (table.equals("materials"))
            d.exec(
                "UPDATE materials SET verified_by=? WHERE id=?",
                status.equals("approved") ? r.uid() : null,
                id);
          d.audit(r.uid(), "content_" + status, id, reason);
          return map("ok", true);
        });
    a.add(
        "POST",
        "/api/admin/reports/{id}",
        "moderator",
        true,
        "{action:'dismiss'|'hide'|'warn',reason}",
        "{ok}",
        "FORBIDDEN",
        r -> {
          r.recent();
          Map<String, Object> report = d.need("SELECT * FROM reports WHERE id=?", r.p());
          allow(r, str(report, "reporter"));
          String action = choice(r.body, "action", "dismiss", "hide", "warn"),
              reason = text(r.body, "reason", 5, 2000),
              kind = str(report, "kind");
          if (action.equals("hide")) {
            String table =
                switch (kind) {
                  case "deck" -> "decks";
                  case "quiz" -> "quizzes";
                  case "material" -> "materials";
                  case "message" -> "messages";
                  default -> "";
                };
            require(
                !table.isBlank(),
                422,
                "VALIDATION",
                "Use user integrity actions for user or duel reports.");
            Map<String, Object> target =
                d.need("SELECT * FROM " + table + " WHERE id=?", report.get("target_id"));
            allow(r, kind.equals("message") ? str(target, "user_id") : str(target, "owner_id"));
            d.exec(
                "UPDATE "
                    + table
                    + " SET "
                    + (kind.equals("message") ? "hidden=1" : "status='quarantined'")
                    + " WHERE id=?",
                report.get("target_id"));
          }
          d.exec(
              "UPDATE reports SET state=?,action=?,reviewed_by=? WHERE id=?",
              action.equals("dismiss") ? "dismissed" : "resolved",
              action + ": " + reason,
              r.uid(),
              r.p());
          d.audit(r.uid(), "report_" + action, r.p(), reason);
          return map("ok", true);
        });
    a.add(
        "PUT",
        "/api/admin/flags/{id}",
        "admin",
        true,
        "{enabled:boolean,reason}",
        "{flag}",
        "REAUTH_REQUIRED,POLICY_REQUIRED",
        r -> {
          r.recent();
          d.need("SELECT * FROM flags WHERE name=?", r.p());
          String reason = text(r.body, "reason", 5, 2000);
          if (r.p().equals("prizes") && yes(r.body, "enabled"))
            require(
                a.demo || "true".equals(System.getenv("PRIZE_POLICY_APPROVED")),
                403,
                "POLICY_REQUIRED",
                "The school must approve prize rules and safeguarding before activation.");
          d.exec("UPDATE flags SET enabled=? WHERE name=?", yes(r.body, "enabled") ? 1 : 0, r.p());
          if (r.p().equals("competition") && !yes(r.body, "enabled")) {
            d.exec("DELETE FROM duel_queue");
            d.exec(
                "UPDATE duels SET state='void',result='Competition paused by institution' WHERE"
                    + " state='active'");
          }
          d.audit(r.uid(), "flag_changed", r.p(), reason);
          return map("flag", d.need("SELECT * FROM flags WHERE name=?", r.p()));
        });
    a.add(
        "POST",
        "/api/admin/users/{id}",
        "admin",
        true,
        "{action:'warn'|'suspend'|'restore'|'reset_band'|'role'|'consent',reason,role?,band?,consent_ref?}",
        "{ok}",
        "VALIDATION,SELF_ACTION",
        r -> {
          r.recent();
          d.need("SELECT id FROM users WHERE id=?", r.p());
          require(
              !r.p().equals(r.uid()),
              409,
              "SELF_ACTION",
              "Another administrator must change your account.");
          String
              action =
                  choice(
                      r.body,
                      "action",
                      "warn",
                      "suspend",
                      "restore",
                      "reset_band",
                      "role",
                      "consent"),
              reason = text(r.body, "reason", 5, 2000);
          switch (action) {
            case "suspend" -> {
              d.exec("UPDATE users SET suspended=1 WHERE id=?", r.p());
              d.exec("DELETE FROM auth_sessions WHERE user_id=?", r.p());
              d.exec("DELETE FROM duel_queue WHERE user_id=?", r.p());
            }
            case "restore" ->
                d.exec("UPDATE users SET suspended=0,delete_after=NULL WHERE id=?", r.p());
            case "reset_band" ->
                d.exec(
                    "UPDATE users SET band=?,band_evidence=0 WHERE id=?",
                    integer(r.body, "band", 0, 3, 0),
                    r.p());
            case "role" ->
                d.exec(
                    "UPDATE users SET role=? WHERE id=?",
                    choice(r.body, "role", "student", "teacher", "admin"),
                    r.p());
            case "consent" ->
                d.exec(
                    "UPDATE users SET consent_ref=? WHERE id=?",
                    text(r.body, "consent_ref", 5, 200),
                    r.p());
            case "warn" ->
                e.notify(
                    r.p(),
                    "rewards",
                    "Integrity review notice: " + reason + ". Contact your coordinator to appeal.");
          }
          d.audit(r.uid(), "user_" + action, r.p(), reason);
          return map("ok", true);
        });
    a.add(
        "POST",
        "/api/admin/cohorts",
        "admin",
        true,
        "{cohort_id,title,user_id,moderator:boolean,reason}",
        "{ok}",
        "VALIDATION",
        r -> {
          r.recent();
          String id = text(r.body, "cohort_id", 1, 80), uid = text(r.body, "user_id", 1, 80);
          d.need("SELECT id FROM users WHERE id=?", uid);
          d.exec(
              "INSERT INTO cohorts VALUES(?,?) ON CONFLICT(id) DO UPDATE SET title=excluded.title",
              id,
              text(r.body, "title", 1, 120));
          d.exec(
              "INSERT OR IGNORE INTO "
                  + (yes(r.body, "moderator") ? "cohort_moderators" : "cohort_members")
                  + " VALUES(?,?)",
              id,
              uid);
          d.audit(r.uid(), "cohort_assigned", uid, text(r.body, "reason", 5, 2000));
          return map("ok", true);
        });
    a.add(
        "POST",
        "/api/admin/catalog",
        "admin",
        true,
        "{title,kind,price,stock?,adult_only,rules,rules_version,sponsor,value,reason}",
        "{item}",
        "VALIDATION",
        r -> {
          r.recent();
          String id = id(),
              kind =
                  choice(
                      r.body, "kind", "skin", "border", "hat", "theme", "content", "freeze",
                      "prize");
          if (kind.equals("content"))
            d.need("SELECT id FROM materials WHERE id=?", text(r.body, "value", 1, 120));
          String
              rules =
                  kind.equals("prize") ? text(r.body, "rules", 30, 10000) : str(r.body, "rules"),
              sponsor = kind.equals("prize") ? text(r.body, "sponsor", 3, 200) : "";
          d.insert(
              "catalog",
              map(
                  "id",
                  id,
                  "title",
                  text(r.body, "title", 1, 120),
                  "kind",
                  kind,
                  "price",
                  integer(r.body, "price", 0, 100000, 10),
                  "stock",
                  r.body.get("stock") == null ? null : integer(r.body, "stock", 0, 100000, 0),
                  "adult_only",
                  yes(r.body, "adult_only") ? 1 : 0,
                  "rules",
                  rules,
                  "rules_version",
                  integer(r.body, "rules_version", 1, 10000, 1),
                  "sponsor",
                  sponsor,
                  "value",
                  text(r.body, "value", 0, 120)));
          d.audit(r.uid(), "catalog_created", id, text(r.body, "reason", 5, 2000));
          return map("item", d.need("SELECT * FROM catalog WHERE id=?", id));
        });
    a.add(
        "PUT",
        "/api/admin/catalog/{id}",
        "admin",
        true,
        "{stock,active,reason}",
        "{item}",
        "VALIDATION",
        r -> {
          r.recent();
          d.need("SELECT * FROM catalog WHERE id=?", r.p());
          d.exec(
              "UPDATE catalog SET stock=?,active=? WHERE id=?",
              integer(r.body, "stock", 0, 100000, 0),
              yes(r.body, "active") ? 1 : 0,
              r.p());
          d.audit(r.uid(), "catalog_stock_changed", r.p(), text(r.body, "reason", 5, 2000));
          return map("item", d.need("SELECT * FROM catalog WHERE id=?", r.p()));
        });
    a.add(
        "POST",
        "/api/admin/claims/{id}",
        "admin",
        true,
        "{action:'approve'|'deny'|'fulfill',reason,eligibility_ref?,receipt?}",
        "{claim}",
        "INVALID_STATE,ELIGIBILITY_REQUIRED,SELF_APPROVAL",
        r -> {
          r.recent();
          Map<String, Object> claim = d.need("SELECT * FROM claims WHERE id=?", r.p());
          require(
              !r.uid().equals(str(claim, "user_id")),
              403,
              "SELF_APPROVAL",
              "A different administrator must process your claim.");
          String action = choice(r.body, "action", "approve", "deny", "fulfill"),
              reason = text(r.body, "reason", 5, 2000);
          if (action.equals("approve")) {
            require(
                str(claim, "state").equals("pending"),
                409,
                "INVALID_STATE",
                "Only pending claims can be approved.");
            String ref = text(r.body, "eligibility_ref", 8, 200);
            Map<String, Object>
                user = d.need("SELECT * FROM users WHERE id=?", claim.get("user_id")),
                item = d.need("SELECT * FROM catalog WHERE id=?", claim.get("item_id"));
            require(
                num(item, "adult_only") == 0 || str(user, "age_band").equals("adult"),
                403,
                "AGE_RESTRICTED",
                "Adult-only prize.");
            require(
                str(user, "age_band").equals("adult") || !str(user, "consent_ref").isBlank(),
                403,
                "ELIGIBILITY_REQUIRED",
                "Document guardian and institution consent first.");
            d.exec(
                "UPDATE claims SET state='approved',updated=?,reviewer=?,reason=? WHERE id=?",
                now(),
                r.uid(),
                reason + " Eligibility record: " + ref,
                r.p());
          } else if (action.equals("deny")) {
            require(
                Set.of("pending", "approved").contains(str(claim, "state")),
                409,
                "INVALID_STATE",
                "This claim is already settled.");
            e.refundClaim(claim, "denied", r.uid(), reason);
          } else {
            require(
                str(claim, "state").equals("approved"),
                409,
                "INVALID_STATE",
                "Approve and verify eligibility before fulfillment.");
            d.exec(
                "UPDATE claims SET state='fulfilled',updated=?,reviewer=?,receipt=?,reason=? WHERE"
                    + " id=?",
                now(),
                r.uid(),
                text(r.body, "receipt", 8, 500),
                reason,
                r.p());
          }
          d.audit(r.uid(), "claim_" + action, r.p(), reason);
          return map("claim", d.need("SELECT * FROM claims WHERE id=?", r.p()));
        });
    a.add(
        "POST",
        "/api/admin/ledger",
        "admin",
        true,
        "{user_id,xp,coins,reason,origin}",
        "{wallet}",
        "NEGATIVE_BALANCE",
        r -> {
          r.recent();
          String uid = text(r.body, "user_id", 1, 80);
          d.need("SELECT id FROM users WHERE id=?", uid);
          int xp = integer(r.body, "xp", -100000, 100000, 0),
              coins = integer(r.body, "coins", -100000, 100000, 0);
          Map<String, Object> w = e.wallet(uid);
          require(
              num(w, "xp") + xp >= 0 && num(w, "coins") + coins >= 0,
              409,
              "NEGATIVE_BALANCE",
              "Adjustment would create a negative balance. Review and record a smaller"
                  + " correction.");
          String origin = "admin:" + text(r.body, "origin", 8, 120),
              reason = text(r.body, "reason", 5, 2000);
          e.ledger(uid, xp, coins, origin, reason, r.uid());
          d.audit(r.uid(), "ledger_adjustment", uid, reason);
          return map("wallet", e.wallet(uid));
        });
  }

  boolean assigned(String moderator, String uid) {
    return moderator.equals(uid)
        || d.scalar(
                "SELECT count(*) FROM cohort_members m JOIN cohort_moderators mod ON"
                    + " m.cohort_id=mod.cohort_id WHERE m.user_id=? AND mod.user_id=?",
                uid,
                moderator)
            > 0;
  }

  void allow(Api.Request r, String uid) {
    require(
        str(r.user, "role").equals("admin") || assigned(r.uid(), uid),
        403,
        "FORBIDDEN",
        "This item is outside your assigned cohort.");
  }
}
