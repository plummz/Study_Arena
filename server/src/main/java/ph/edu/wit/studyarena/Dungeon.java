package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.io.IOException;
import java.nio.file.*;
import java.util.*;

final class Dungeon {
  private final Path project;
  private final Api a;
  private final Db d;
  private final Economy economy;
  private Process game;

  Dungeon(Api a, Economy economy) {
    this.a = a;
    this.d = a.db;
    this.economy = economy;
    project = a.web.getParent().resolve("godot").resolve("dungeon_maze").normalize();
    a.add(
        "POST",
        "/api/dungeon/launch",
        "public",
        false,
        "{companion:moss|lumi|coral|sky|plum|sunny|mint|nova|ember|bubbles|byte|clover|mochi|comet|pebble|melody|taro|sol,difficulty:easy|average|hard|hell,run_id?,ticket?}",
        "{launched,already_running,companion,difficulty}",
        "VALIDATION,DUNGEON_UNAVAILABLE,DUNGEON_LAUNCH_FAILED",
        r -> launch(r));
    a.add("POST", "/api/dungeon/runs", "student", false,
        "{difficulty:easy|average|hard|hell,companion}",
        "{run_id,ticket,expires_at,difficulty,question_count,hint_cost,time_limit_seconds,mistake_limit,source}",
        "VALIDATION,FEATURE_DISABLED", this::create);
    a.add("GET", "/api/dungeon/runs/{run_id}/questions", "dungeon", false, "-",
        "{run_id,questions:[{index,prompt,options,subject,source}],state}",
        "RUN_NOT_FOUND,TICKET_INVALID", this::questions);
    a.add("POST", "/api/dungeon/runs/{run_id}/answer", "dungeon", false,
        "{index,choice}", "{index,correct,correct_choice,explanation,coins_awarded,mercy_token,cap_reached,flagged_fast,state}",
        "VALIDATION,RUN_NOT_FOUND,TICKET_INVALID,RUN_CLOSED,RATE_LIMITED", this::answer);
    a.add("POST", "/api/dungeon/runs/{run_id}/hint", "dungeon", false,
        "{index}", "{index,removed_choices,coins_spent,wallet_balance}",
        "VALIDATION,RUN_NOT_FOUND,TICKET_INVALID,RUN_CLOSED,INSUFFICIENT_COINS,RATE_LIMITED", this::hint);
    a.add("POST", "/api/dungeon/runs/{run_id}/finish", "dungeon", false,
        "{outcome:victory|lost|abandoned|timeout}",
        "{run_id,outcome,answered,correct_count,coins_awarded,duration_seconds}",
        "VALIDATION,RUN_NOT_FOUND,TICKET_INVALID,RUN_CLOSED", this::finish);
  }

