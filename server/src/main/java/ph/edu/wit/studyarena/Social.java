package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.util.*;

final class Social {
  final Api a;
  final Db d;
  final Content c;
  final Economy e;

  Social(Api a, Content c, Economy e) {
    this.a = a;
    d = a.db;
    this.c = c;
    this.e = e;
    a.add(
        "GET",
        "/api/rooms",
        "student",
        false,
        "?topic=&offset=&limit=",
        "{mine,matching}",
        "FEATURE_DISABLED",
        r -> {
          r.flag("rooms");
          return map(
              "mine",
              d.all(
                  "SELECT r.* FROM rooms r JOIN memberships m ON r.id=m.room_id WHERE m.user_id=?"
                      + " ORDER BY r.last_active DESC LIMIT ? OFFSET ?",
                  r.uid(),
                  r.limit(),
                  r.offset()),
              "matching",
              d.all(
                  "SELECT r.id,r.title,r.topic_id,r.band,(SELECT count(*) FROM memberships m WHERE"
                      + " room_id=r.id) AS members FROM rooms r WHERE r.state='active' AND r.band=?"
                      + " AND (?='' OR topic_id=?) LIMIT ?",
                  r.user.get("band"),
                  r.q("topic"),
                  r.q("topic"),
                  r.limit()));
        });
    a.add(
        "POST",
        "/api/rooms",
        "student",
        true,
        "{title,topic_id}",
        "{room,code}",
        "VALIDATION,FEATURE_DISABLED",
        r -> {
          r.flag("rooms");
          d.need("SELECT id FROM topics WHERE id=?", str(r.body, "topic_id"));
          d.rate("room-create:" + r.uid(), 5, 3600);
          String id = id(), code = token().substring(0, 12);
          d.insert(
              "rooms",
              map(
                  "id",
                  id,
                  "owner_id",
                  r.uid(),
                  "title",
                  text(r.body, "title", 1, 80),
                  "topic_id",
                  r.body.get("topic_id"),
                  "band",
                  r.user.get("band"),
                  "code_hash",
                  hash(code),
                  "code_expires",
                  now() + 86400,
                  "state",
                  "active",
                  "last_active",
                  now()));
          d.insert("memberships", map("room_id", id, "user_id", r.uid(), "joined", now()));
          return map("room", room(id, r.uid()), "code", code);
        });
    a.add(
        "POST",
        "/api/rooms/join",
        "student",
        true,
        "{code?|room_id?}",
        "{room}",
        "INVALID_INVITE,ROOM_FULL,SKILL_BAND_MISMATCH",
        r -> {
          r.flag("rooms");
          d.rate("join:" + r.uid(), 10, 60);
          Map<String, Object> room =
              str(r.body, "code").isBlank()
                  ? d.one(
                      "SELECT * FROM rooms WHERE id=? AND state='active'", str(r.body, "room_id"))
                  : d.one(
                      "SELECT * FROM rooms WHERE code_hash=? AND code_expires>? AND state='active'",
                      hash(str(r.body, "code")),
                      now());
          require(room != null, 404, "INVALID_INVITE", "Invite is invalid or expired.");
          require(
              num(room, "band") == num(r.user, "band"),
              409,
              "SKILL_BAND_MISMATCH",
              "Choose a room in your skill band.");
          String id = str(room, "id");
          if (d.one("SELECT * FROM memberships WHERE room_id=? AND user_id=?", id, r.uid())
              == null) {
            require(
                d.scalar("SELECT count(*) FROM memberships WHERE room_id=?", id) < 10,
                409,
                "ROOM_FULL",
                "This room has reached its 10-member limit.");
            d.insert("memberships", map("room_id", id, "user_id", r.uid(), "joined", now()));
          }
          return map("room", room(id, r.uid()));
        });
    a.add(
        "GET",
        "/api/rooms/{id}",
        "student",
        false,
        "—",
        "{room,roster,messages,resources}",
        "NOT_FOUND",
        r -> {
          r.flag("rooms");
          Map<String, Object> room = room(r.p(), r.uid());
          return map(
              "room",
              room,
              "roster",
              d.all(
                  "SELECT u.id,u.display_name,m.joined,u.band FROM memberships m JOIN users u ON"
                      + " m.user_id=u.id WHERE room_id=?",
                  r.p()),
              "messages",
              d.all(
                  "SELECT m.id,m.user_id,u.display_name,m.body,m.created FROM messages m LEFT JOIN"
                      + " users u ON m.user_id=u.id WHERE m.room_id=? AND m.hidden=0 AND NOT EXISTS"
                      + " (SELECT 1 FROM blocks b WHERE b.user_id=? AND b.blocked_id=m.user_id)"
                      + " ORDER BY m.created DESC LIMIT 50",
                  r.p(),
                  r.uid()),
              "resources",
              d.all("SELECT * FROM room_resources WHERE room_id=?", r.p()));
        });
    a.add(
        "PUT",
        "/api/rooms/{id}",
        "student",
        true,
        "{action:'schedule'|'timer'|'rotate'|'transfer'|'remove'|'disband'|'restore',scheduled?,minutes?,user_id?}",
        "{room?,code?,ok?}",
        "FORBIDDEN,INVALID_STATE",
        r -> {
          r.flag("rooms");
          Map<String, Object> room = d.need("SELECT * FROM rooms WHERE id=?", r.p());
          r.owner(room);
          String action =
              choice(
                  r.body,
                  "action",
                  "schedule",
                  "timer",
                  "rotate",
                  "transfer",
                  "remove",
                  "disband",
                  "restore");
          switch (action) {
            case "schedule" -> {
              require(
                  num(r.body, "scheduled") > now(),
                  422,
                  "VALIDATION",
                  "Choose a future session time.");
              d.exec("UPDATE rooms SET scheduled=? WHERE id=?", r.body.get("scheduled"), r.p());
            }
            case "timer" ->
                d.exec(
                    "UPDATE rooms SET timer_end=? WHERE id=?",
                    now() + integer(r.body, "minutes", 5, 180, 25) * 60,
                    r.p());
            case "rotate" -> {
              String code = token().substring(0, 12);
              d.exec(
                  "UPDATE rooms SET code_hash=?,code_expires=? WHERE id=?",
                  hash(code),
                  now() + 86400,
                  r.p());
              return map("code", code);
            }
            case "transfer" -> {
              String uid = text(r.body, "user_id", 1, 80);
              c.membership(r.p(), uid);
              d.exec("UPDATE rooms SET owner_id=? WHERE id=?", uid, r.p());
            }
            case "remove" -> {
              String uid = text(r.body, "user_id", 1, 80);
              require(
                  !uid.equals(r.uid()), 422, "VALIDATION", "Transfer ownership before leaving.");
              d.exec("DELETE FROM memberships WHERE room_id=? AND user_id=?", r.p(), uid);
            }
            case "disband" -> {
              d.exec(
                  "UPDATE rooms SET state='archived',archived=?,timer_end=NULL WHERE id=?",
                  now(),
                  r.p());
              d.audit(r.uid(), "room_disbanded", r.p(), "Owner disbanded room");
              return map("ok", true);
            }
            case "restore" -> {
              require(
                  str(room, "state").equals("archived")
                      && now() - num(room, "archived") < 30 * 86400,
                  409,
                  "INVALID_STATE",
                  "Restoration window has ended.");
              d.exec("UPDATE rooms SET state='active',archived=NULL,warned=0 WHERE id=?", r.p());
            }
          }
          d.exec("UPDATE rooms SET last_active=? WHERE id=?", now(), r.p());
          return map("ok", true);
        });
    a.add(
        "POST",
        "/api/rooms/{id}/leave",
        "student",
        true,
        "{}",
        "{ok}",
        "OWNER_TRANSFER_REQUIRED",
        r -> {
          Map<String, Object> room = room(r.p(), r.uid());
          if (str(room, "owner_id").equals(r.uid())) {
            require(
                d.scalar("SELECT count(*) FROM memberships WHERE room_id=?", r.p()) == 1,
                409,
                "OWNER_TRANSFER_REQUIRED",
                "Transfer ownership or disband before leaving.");
            d.exec("UPDATE rooms SET state='archived',archived=? WHERE id=?", now(), r.p());
          }
          d.exec("DELETE FROM memberships WHERE room_id=? AND user_id=?", r.p(), r.uid());
          return map("ok", true);
        });
    a.add(
        "POST",
        "/api/rooms/{id}/messages",
        "student",
        true,
        "{body}",
        "{message,support?}",
        "RATE_LIMITED,NOT_FOUND",
        r -> {
          r.flag("rooms");
          room(r.p(), r.uid());
          d.rate("chat:" + r.uid(), 10, 60);
          String body = text(r.body, "body", 1, 2000), id = id();
          d.insert(
              "messages",
              map("id", id, "room_id", r.p(), "user_id", r.uid(), "body", body, "created", now()));
          d.exec("UPDATE rooms SET last_active=? WHERE id=?", now(), r.p());
          boolean distress =
              normalized(body)
                  .matches("(?s).*(kill myself|end my life|hurt myself|suicide|magpakamatay).*");
          return map(
              "message",
              d.need("SELECT * FROM messages WHERE id=?", id),
              "support",
              distress
                  ? "If you may be in immediate danger, contact emergency services or a trusted"
                      + " person nearby. Contact your school guidance office for support. Study"
                      + " Arena is not a counselling service."
                  : null);
        });
    a.add(
        "POST",
        "/api/rooms/{id}/resources",
        "student",
        true,
        "{kind:'deck'|'material',resource_id}",
        "{ok}",
        "NOT_FOUND",
        r -> {
          room(r.p(), r.uid());
          String kind = choice(r.body, "kind", "deck", "material"),
              id = text(r.body, "resource_id", 1, 80);
          if (kind.equals("deck")) {
            Map<String, Object> deck = c.deck(id, r.uid());
            if (str(deck, "owner_id").equals(r.uid()))
              d.exec("UPDATE decks SET visibility='room',room_id=? WHERE id=?", r.p(), id);
            else
              require(
                  str(deck, "status").equals("approved"),
                  403,
                  "FORBIDDEN",
                  "Only approved public decks or your own decks can be shared.");
          } else {
            Map<String, Object> m = c.material(id, r.uid());
            require(
                str(m, "status").equals("approved"),
                403,
                "FORBIDDEN",
                "Materials need approval before room sharing.");
          }
          d.exec("INSERT OR IGNORE INTO room_resources VALUES(?,?,?,?)", r.p(), kind, id, r.uid());
          return map("ok", true);
        });
    a.add(
        "POST",
        "/api/users/{id}/block",
        "student",
        true,
        "{blocked:boolean}",
        "{ok}",
        "VALIDATION",
        r -> {
          require(!r.p().equals(r.uid()), 422, "VALIDATION", "You cannot block yourself.");
          d.need("SELECT id FROM users WHERE id=?", r.p());
          if (yes(r.body, "blocked"))
            d.exec("INSERT OR IGNORE INTO blocks VALUES(?,?)", r.uid(), r.p());
          else d.exec("DELETE FROM blocks WHERE user_id=? AND blocked_id=?", r.uid(), r.p());
          return map("ok", true);
        });
    a.add(
        "POST",
        "/api/duels/queue",
        "student",
        true,
        "{topic_id,bot?:boolean}",
        "{duel?|queued,wait_seconds?}",
        "COMPETITION_HIDDEN,EMAIL_UNVERIFIED,ACTIVE_DUEL,COOLDOWN",
        r -> {
          eligible(r);
          Map<String, Object> active = active(r.uid());
          if (active != null) return duelView(active, r.uid());
          d.rate("queue:" + r.uid(), 4, 60);
          d.need("SELECT id FROM topics WHERE id=?", str(r.body, "topic_id"));
          if (yes(r.body, "bot")) {
            Map<String, Object> queue = d.one("SELECT * FROM duel_queue WHERE user_id=?", r.uid());
            require(
                queue != null && now() - num(queue, "queued") >= 20,
                409,
                "COOLDOWN",
                "Practice bot is available after 20 seconds of searching.");
            return duelView(
                createDuel(r.uid(), null, str(queue, "topic_id"), (int) num(r.user, "band")),
                r.uid());
          }
          d.exec(
              "INSERT INTO duel_queue VALUES(?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET"
                  + " heartbeat=excluded.heartbeat",
              r.uid(),
              str(r.body, "topic_id"),
              r.user.get("band"),
              now(),
              now());
          return match(r);
        });
    a.add(
        "GET",
        "/api/duels/current",
        "student",
        false,
        "—",
        "{duel,questions,answers?,result?}|{queued,wait_seconds}",
        "COMPETITION_HIDDEN,EMAIL_UNVERIFIED",
        r -> {
          eligible(r);
          Map<String, Object> active = active(r.uid());
          if (active != null) {
            settle(active);
            Map<String, Object> fresh = d.need("SELECT * FROM duels WHERE id=?", active.get("id"));
            if (str(fresh, "state").equals("active"))
              d.exec(
                  "UPDATE duels SET "
                      + (str(fresh, "a_id").equals(r.uid()) ? "a_seen" : "b_seen")
                      + "=? WHERE id=?",
                  now(),
                  fresh.get("id"));
            return duelView(d.need("SELECT * FROM duels WHERE id=?", fresh.get("id")), r.uid());
          }
          return match(r);
        });
    a.add(
        "DELETE",
        "/api/duels/queue",
        "student",
        true,
        "{}",
        "{ok}",
        "",
        r -> {
          d.exec("DELETE FROM duel_queue WHERE user_id=?", r.uid());
          return map("ok", true);
        });
    a.add(
        "GET",
        "/api/duels/{id}",
        "student",
        false,
        "—",
        "{duel,questions,answers?,result?}",
        "NOT_FOUND",
        r -> {
          eligible(r);
          Map<String, Object> duel = duel(r.p(), r.uid());
          settle(duel);
          return duelView(d.need("SELECT * FROM duels WHERE id=?", r.p()), r.uid());
        });
    a.add(
        "POST",
        "/api/duels/{id}/answer",
        "student",
        true,
        "{question_id,answer}",
        "{accepted,duel}",
        "INVALID_STATE,DEADLINE_EXPIRED",
        r -> {
          eligible(r);
          Map<String, Object> duel = duel(r.p(), r.uid());
          settle(duel);
          duel = d.need("SELECT * FROM duels WHERE id=?", r.p());
          require(str(duel, "state").equals("active"), 409, "INVALID_STATE", "Duel has ended.");
          require(
              now() <= num(duel, "deadline"),
              409,
              "DEADLINE_EXPIRED",
              "Answer arrived after the deadline.");
          Map<String, Object> q =
              Study.findQuestion(rows(str(duel, "question_data")), str(r.body, "question_id"));
          String answer = text(r.body, "answer", 1, 4000);
          boolean correct = Study.correct(q, answer);
          d.exec(
              "INSERT OR IGNORE INTO duel_answers VALUES(?,?,?,?,?,?)",
              r.p(),
              r.uid(),
              q.get("id"),
              answer,
              correct ? 1 : 0,
              now());
          d.exec(
              "UPDATE duels SET "
                  + (str(duel, "a_id").equals(r.uid()) ? "a_seen" : "b_seen")
                  + "=? WHERE id=?",
              now(),
              r.p());
          settle(d.need("SELECT * FROM duels WHERE id=?", r.p()));
          return map(
              "accepted",
              true,
              "duel",
              duelView(d.need("SELECT * FROM duels WHERE id=?", r.p()), r.uid()));
        });
    a.add(
        "POST",
        "/api/duels/{id}/forfeit",
        "student",
        true,
        "{}",
        "{duel}",
        "",
        r -> {
          Map<String, Object> duel = duel(r.p(), r.uid());
          if (str(duel, "state").equals("active"))
            d.exec(
                "UPDATE duels SET state='forfeit',result=? WHERE id=?",
                "Forfeited by " + (str(duel, "a_id").equals(r.uid()) ? "player A" : "player B"),
                r.p());
          return duelView(d.need("SELECT * FROM duels WHERE id=?", r.p()), r.uid());
        });
  }

