package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.time.*;
import java.util.*;

final class Study {
  final Api a;
  final Db d;
  final Content c;
  final Economy e;

  Study(Api a, Content c, Economy e) {
    this.a = a;
    d = a.db;
    this.c = c;
    this.e = e;
    a.add(
        "GET",
        "/api/study/sessions",
        "student",
        false,
        "?offset=&limit=",
        "{items:[StudySession with own notes]}",
        "",
        r -> {
          List<Map<String, Object>> rows =
              d.all(
                  "SELECT * FROM study_sessions WHERE user_id=? ORDER BY started DESC LIMIT ?"
                      + " OFFSET ?",
                  r.uid(),
                  r.limit(),
                  r.offset());
          for (Map<String, Object> row : rows) {
            row.put("notes", crypt(str(row, "notes_cipher"), a.key, false));
            row.remove("notes_cipher");
          }
          return map("items", rows);
        });
    a.add(
        "POST",
        "/api/study/sessions",
        "student",
        true,
        "{topic_id,notes?}",
        "{session}",
        "ACTIVE_SESSION",
        r -> {
          d.need("SELECT * FROM topics WHERE id=?", str(r.body, "topic_id"));
          expireSessions(r.uid());
          require(
              d.scalar(
                      "SELECT count(*) FROM study_sessions WHERE user_id=? AND state IN"
                          + " ('running','paused')",
                      r.uid())
                  == 0,
              409,
              "ACTIVE_SESSION",
              "Resume or finish your other active session.");
          String id = id();
          double t = now();
          d.insert(
              "study_sessions",
              map(
                  "id",
                  id,
                  "user_id",
                  r.uid(),
                  "topic_id",
                  r.body.get("topic_id"),
                  "state",
                  "running",
                  "started",
                  t,
                  "last_heartbeat",
                  t,
                  "timezone",
                  r.user.get("timezone"),
                  "notes_cipher",
                  crypt(text(r.body, "notes", 0, 10000), a.key, true)));
          return map("session", safeSession(d.need("SELECT * FROM study_sessions WHERE id=?", id)));
        });
    a.add(
        "PUT",
        "/api/study/sessions/{id}",
        "student",
        true,
        "{action:'heartbeat'|'pause'|'resume'|'complete'|'discard',notes?}",
        "{session,wallet}",
        "INVALID_STATE",
        r -> {
          Map<String, Object> s =
              d.need("SELECT * FROM study_sessions WHERE id=? AND user_id=?", r.p(), r.uid());
          String action =
              choice(r.body, "action", "heartbeat", "pause", "resume", "complete", "discard");
          if (!Set.of("running", "paused").contains(str(s, "state")))
            return map("session", safeSession(s), "wallet", e.wallet(r.uid()));
          double t = now(),
              delta =
                  str(s, "state").equals("running")
                      ? Math.min(120, Math.max(0, t - num(s, "last_heartbeat")))
                      : 0;
          double elapsed = Math.min(10800, num(s, "elapsed") + delta);
          String state = str(s, "state");
          if (action.equals("pause")) state = "paused";
          if (action.equals("resume")) state = "running";
          if (t - num(s, "started") >= 14400 || action.equals("complete")) state = "completed";
          if (action.equals("discard")) state = "discarded";
          int minutes = state.equals("completed") && elapsed >= 300 ? (int) (elapsed / 60) : 0;
          String notes =
              r.body.containsKey("notes")
                  ? crypt(text(r.body, "notes", 0, 10000), a.key, true)
                  : str(s, "notes_cipher");
          d.exec(
              "UPDATE study_sessions SET"
                  + " state=?,ended=?,elapsed=?,credited=?,last_heartbeat=?,notes_cipher=? WHERE"
                  + " id=?",
              state,
              Set.of("completed", "discarded").contains(state) ? t : null,
              elapsed,
              minutes,
              t,
              notes,
              r.p());
          if (minutes > 0)
            sessionReward(r.uid(), r.p(), minutes, num(s, "started"), str(s, "timezone"));
          return map(
              "session",
              safeSession(d.need("SELECT * FROM study_sessions WHERE id=?", r.p())),
              "wallet",
              e.wallet(r.uid()));
        });
    a.add(
        "POST",
        "/api/study/offline",
        "student",
        true,
        "{id,topic_id,started,ended,elapsed,timezone,notes}",
        "{session,wallet}",
        "VALIDATION,SESSION_CONFLICT",
        r -> {
          String id = text(r.body, "id", 16, 80);
          Map<String, Object> existing =
              d.one("SELECT * FROM study_sessions WHERE id=? AND user_id=?", id, r.uid());
          if (existing != null && !Set.of("running", "paused").contains(str(existing, "state")))
            return map("session", safeSession(existing), "wallet", e.wallet(r.uid()));
          double started = num(r.body, "started"),
              ended = num(r.body, "ended"),
              elapsed = num(r.body, "elapsed");
          require(
              started > now() - 30 * 86400
                  && ended <= now() + 120
                  && ended >= started
                  && elapsed >= 0
                  && elapsed <= Math.min(14400, ended - started + 5),
              422,
              "VALIDATION",
              "Offline timing evidence is inconsistent. Keep the log locally and correct the device"
                  + " clock.");
          d.need("SELECT * FROM topics WHERE id=?", str(r.body, "topic_id"));
          String tz = text(r.body, "timezone", 1, 80);
          try {
            ZoneId.of(tz);
          } catch (Exception ex) {
            throw new Fault(422, "VALIDATION", "Invalid timezone.");
          }
          boolean overlap =
              d.scalar(
                      "SELECT count(*) FROM study_sessions WHERE user_id=? AND id!=? AND"
                          + " state!='discarded' AND started<? AND coalesce(ended,?)>?",
                      r.uid(),
                      id,
                      ended,
                      now(),
                      started)
                  > 0;
          int credit = overlap ? 0 : elapsed < 300 ? 0 : Math.min(180, (int) (elapsed / 60));
          if (existing != null) d.exec("DELETE FROM study_sessions WHERE id=?", id);
          d.insert(
              "study_sessions",
              map(
                  "id",
                  id,
                  "user_id",
                  r.uid(),
                  "topic_id",
                  r.body.get("topic_id"),
                  "state",
                  credit > 0 ? "completed" : "uncredited",
                  "started",
                  started,
                  "ended",
                  ended,
                  "elapsed",
                  elapsed,
                  "credited",
                  credit,
                  "last_heartbeat",
                  ended,
                  "timezone",
                  tz,
                  "notes_cipher",
                  crypt(text(r.body, "notes", 0, 10000), a.key, true),
                  "offline",
                  1,
                  "reason",
                  overlap
                      ? "Overlaps a previously accepted session"
                      : credit == 0
                          ? "Less than five minutes"
                          : "Offline self-reported study; excluded from prize eligibility"
                              + " evidence"));
          if (credit > 0) sessionReward(r.uid(), id, credit, started, tz);
          return map(
              "session",
              safeSession(d.need("SELECT * FROM study_sessions WHERE id=?", id)),
              "wallet",
              e.wallet(r.uid()));
        });
    a.add(
        "POST",
        "/api/cards/{id}/review",
        "student",
        true,
        "{known?:boolean,rating?:again|hard|good|easy,occurred?}",
        "{schedule,rewarded,wallet}",
        "VALIDATION,NOT_FOUND",
        r -> {
          Map<String, Object> card =
              d.need(
                  "SELECT c.*,x.topic_id FROM cards c JOIN decks x ON c.deck_id=x.id WHERE c.id=?",
                  r.p());
          c.deck(str(card, "deck_id"), r.uid());
          double t = now();
          Map<String, Object> old =
              d.one("SELECT * FROM card_schedule WHERE user_id=? AND card_id=?", r.uid(), r.p());
          boolean due = old == null || num(old, "due") <= t;
          String rating = Objects.toString(r.body.get("rating"), "").strip().toLowerCase(Locale.ROOT);
          if (rating.isBlank()) rating = yes(r.body, "known") ? "good" : "again";
          require(
              Set.of("again", "hard", "good", "easy").contains(rating),
              422,
              "VALIDATION",
              "Rating must be again, hard, good or easy.");
          boolean known = !rating.equals("again");
          double interval = old == null ? 0 : num(old, "interval_days"),
              ease = old == null ? 2.5 : num(old, "ease");
          int reps = old == null ? 0 : (int) num(old, "repetitions");
          if (due) {
            if (rating.equals("again")) {
              reps = 0;
              interval = 0.01;
              ease = Math.max(1.3, ease - 0.2);
            } else if (rating.equals("hard")) {
              reps++;
              interval = Math.max(0.5, interval == 0 ? 0.5 : interval * 1.2);
              ease = Math.max(1.3, ease - 0.15);
            } else if (rating.equals("easy")) {
              reps++;
              interval = reps == 1 ? 3 : reps == 2 ? 7 : Math.min(365, interval * (ease + 0.15) * 1.3);
              ease = Math.min(3.2, ease + 0.15);
            } else {
              reps++;
              interval = reps == 1 ? 1 : reps == 2 ? 3 : Math.min(365, interval * ease);
            }
            d.exec(
                "INSERT INTO card_schedule VALUES(?,?,?,?,?,?) ON CONFLICT(user_id,card_id) DO"
                    + " UPDATE SET"
                    + " due=excluded.due,interval_days=excluded.interval_days,ease=excluded.ease,repetitions=excluded.repetitions",
                r.uid(),
                r.p(),
                t + interval * 86400,
                interval,
                ease,
                reps);
          }
          String event = id();
          boolean reward =
              due
                  && d.scalar(
                          "SELECT count(*) FROM review_events WHERE user_id=? AND card_id=? AND"
                              + " rewarded=1 AND occurred>?",
                          r.uid(),
                          r.p(),
                          t - 86400)
                      == 0;
          d.insert(
              "review_events",
              map(
                  "id",
                  event,
                  "user_id",
                  r.uid(),
                  "card_id",
                  r.p(),
                  "known",
                  known ? 1 : 0,
                  "occurred",
                  t,
                  "rewarded",
                  reward ? 1 : 0));
          if (due) evidence(r.uid(), str(card, "topic_id"), known ? 1 : 0, 0.5, "review:" + event);
          if (reward)
            e.award(r.uid(), "review:" + event, 2, 1, "First due review of this card in 24 hours");
          return map(
              "schedule",
              d.one("SELECT * FROM card_schedule WHERE user_id=? AND card_id=?", r.uid(), r.p()),
              "rewarded",
              reward,
              "wallet",
              e.wallet(r.uid()));
        });
    a.add(
        "POST",
        "/api/quizzes/{id}/attempts",
        "student",
        true,
        "{timed:boolean}",
        "{attempt,questions}",
        "EMPTY_QUIZ",
        r -> {
          Map<String, Object> quiz = c.quiz(r.p(), r.uid()),
              old =
                  d.one(
                      "SELECT * FROM attempts WHERE user_id=? AND quiz_id=? AND state='active'",
                      r.uid(),
                      r.p());
          if (old != null) return attemptView(old);
          List<Map<String, Object>> qs = c.questions(r.p());
          require(!qs.isEmpty(), 409, "EMPTY_QUIZ", "Quiz has no questions.");
          Collections.shuffle(qs, RANDOM);
          String id = id();
          double t = now();
          d.insert(
              "attempts",
              map(
                  "id",
                  id,
                  "user_id",
                  r.uid(),
                  "quiz_id",
                  r.p(),
                  "state",
                  "active",
                  "started",
                  t,
                  "deadline",
                  yes(r.body, "timed")
                      ? t + (quiz.get("duration") == null ? qs.size() * 60 : num(quiz, "duration"))
                      : null,
                  "question_order",
                  json(qs.stream().map(q -> q.get("id")).toList()),
                  "total",
                  qs.size(),
                  "snapshot",
                  json(qs)));
          return attemptView(d.need("SELECT * FROM attempts WHERE id=?", id));
        });
    a.add(
        "GET",
        "/api/attempts/{id}",
        "student",
        false,
        "—",
        "{attempt,questions,answers}",
        "NOT_FOUND",
        r ->
            attemptView(d.need("SELECT * FROM attempts WHERE id=? AND user_id=?", r.p(), r.uid())));
    a.add(
        "POST",
        "/api/attempts/{id}/answer",
        "student",
        true,
        "{question_id,answer}",
        "{correct,accepted,explanation,late}",
        "INVALID_STATE,QUESTION_NOT_FOUND",
        r -> {
          Map<String, Object> t =
              d.need("SELECT * FROM attempts WHERE id=? AND user_id=?", r.p(), r.uid());
          require(
              str(t, "state").equals("active"), 409, "INVALID_STATE", "This attempt is closed.");
          Map<String, Object> q =
              findQuestion(rows(str(t, "snapshot")), str(r.body, "question_id"));
          Map<String, Object> previous =
              d.one(
                  "SELECT * FROM answers WHERE attempt_id=? AND question_id=?", r.p(), q.get("id"));
          boolean late = t.get("deadline") != null && now() > num(t, "deadline");
          String answer = text(r.body, "answer", 0, 4000);
          boolean correct = !late && correct(q, answer);
          if (previous == null)
            d.insert(
                "answers",
                map(
                    "attempt_id",
                    r.p(),
                    "question_id",
                    q.get("id"),
                    "answer",
                    late ? "" : answer,
                    "correct",
                    correct ? 1 : 0,
                    "answered",
                    now()));
          else correct = num(previous, "correct") == 1;
          return map(
              "correct",
              correct,
              "accepted",
              q.get("accepted"),
              "explanation",
              q.get("explanation"),
              "late",
              late);
        });
    a.add(
        "POST",
        "/api/attempts/{id}/finish",
        "student",
        true,
        "{discard?:boolean}",
        "{attempt,questions,answers,wallet}",
        "",
        r -> {
          Map<String, Object> t =
              d.need("SELECT * FROM attempts WHERE id=? AND user_id=?", r.p(), r.uid());
          finish(t, yes(r.body, "discard"));
          return attemptView(d.need("SELECT * FROM attempts WHERE id=?", r.p()));
        });
    a.add(
        "POST",
        "/api/quizzes/{id}/offline",
        "student",
        true,
        "{id,version,started,ended,timed,answers:[{question_id,answer,elapsed}]}",
        "{attempt,questions,answers,wallet}",
        "CONTENT_CHANGED,VALIDATION",
        r -> {
          Map<String, Object> quiz = c.quiz(r.p(), r.uid());
          String id = text(r.body, "id", 16, 80);
          Map<String, Object> old =
              d.one("SELECT * FROM attempts WHERE id=? AND user_id=?", id, r.uid());
          if (old != null) return attemptView(old);
          require(
              num(r.body, "version") == num(quiz, "version"),
              409,
              "CONTENT_CHANGED",
              "This saved quiz changed. Preserve the local result and download the current"
                  + " revision.");
          double started = num(r.body, "started"), ended = num(r.body, "ended");
          require(
              started <= ended && ended <= now() + 120 && started >= now() - 30 * 86400,
              422,
              "VALIDATION",
              "Invalid attempt dates.");
          List<Map<String, Object>> qs = c.questions(r.p());
          double duration = quiz.get("duration") == null ? qs.size() * 60 : num(quiz, "duration");
          d.insert(
              "attempts",
              map(
                  "id",
                  id,
                  "user_id",
                  r.uid(),
                  "quiz_id",
                  r.p(),
                  "state",
                  "active",
                  "started",
                  started,
                  "deadline",
                  yes(r.body, "timed") ? started + duration : null,
                  "question_order",
                  json(qs.stream().map(q -> q.get("id")).toList()),
                  "total",
                  qs.size(),
                  "snapshot",
                  json(qs),
                  "offline",
                  1));
          Set<String> seen = new HashSet<>();
          for (Map<String, Object> answer : rows(json(r.body.get("answers")))) {
            Map<String, Object> q = findQuestion(qs, str(answer, "question_id"));
            require(seen.add(str(q, "id")), 422, "VALIDATION", "Duplicate answer.");
            double elapsed = num(answer, "elapsed");
            require(
                elapsed >= 0 && elapsed <= ended - started + 5,
                422,
                "VALIDATION",
                "Invalid answer timing.");
            boolean late = yes(r.body, "timed") && elapsed > duration;
            d.insert(
                "answers",
                map(
                    "attempt_id",
                    id,
                    "question_id",
                    q.get("id"),
                    "answer",
                    text(answer, "answer", 0, 4000),
                    "correct",
                    !late && correct(q, str(answer, "answer")) ? 1 : 0,
                    "answered",
                    started + elapsed));
          }
          finish(d.need("SELECT * FROM attempts WHERE id=?", id), false);
          return attemptView(d.need("SELECT * FROM attempts WHERE id=?", id));
        });
    a.add(
        "GET",
        "/api/progress",
        "student",
        false,
        "—",
        "{topics:[{mastery,evidence_count,label,confidence,suggested_minutes}],history,wallet,streak,today_minutes,week_minutes,badges,levels_enabled}",
        "",
        r -> {
          List<Map<String, Object>> topics = new ArrayList<>();
          for (Map<String, Object> topic : d.all("SELECT * FROM topics")) {
            List<Map<String, Object>> events =
                d.all(
                    "SELECT * FROM evidence WHERE user_id=? AND topic_id=? AND occurred>? ORDER BY"
                        + " occurred DESC LIMIT 100",
                    r.uid(),
                    topic.get("id"),
                    now() - 90 * 86400);
            double total = 0, correct = 0;
            for (Map<String, Object> event : events) {
              double w =
                  num(event, "weight") * Math.exp(-(now() - num(event, "occurred")) / (30 * 86400));
              total += w;
              correct += w * num(event, "correct");
            }
            topic.put("mastery", total == 0 ? null : Math.round(100 * correct / total));
            topic.put("evidence_count", events.size());
            topic.put(
                "confidence", events.size() < 5 ? "Low evidence" : "Established practice evidence");
            topic.put(
                "label",
                total == 0
                    ? "Not assessed"
                    : correct / total < 0.5
                        ? "Needs review"
                        : correct / total < 0.8 ? "Developing" : "Strong");
            topic.put("suggested_minutes", total > 0 && correct / total < 0.5 ? 25 : 10);
            topics.add(topic);
          }
          topics.sort(
              Comparator.comparingDouble(t -> t.get("mastery") == null ? 101 : num(t, "mastery")));
          String today = LocalDate.now(ZoneId.of(str(r.user, "timezone"))).toString();
          double start =
              LocalDate.parse(today)
                  .atStartOfDay(ZoneId.of(str(r.user, "timezone")))
                  .toEpochSecond();
          return map(
              "topics",
              topics,
              "history",
              d.all(
                  "SELECT started,score,total,quiz_id FROM attempts WHERE user_id=? AND"
                      + " state='completed' ORDER BY started DESC LIMIT 50",
                  r.uid()),
              "wallet",
              e.wallet(r.uid()),
              "streak",
              streak(r.uid(), today),
              "today_minutes",
              d.scalar(
                  "SELECT sum(credited) FROM study_sessions WHERE user_id=? AND started>=?",
                  r.uid(),
                  start),
              "week_minutes",
              d.scalar(
                  "SELECT sum(credited) FROM study_sessions WHERE user_id=? AND started>=?",
                  r.uid(),
                  start - 6 * 86400),
              "badges",
              d.all("SELECT badge,earned FROM badges WHERE user_id=?", r.uid()),
              "levels_enabled",
              d.flag("levels"));
        });
  }