  private synchronized Object launch(Api.Request r) {
    Map<String, Object> body = r.body;
    String companion =
        choice(body, "companion", "moss", "lumi", "coral", "sky", "plum", "sunny", "mint", "nova", "ember", "bubbles", "byte", "clover", "mochi", "comet", "pebble", "melody", "taro", "sol");
    String difficulty = choice(body, "difficulty", "easy", "average", "hard", "hell");
    String runId = str(body, "run_id"), ticket = str(body, "ticket");
    require(runId.isEmpty() == ticket.isEmpty(), 422, "VALIDATION", "Run and ticket must be supplied together.");
    if (!runId.isEmpty()) {
      require(runId.matches("[0-9a-fA-F-]{36}") && ticket.matches("[A-Za-z0-9_-]{43}"),
          422, "VALIDATION", "Invalid run credentials.");
      require(r.user != null && d.one("SELECT id FROM dungeon_runs WHERE id=? AND user_id=? AND ticket_hash=? AND ticket_expires>? AND state='active' AND difficulty=? AND companion=?",
          runId, r.uid(), hash(ticket), now(), difficulty, companion) != null,
          401, "TICKET_INVALID", "Invalid dungeon ticket.");
    }
    require(
        Files.isRegularFile(project.resolve("project.godot")),
        409,
        "DUNGEON_UNAVAILABLE",
        "The local dungeon module is not installed.");
    if (game != null && game.isAlive()) {
      if (runId.isEmpty())
        return map("launched", true, "already_running", true,
            "companion", companion, "difficulty", difficulty);
      game.destroyForcibly();
      game = null;
    }
    Path godot = findGodot();
    require(
        godot != null,
        409,
        "DUNGEON_UNAVAILABLE",
        "Godot was not found. Keep the downloaded Godot folder in Downloads.");
    try {
      copyCompanionAssets();
      List<String> command = new ArrayList<>(List.of(godot.toString(), "--path", project.toString(), "--",
          "--companion=" + companion, "--difficulty=" + difficulty));
      if (!runId.isEmpty()) command.addAll(List.of("--run=" + runId, "--ticket=" + ticket,
          "--api=http://localhost:" + System.getenv().getOrDefault("PORT", "8080")));
      game =
          new ProcessBuilder(command)
              .directory(project.toFile())
              .redirectOutput(ProcessBuilder.Redirect.DISCARD)
              .redirectError(ProcessBuilder.Redirect.DISCARD)
              .start();
      return map(
          "launched", true,
          "already_running", false,
          "companion", companion,
          "difficulty", difficulty);
    } catch (IOException e) {
      throw new Fault(500, "DUNGEON_LAUNCH_FAILED", "The dungeon could not be opened.");
    }
  }

  private Object create(Api.Request r) {
    require(str(r.user, "role").equals("student") && num(r.user, "competition") == 1 && d.flag("competition"),
        403, "FEATURE_DISABLED", "Saved dungeon runs require competition to be enabled.");
    String difficulty = choice(r.body, "difficulty", "easy", "average", "hard", "hell");
    String companion = choice(r.body, "companion", "moss", "lumi", "coral", "sky", "plum", "sunny", "mint", "nova", "ember", "bubbles", "byte", "clover", "mochi", "comet", "pebble", "melody", "taro", "sol");
    int level = List.of("easy", "average", "hard", "hell").indexOf(difficulty);
    // Question count scales with difficulty (capped at 50); the game sizes its maze to match.
    int[] counts = {20, 30, 40, 50}, seconds = {480, 720, 960, 1200}, mistakes = {5, 5, 4, 3};
    int count = counts[level];
    double at = now(), expires = at + 6 * 3600;
    d.exec("UPDATE dungeon_runs SET state='expired',ended=? WHERE user_id=? AND state='active' AND (ticket_expires<=? OR started+time_limit_seconds<=?)", at, r.uid(), at, at);
    d.exec("UPDATE dungeon_runs SET state='abandoned',ended=? WHERE user_id=? AND state='active'", at, r.uid());
    String run = id(), ticket = token();
    List<Question> selected = libraryQuestions(r, count * 7 / 10);
    selected.addAll(flashcardQuestions(r, count - selected.size()));
    int libraryCount = Math.min(count, selected.size());
    while (selected.size() < count) selected.add(practice(selected.size()));
    String source = libraryCount == count ? "library" : libraryCount == 0 ? "practice" : "mixed";
    d.exec("INSERT INTO dungeon_runs(id,user_id,ticket_hash,ticket_expires,difficulty,companion,state,started,time_limit_seconds,mistake_limit,hint_cost,source) VALUES(?,?,?,?,?,?,'active',?,?,?,?,?)",
        run, r.uid(), hash(ticket), expires, difficulty, companion, at, seconds[level], mistakes[level], level + 2, source);
    for (int i = 0; i < selected.size(); i++) {
      Question q = selected.get(i);
      d.exec("INSERT INTO dungeon_run_questions(run_id,idx,prompt,options,correct_choice,explanation,subject,source) VALUES(?,?,?,?,?,?,?,?)",
          run, i, q.prompt, json(q.options), q.correct, q.explanation, q.subject, q.source);
    }
    return map("run_id", run, "ticket", ticket, "expires_at", expires, "difficulty", difficulty,
        "question_count", count, "hint_cost", level + 2, "time_limit_seconds", seconds[level],
        "mistake_limit", mistakes[level], "source", source);
  }