  Map<String, Object> room(String id, String uid) {
    c.membership(id, uid);
    Map<String, Object> out = d.need("SELECT * FROM rooms WHERE id=?", id);
    out.remove("code_hash");
    return out;
  }

  void eligible(Api.Request r) {
    r.flag("competition");
    require(
        num(r.user, "competition") == 1,
        403,
        "COMPETITION_HIDDEN",
        "Competition is hidden in your preferences.");
    require(
        num(r.user, "verified") == 1,
        403,
        "EMAIL_UNVERIFIED",
        "Verify your email before entering a duel.");
  }

  Map<String, Object> active(String uid) {
    return d.one(
        "SELECT * FROM duels WHERE state='active' AND (a_id=? OR b_id=?) ORDER BY created DESC"
            + " LIMIT 1",
        uid,
        uid);
  }

  Map<String, Object> duel(String id, String uid) {
    return d.need("SELECT * FROM duels WHERE id=? AND (a_id=? OR b_id=?)", id, uid, uid);
  }

  Map<String, Object> match(Api.Request r) {
    Map<String, Object> q = d.one("SELECT * FROM duel_queue WHERE user_id=?", r.uid());
    if (q == null) return map("queued", false);
    d.exec("UPDATE duel_queue SET heartbeat=? WHERE user_id=?", now(), r.uid());
    Map<String, Object> opponent =
        d.one(
            "SELECT q.* FROM duel_queue q JOIN users u ON q.user_id=u.id WHERE q.user_id!=? AND"
                + " q.topic_id=? AND q.band=? AND q.heartbeat>? AND u.verified=1 AND"
                + " u.competition=1 AND u.suspended=0 AND u.delete_after IS NULL AND NOT EXISTS"
                + " (SELECT 1 FROM blocks b WHERE b.user_id=? AND b.blocked_id=q.user_id OR"
                + " b.blocked_id=? AND b.user_id=q.user_id) ORDER BY q.queued LIMIT 1",
            r.uid(),
            q.get("topic_id"),
            q.get("band"),
            now() - 10,
            r.uid(),
            r.uid());
    if (opponent != null)
      return duelView(
          createDuel(str(opponent, "user_id"), r.uid(), str(q, "topic_id"), (int) num(q, "band")),
          r.uid());
    return map("queued", true, "wait_seconds", (int) (now() - num(q, "queued")));
  }