  Map<String, Object> safeSession(Map<String, Object> s) {
    s.remove("notes_cipher");
    return s;
  }

  void expireSessions(String uid) {
    d.exec(
        "UPDATE study_sessions SET state='uncredited',ended=?,reason='No heartbeat for four hours'"
            + " WHERE user_id=? AND state IN ('running','paused') AND last_heartbeat<?",
        now(),
        uid,
        now() - 14400);
  }

  void sessionReward(String uid, String id, int minutes, double started, String timezone) {
    String day =
        Instant.ofEpochSecond((long) started).atZone(ZoneId.of(timezone)).toLocalDate().toString();
    e.award(
        uid,
        "session:" + id,
        minutes,
        minutes / 5,
        "One XP per study minute and one coin per five minutes; daily caps apply");
    d.exec("INSERT OR IGNORE INTO streak_days VALUES(?,?,?,?)", uid, day, "study", now());
    d.exec("INSERT OR IGNORE INTO badges VALUES(?,?,?)", uid, "First focus", now());
    LocalDate previous = LocalDate.parse(day).minusDays(2);
    if (d.scalar(
                "SELECT count(*) FROM streak_days WHERE user_id=? AND day=?",
                uid,
                previous.toString())
            > 0
        && d.scalar(
                "SELECT count(*) FROM streak_days WHERE user_id=? AND kind='grace' AND created>?",
                uid,
                now() - 30 * 86400)
            == 0)
      d.exec(
          "INSERT OR IGNORE INTO streak_days VALUES(?,?,?,?)",
          uid,
          previous.plusDays(1).toString(),
          "grace",
          now());
  }