  private record Question(String prompt, List<String> options, int correct, String explanation, String subject, String source) {}

  private List<Question> libraryQuestions(Api.Request r, int limit) {
    Set<String> preferred = new HashSet<>();
    for (Object value : list(str(r.user, "subjects"))) preferred.add(value.toString());
    List<Map<String, Object>> rows = d.all(
        "SELECT q.*,t.subject,t.id AS subject_id FROM questions q JOIN quizzes z ON z.id=q.quiz_id JOIN topics t ON t.id=q.topic_id WHERE z.status='approved' AND q.kind IN ('mcq','boolean') AND length(trim(q.explanation))>0");
    Collections.shuffle(rows, RANDOM);
    rows.sort(Comparator.comparingInt(x -> preferred.contains(str(x, "subject_id")) ? 0 : 1));
    List<Question> out = new ArrayList<>();
    for (Map<String, Object> row : rows) {
      if (out.size() >= limit) break;
      List<Object> options = list(str(row, "options")), accepted = list(str(row, "accepted"));
      if (options.size() < 2 || options.size() > 4 || accepted.size() != 1 || !options.contains(accepted.get(0))) continue;
      if (options.size() == 2 && !str(row, "kind").equals("boolean")) continue;
      List<String> shuffled = new ArrayList<>();
      for (Object option : options) shuffled.add(option.toString());
      // True/false keeps its natural order; multiple choice is shuffled.
      if (!str(row, "kind").equals("boolean")) Collections.shuffle(shuffled, RANDOM);
      out.add(new Question(str(row, "prompt"), shuffled, shuffled.indexOf(accepted.get(0).toString()),
          str(row, "explanation"), str(row, "subject"), "quiz"));
    }
    return out;
  }

  /** Flashcards from the student's own decks and approved public decks, as 4-choice questions
   *  whose distractors are other answers from the same deck. */
  private List<Question> flashcardQuestions(Api.Request r, int wanted) {
    List<Question> out = new ArrayList<>();
    if (wanted <= 0) return out;
    List<Map<String, Object>> rows = d.all(
        "SELECT c.deck_id,c.front,c.back,t.subject FROM cards c JOIN decks k ON k.id=c.deck_id JOIN topics t ON t.id=k.topic_id "
            + "WHERE (k.owner_id=? OR (k.visibility='public' AND k.status='approved')) AND length(c.back)<=120 AND length(c.front)<=300",
        r.uid());
    Map<String, List<Map<String, Object>>> byDeck = new HashMap<>();
    for (Map<String, Object> row : rows) byDeck.computeIfAbsent(str(row, "deck_id"), k -> new ArrayList<>()).add(row);
    Collections.shuffle(rows, RANDOM);
    Set<String> seen = new HashSet<>();
    for (Map<String, Object> row : rows) {
      if (out.size() >= wanted) break;
      String front = str(row, "front").trim(), back = str(row, "back").trim();
      if (front.isEmpty() || back.isEmpty() || !seen.add(front.toLowerCase(Locale.ROOT))) continue;
      List<String> distractors = new ArrayList<>();
      for (Map<String, Object> other : byDeck.get(str(row, "deck_id"))) {
        String option = str(other, "back").trim();
        if (!option.isEmpty() && !option.equalsIgnoreCase(back) && distractors.stream().noneMatch(option::equalsIgnoreCase)) distractors.add(option);
      }
      if (distractors.size() < 3) continue;
      Collections.shuffle(distractors, RANDOM);
      List<String> options = new ArrayList<>(distractors.subList(0, 3));
      options.add(back);
      Collections.shuffle(options, RANDOM);
      out.add(new Question(front, options, options.indexOf(back), "Flashcard answer: " + back, str(row, "subject"), "flashcard"));
    }
    return out;
  }