  Map<String, Object> createDuel(String ua, String ub, String topic, int band) {
    String id = id();
    List<Map<String, Object>> qs = new ArrayList<>();
    for (int i = 0; i < 5; i++) {
      int x = RANDOM.nextInt(9) + band * 5 + 2, y = RANDOM.nextInt(9) + 2;
      String prompt, answer, explanation;
      if (topic.equals("computing")) {
        prompt = "Convert binary " + Integer.toBinaryString(x) + " to decimal.";
        answer = "" + x;
        explanation = "Add each set bit’s power of two. The decimal value is " + x + ".";
      } else if (topic.equals("calculus")) {
        prompt = "For f(x) = " + x + "x², what is f′(" + y + ")?";
        answer = "" + (2 * x * y);
        explanation = "The power rule gives f′(x) = " + (2 * x) + "x. Substitute " + y + ".";
      } else {
        prompt = "Solve " + x + "x = " + (x * y) + ". What is x?";
        answer = "" + y;
        explanation = "Divide both sides by " + x + " to obtain x = " + y + ".";
      }
      qs.add(
          map(
              "id",
              id(),
              "kind",
              "identification",
              "prompt",
              prompt,
              "options",
              List.of(),
              "accepted",
              List.of(answer),
              "explanation",
              explanation,
              "topic_id",
              topic));
    }
    Map<String, Object> season =
        d.one(
            "SELECT id FROM seasons WHERE starts<=? AND ends>? ORDER BY starts DESC LIMIT 1",
            now(),
            now());
    double t = now();
    d.insert(
        "duels",
        map(
            "id",
            id,
            "a_id",
            ua,
            "b_id",
            ub,
            "topic_id",
            topic,
            "season_id",
            season == null ? null : season.get("id"),
            "state",
            "active",
            "created",
            t,
            "deadline",
            t + 90 + 2,
            "a_seen",
            t,
            "b_seen",
            t,
            "question_data",
            json(qs),
            "bot",
            ub == null ? 1 : 0,
            "b_score",
            ub == null ? RANDOM.nextInt(4) + 1 : 0));
    d.exec("DELETE FROM duel_queue WHERE user_id=? OR user_id=?", ua, ub);
    return d.need("SELECT * FROM duels WHERE id=?", id);
  }