  void evidence(String uid, String topic, double correct, double weight, String origin) {
    d.insert(
        "evidence",
        map(
            "id",
            id(),
            "user_id",
            uid,
            "topic_id",
            topic,
            "correct",
            correct,
            "weight",
            weight,
            "occurred",
            now(),
            "origin",
            origin));
  }

  int streak(String uid, String today) {
    LocalDate day = LocalDate.parse(today);
    if (d.scalar("SELECT count(*) FROM streak_days WHERE user_id=? AND day=?", uid, day.toString())
        == 0) day = day.minusDays(1);
    int n = 0;
    while (n < 4000
        && d.scalar(
                "SELECT count(*) FROM streak_days WHERE user_id=? AND day=?", uid, day.toString())
            > 0) {
      n++;
      day = day.minusDays(1);
    }
    return n;
  }

  static boolean correct(Map<String, Object> q, String answer) {
    for (Object accepted : (List<?>) q.get("accepted"))
      if (normalized(accepted.toString()).equals(normalized(answer))) return true;
    return false;
  }

  static Map<String, Object> findQuestion(List<Map<String, Object>> qs, String id) {
    return qs.stream()
        .filter(q -> str(q, "id").equals(id))
        .findFirst()
        .orElseThrow(
            () -> new Fault(404, "QUESTION_NOT_FOUND", "Question is not part of this attempt."));
  }