  private Question practice(int index) {
    int tier = 1 + index / 25;
    int a = 3 + RANDOM.nextInt(12 * tier), b = 2 + RANDOM.nextInt(9 * tier);
    int answer;
    String prompt;
    switch (index % 4) {
      case 0 -> { answer = a + b; prompt = "What is " + a + " + " + b + "?"; }
      case 1 -> { answer = a; prompt = "What is " + (a + b) + " - " + b + "?"; }
      case 2 -> { answer = a * b; prompt = "What is " + a + " x " + b + "?"; }
      default -> { answer = a; prompt = "What is " + (a * b) + " / " + b + "?"; }
    }
    Set<Integer> values = new LinkedHashSet<>();
    values.add(answer);
    for (int offset = 1; values.size() < 4; offset++) {
      values.add(answer + offset * tier);
      if (answer - offset * tier >= 0) values.add(answer - offset * tier);
    }
    List<String> options = values.stream().limit(4).map(String::valueOf).collect(java.util.stream.Collectors.toCollection(ArrayList::new));
    Collections.shuffle(options, RANDOM);
    return new Question(prompt, options, options.indexOf(String.valueOf(answer)),
        "The answer is " + answer + ".", "Arithmetic", "practice");
  }

  private Map<String, Object> run(Api.Request r) {
    Map<String, Object> run = d.one("SELECT * FROM dungeon_runs WHERE id=? AND user_id=?", r.p(), r.uid());
    require(run != null, 404, "RUN_NOT_FOUND", "Dungeon run not found.");
    double at = now();
    if (str(run, "state").equals("active") && (num(run, "ticket_expires") <= at || num(run, "started") + num(run, "time_limit_seconds") <= at)) {
      d.exec("UPDATE dungeon_runs SET state='expired',ended=? WHERE id=?", at, r.p());
      run.put("state", "expired");
    }
    return run;
  }

  private Map<String, Object> active(Api.Request r) {
    Map<String, Object> run = run(r);
    require(str(run, "state").equals("active"), 409, "RUN_CLOSED", "This dungeon run has ended.");
    return run;
  }

  private Map<String, Object> question(Api.Request r, int index) {
    Map<String, Object> q = d.one("SELECT * FROM dungeon_run_questions WHERE run_id=? AND idx=?", r.p(), index);
    require(q != null, 422, "VALIDATION", "Invalid question index.");
    return q;
  }

  private Object questions(Api.Request r) {
    run(r);
    List<Map<String, Object>> rows = d.all("SELECT idx,prompt,options,subject,source FROM dungeon_run_questions WHERE run_id=? ORDER BY idx", r.p());
    List<Object> visible = new ArrayList<>();
    for (Map<String, Object> q : rows) visible.add(map("index", q.get("idx"), "prompt", q.get("prompt"),
        "options", list(str(q, "options")), "subject", q.get("subject"), "source", q.get("source")));
    d.exec("UPDATE dungeon_run_questions SET served_at=coalesce(served_at,?) WHERE run_id=?", now(), r.p());
    List<Object> answered = d.all("SELECT idx FROM dungeon_run_questions WHERE run_id=? AND answered_at IS NOT NULL ORDER BY idx", r.p())
        .stream().map(x -> x.get("idx")).toList();
    Map<String, Object> run = run(r);
    return map("run_id", r.p(), "questions", visible, "state", map("answered_indexes", answered,
        "coins_awarded", run.get("coins_awarded"), "mistakes_used", run.get("mistakes_used")));
  }

  private Map<String, Object> answerState(Map<String, Object> run) {
    Map<String, Object> counts = d.one("SELECT count(answered_at) AS answered,coalesce(sum(correct),0) AS correct_count FROM dungeon_run_questions WHERE run_id=?", run.get("id"));
    return map("answered", counts.get("answered"), "correct_count", counts.get("correct_count"),
        "mistakes_used", run.get("mistakes_used"),
        "mistakes_left", Math.max(0, (int) (num(run, "mistake_limit") + num(run, "mercy_tokens") - num(run, "mistakes_used"))),
        "coins_total_this_run", run.get("coins_awarded"));
  }