  void settle(Map<String, Object> duel) {
    if (!str(duel, "state").equals("active")) return;
    String id = str(duel, "id");
    int
        aCount =
            (int)
                d.scalar(
                    "SELECT count(*) FROM duel_answers WHERE duel_id=? AND user_id=?",
                    id,
                    duel.get("a_id")),
        bCount =
            num(duel, "bot") == 1
                ? 5
                : (int)
                    d.scalar(
                        "SELECT count(*) FROM duel_answers WHERE duel_id=? AND user_id=?",
                        id,
                        duel.get("b_id"));
    boolean aLost = now() - num(duel, "a_seen") > 20,
        bLost = num(duel, "bot") == 0 && now() - num(duel, "b_seen") > 20;
    if (aCount == 5 && bCount == 5 || now() >= num(duel, "deadline")) {
      int
          sa =
              (int)
                  d.scalar(
                      "SELECT sum(correct) FROM duel_answers WHERE duel_id=? AND user_id=?",
                      id,
                      duel.get("a_id")),
          sb =
              num(duel, "bot") == 1
                  ? (int) num(duel, "b_score")
                  : (int)
                      d.scalar(
                          "SELECT sum(correct) FROM duel_answers WHERE duel_id=? AND user_id=?",
                          id,
                          duel.get("b_id"));
      d.exec(
          "UPDATE duels SET state='completed',a_score=?,b_score=?,result=? WHERE id=?",
          sa,
          sb,
          sa == sb
              ? "Draw"
              : sa > sb
                  ? "Player A completed more correct answers"
                  : "Player B completed more correct answers",
          id);
    } else if (aLost && bLost)
      d.exec(
          "UPDATE duels SET state='void',result='Both players disconnected; no penalty' WHERE id=?",
          id);
    else if (aLost || bLost)
      d.exec(
          "UPDATE duels SET state='forfeit',result=? WHERE id=?",
          aLost ? "Player A disconnected" : "Player B disconnected",
          id);
  }

  Map<String, Object> duelView(Map<String, Object> duel, String uid) {
    List<Map<String, Object>> qs = rows(str(duel, "question_data"));
    duel.remove("question_data");
    boolean complete = !str(duel, "state").equals("active");
    if (!complete)
      for (Map<String, Object> q : qs) {
        q.remove("accepted");
        q.remove("explanation");
      }
    Map<String, Object> opponent =
        d.one(
            "SELECT display_name FROM users WHERE id=?",
            str(duel, "a_id").equals(uid) ? duel.get("b_id") : duel.get("a_id"));
    duel.put(
        "opponent_name",
        num(duel, "bot") == 1
            ? "Practice bot — unranked"
            : opponent == null ? "Former student" : opponent.get("display_name"));
    duel.put("your_side", str(duel, "a_id").equals(uid) ? "a" : "b");
    return map(
        "duel",
        duel,
        "questions",
        qs,
        "answers",
        d.all(
            complete
                ? "SELECT question_id,answer,correct,user_id FROM duel_answers WHERE duel_id=? AND"
                    + " user_id=?"
                : "SELECT question_id,answer FROM duel_answers WHERE duel_id=? AND user_id=?",
            duel.get("id"),
            uid),
        "server_time",
        now());
  }
}