  Map<String, Object> attemptView(Map<String, Object> t) {
    List<Map<String, Object>> qs = rows(str(t, "snapshot"));
    t.remove("snapshot");
    return map(
        "attempt",
        t,
        "questions",
        qs,
        "answers",
        d.all("SELECT * FROM answers WHERE attempt_id=?", t.get("id")),
        "wallet",
        e.wallet(str(t, "user_id")));
  }

  void finish(Map<String, Object> t, boolean discard) {
    if (!str(t, "state").equals("active")) return;
    int score = (int) d.scalar("SELECT sum(correct) FROM answers WHERE attempt_id=?", t.get("id"));
    boolean fast = now() - num(t, "started") < num(t, "total") * 0.3;
    String state = discard ? "discarded" : "completed";
    d.exec(
        "UPDATE attempts SET state=?,ended=?,score=?,flagged=? WHERE id=?",
        state,
        now(),
        score,
        fast ? "Unusually fast; reward withheld" : "",
        t.get("id"));
    if (discard) return;
    String uid = str(t, "user_id"), id = str(t, "id");
    List<Map<String, Object>> qs = rows(str(t, "snapshot"));
    if (fast) {
      d.insert(
          "risk_events",
          map("id", id(), "user_id", uid, "signal", "fast_quiz", "evidence", id, "created", now()));
      return;
    }
    for (Map<String, Object> q : qs) {
      double v =
          d.scalar(
              "SELECT correct FROM answers WHERE attempt_id=? AND question_id=?", id, q.get("id"));
      evidence(uid, str(q, "topic_id"), v, 1, "quiz:" + id);
    }
    double oldBest =
        d.scalar(
            "SELECT max(score) FROM attempts WHERE user_id=? AND quiz_id=? AND state='completed'"
                + " AND id!=? AND flagged=''",
            uid,
            t.get("quiz_id"),
            id);
    int improvement = Math.max(0, score - (int) oldBest);
    if (improvement > 0)
      e.award(uid, "quiz:" + id, improvement * 5, improvement * 2, "Quiz accuracy improvement");
    d.exec("INSERT OR IGNORE INTO badges VALUES(?,?,?)", uid, "First quiz", now());
    double n = d.scalar("SELECT count(*) FROM evidence WHERE user_id=?", uid);
    if (n >= 10) {
      double mastery =
          d.scalar(
              "SELECT avg(correct) FROM (SELECT correct FROM evidence WHERE user_id=? ORDER BY"
                  + " occurred DESC LIMIT 50)",
              uid);
      int band = mastery < 0.4 ? 0 : mastery < 0.65 ? 1 : mastery < 0.85 ? 2 : 3;
      d.exec("UPDATE users SET band=max(band,?),band_evidence=? WHERE id=?", band, (int) n, uid);
    }
  }
}