  private Object answer(Api.Request r) {
    int index = integer(r.body, "index", 0, 49, -1);
    require(index >= 0, 422, "VALIDATION", "Question index is required.");
    Map<String, Object> run = run(r), q = question(r, index);
    int choice = integer(r.body, "choice", 0, list(str(q, "options")).size() - 1, -1);
    require(choice >= 0, 422, "VALIDATION", "Choice is required.");
    if (q.get("answered_at") != null) return obj(str(q, "answer_response"));
    d.rate("dungeon:" + r.p(), 3, 1);
    require(str(run, "state").equals("active"), 409, "RUN_CLOSED", "This dungeon run has ended.");
    require(q.get("served_at") != null, 409, "RUN_CLOSED", "Fetch the questions before answering.");
    double at = now();
    boolean correct = choice == (int) num(q, "correct_choice");
    boolean fast = at - num(q, "served_at") < 1.5 ||
        (run.get("last_answer_at") != null && at - num(run, "last_answer_at") < 1.5);
    boolean cap = false;
    int awarded = 0, mercy = 0;
    if (correct) {
      cap = d.scalar("SELECT coalesce(sum(coins),0) FROM ledger WHERE user_id=? AND origin LIKE 'dungeon_answer:%' AND created>=?", r.uid(), at - 86400) >= 100;
      if (!fast && !cap) {
        economy.ledger(r.uid(), 0, 1, "dungeon_answer:" + r.p() + ":" + index, "dungeon_answer", r.uid());
        awarded = 1;
      }
      if (RANDOM.nextInt(20) == 0) mercy = 1;
    }
    d.exec("UPDATE dungeon_run_questions SET answered_at=?,choice=?,correct=?,coins_awarded=?,flagged_fast=?,mercy_token=? WHERE run_id=? AND idx=?",
        at, choice, correct ? 1 : 0, awarded, fast ? 1 : 0, mercy, r.p(), index);
    d.exec("UPDATE dungeon_runs SET mistakes_used=mistakes_used+?,mercy_tokens=mercy_tokens+?,coins_awarded=coins_awarded+?,last_answer_at=? WHERE id=?",
        correct ? 0 : 1, mercy, awarded, at, r.p());
    run = d.one("SELECT * FROM dungeon_runs WHERE id=?", r.p());
    if (num(run, "mistakes_used") >= num(run, "mistake_limit") + num(run, "mercy_tokens")) {
      d.exec("UPDATE dungeon_runs SET state='lost',ended=? WHERE id=?", at, r.p());
      run.put("state", "lost");
    }
    Object result = answerResult(run, d.one("SELECT * FROM dungeon_run_questions WHERE run_id=? AND idx=?", r.p(), index));
    d.exec("UPDATE dungeon_run_questions SET answer_response=? WHERE run_id=? AND idx=?", json(result), r.p(), index);
    return result;
  }

  private Object answerResult(Map<String, Object> run, Map<String, Object> q) {
    return map("index", q.get("idx"), "correct", num(q, "correct") == 1,
        "correct_choice", q.get("correct_choice"), "explanation", q.get("explanation"),
        "coins_awarded", q.get("coins_awarded"), "mercy_token", num(q, "mercy_token") == 1,
        "cap_reached", num(q, "correct") == 1 && num(q, "coins_awarded") == 0 && num(q, "flagged_fast") == 0,
        "flagged_fast", num(q, "flagged_fast") == 1, "state", answerState(run));
  }

  private Object hint(Api.Request r) {
    int index = integer(r.body, "index", 0, 49, -1);
    require(index >= 0, 422, "VALIDATION", "Question index is required.");
    Map<String, Object> run = run(r), q = question(r, index);
    if (q.get("hint_removed") != null) return obj(str(q, "hint_response"));
    d.rate("dungeon:" + r.p(), 3, 1);
    require(str(run, "state").equals("active") && q.get("answered_at") == null,
        409, "RUN_CLOSED", "Hint is unavailable for this question.");
    int cost = (int) num(run, "hint_cost");
    require(num(economy.wallet(r.uid()), "coins") >= cost, 409, "INSUFFICIENT_COINS", "You need more dungeon coins for a hint.");
    List<Integer> wrong = new ArrayList<>();
    for (int i = 0; i < list(str(q, "options")).size(); i++) if (i != (int) num(q, "correct_choice")) wrong.add(i);
    require(wrong.size() >= 2, 422, "VALIDATION", "This question has too few choices for a hint.");
    Collections.shuffle(wrong, RANDOM);
    List<Integer> removed = wrong.subList(0, 2);
    economy.ledger(r.uid(), 0, -cost, "dungeon_hint:" + r.p() + ":" + index, "dungeon_hint", r.uid());
    d.exec("UPDATE dungeon_run_questions SET hint_removed=? WHERE run_id=? AND idx=?", json(removed), r.p(), index);
    Object result = map("index", index, "removed_choices", removed, "coins_spent", cost,
        "wallet_balance", economy.wallet(r.uid()).get("coins"));
    d.exec("UPDATE dungeon_run_questions SET hint_response=? WHERE run_id=? AND idx=?", json(result), r.p(), index);
    return result;
  }

  private Object finish(Api.Request r) {
    String requested = choice(r.body, "outcome", "victory", "lost", "abandoned", "timeout");
    Map<String, Object> run = run(r);
    if (str(run, "state").equals("active")) {
      Map<String, Object> counts = d.one("SELECT count(*) AS total,count(answered_at) AS answered,coalesce(sum(correct),0) AS correct_count FROM dungeon_run_questions WHERE run_id=?", r.p());
      // Every question is single-attempt, so a run is won once all are answered without losing.
      String state = requested.equals("victory") && num(counts, "answered") == num(counts, "total") ? "won" : requested.equals("timeout") ? "expired" : "abandoned";
      d.exec("UPDATE dungeon_runs SET state=?,ended=? WHERE id=?", state, now(), r.p());
      run = d.one("SELECT * FROM dungeon_runs WHERE id=?", r.p());
    }
    Map<String, Object> counts = d.one("SELECT count(answered_at) AS answered,coalesce(sum(correct),0) AS correct_count FROM dungeon_run_questions WHERE run_id=?", r.p());
    String state = str(run, "state");
    return map("run_id", r.p(), "outcome", state.equals("won") ? "victory" : state.equals("expired") ? "timeout" : state,
        "answered", counts.get("answered"), "correct_count", counts.get("correct_count"),
        "coins_awarded", run.get("coins_awarded"),
        "duration_seconds", Math.max(0, (int) (num(run, "ended") - num(run, "started"))));
  }

  private void copyCompanionAssets() throws IOException {
    Path source = project.getParent().getParent().resolve("web").resolve("assets").resolve("companions");
    Path destination = project.resolve("assets").resolve("companions");
    Files.createDirectories(destination);
    for (String id : List.of("moss", "lumi", "coral", "sky", "plum", "sunny", "mint", "nova", "ember", "bubbles", "byte", "clover", "mochi", "comet", "pebble", "melody", "taro", "sol")) {
      Path image = source.resolve(id + ".png");
      if (Files.isRegularFile(image))
        Files.copy(image, destination.resolve(image.getFileName()), StandardCopyOption.REPLACE_EXISTING);
    }
  }

  private Path findGodot() {
    String configured = System.getenv("GODOT_EXE");
    if (configured != null && !configured.isBlank()) {
      Path candidate = Path.of(configured).toAbsolutePath().normalize();
      if (Files.isRegularFile(candidate)) return candidate;
    }
    Path downloads = Path.of(System.getProperty("user.home"), "Downloads").normalize();
    if (!Files.isDirectory(downloads)) return null;
    try (var entries = Files.list(downloads)) {
      for (Path entry : entries.filter(Files::isDirectory).sorted().toList()) {
        String folder = entry.getFileName().toString();
        if (!folder.matches("Godot_v[0-9.]+-stable_win64\\.exe")) continue;
        Path executable = entry.resolve(folder);
        if (Files.isRegularFile(executable)) return executable;
      }
    } catch (IOException ignored) {
    }
    return null;
  }
}
