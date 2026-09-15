package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.nio.*;
import java.nio.file.*;
import java.util.*;

final class Content {
  final Api a;
  final Db d;

  Content(Api a) {
    this.a = a;
    d = a.db;
    a.add(
        "GET",
        "/api/topics",
        "public",
        false,
        "—",
        "{items:[Topic]}",
        "",
        r -> map("items", d.all("SELECT * FROM topics ORDER BY course,subject,title")));
    a.add(
        "GET",
        "/api/decks",
        "public",
        false,
        "?q=&topic=&offset=&limit=",
        "{items:[Deck]}",
        "",
        r ->
            map(
                "items",
                d.all(
                    "SELECT x.*, (SELECT count(*) FROM cards WHERE deck_id=x.id) AS card_count FROM"
                        + " decks x WHERE (status='approved' AND visibility='public' OR owner_id=?)"
                        + " AND title LIKE ? AND (?='' OR topic_id=?) ORDER BY updated DESC LIMIT ?"
                        + " OFFSET ?",
                    r.user == null ? "" : r.uid(),
                    "%" + r.q("q") + "%",
                    r.q("topic"),
                    r.q("topic"),
                    r.limit(),
                    r.offset())));
    a.add(
        "GET",
        "/api/decks/{id}",
        "public",
        false,
        "?offset=&limit=",
        "{deck,cards:[Card],total}",
        "NOT_FOUND",
        r -> {
          Map<String, Object> deck = deck(r.p(), r.user == null ? "" : r.uid());
          return map(
              "deck",
              deck,
              "cards",
              d.all(
                  "SELECT c.*,s.due,s.interval_days FROM cards c LEFT JOIN card_schedule s ON"
                      + " s.card_id=c.id AND s.user_id=? WHERE c.deck_id=? ORDER BY position LIMIT"
                      + " ? OFFSET ?",
                  r.user == null ? "" : r.uid(),
                  r.p(),
                  r.limit(),
                  r.offset()),
              "total",
              d.scalar("SELECT count(*) FROM cards WHERE deck_id=?", r.p()));
        });
    a.add(
        "POST",
        "/api/decks",
        "student",
        true,
        "{title,topic_id,cards:[{front,back,image_id?,image_alt?}],source?,license?}",
        "{deck}",
        "VALIDATION,DUPLICATE_CARD",
        r -> {
          String id = str(r.body, "id").isBlank() ? id() : text(r.body, "id", 36, 36);
          require(
              d.one("SELECT id FROM decks WHERE id=?", id) == null,
              409,
              "VERSION_CONFLICT",
              "This deck already exists.");
          saveDeck(r, id, false);
          return map("deck", d.need("SELECT * FROM decks WHERE id=?", id));
        });
    a.add(
        "PUT",
        "/api/decks/{id}",
        "student",
        true,
        "{version,title,topic_id,cards:[Card],source?,license?,allow_duplicates?}",
        "{deck,conflict_copy?}",
        "FORBIDDEN,VALIDATION",
        r -> {
          Map<String, Object> old = d.need("SELECT * FROM decks WHERE id=?", r.p());
          r.owner(old);
          if (integer(r.body, "version", 1, Integer.MAX_VALUE, 0) != num(old, "version")) {
            String copy = id();
            saveDeck(r, copy, false);
            return map(
                "deck",
                d.need("SELECT * FROM decks WHERE id=?", copy),
                "conflict_copy",
                true,
                "message",
                "A concurrent edit was preserved as a private conflict copy.");
          }
          saveDeck(r, r.p(), true);
          return map("deck", d.need("SELECT * FROM decks WHERE id=?", r.p()));
        });
    a.add(
        "DELETE",
        "/api/decks/{id}",
        "student",
        true,
        "{}",
        "{ok}",
        "FORBIDDEN",
        r -> {
          Map<String, Object> deck = d.need("SELECT * FROM decks WHERE id=?", r.p());
          r.owner(deck);
          d.exec("DELETE FROM room_resources WHERE kind='deck' AND resource_id=?", r.p());
          d.exec("DELETE FROM decks WHERE id=?", r.p());
          return map("ok", true);
        });
    a.add(
        "POST",
        "/api/decks/{id}/share",
        "student",
        true,
        "{visibility:'public'|'room'|'private',room_id?,source,license}",
        "{deck}",
        "FORBIDDEN,VALIDATION",
        r -> {
          Map<String, Object> deck = d.need("SELECT * FROM decks WHERE id=?", r.p());
          r.owner(deck);
          String vis = choice(r.body, "visibility", "private", "public", "room"), room = null;
          if (vis.equals("room")) {
            room = text(r.body, "room_id", 1, 80);
            membership(room, r.uid());
          }
          String
              source = vis.equals("private") ? str(deck, "source") : text(r.body, "source", 3, 500),
              license =
                  vis.equals("private") ? str(deck, "license") : text(r.body, "license", 3, 120);
          d.exec(
              "UPDATE decks SET"
                  + " visibility=?,room_id=?,status=?,source=?,license=?,version=version+1,updated=?"
                  + " WHERE id=?",
              vis,
              room,
              vis.equals("public") ? "pending" : "private",
              source,
              license,
              now(),
              r.p());
          return map("deck", d.need("SELECT * FROM decks WHERE id=?", r.p()));
        });
    a.add(
        "POST",
        "/api/decks/{id}/clone",
        "student",
        true,
        "{}",
        "{deck}",
        "NOT_FOUND",
        r -> {
          Map<String, Object> source = deck(r.p(), r.uid());
          String id = id();
          d.insert(
              "decks",
              map(
                  "id",
                  id,
                  "owner_id",
                  r.uid(),
                  "title",
                  str(source, "title"),
                  "topic_id",
                  source.get("topic_id"),
                  "updated",
                  now(),
                  "source",
                  str(source, "source"),
                  "license",
                  str(source, "license")));
          for (Map<String, Object> c : d.all("SELECT * FROM cards WHERE deck_id=?", r.p())) {
            c.put("id", id());
            c.put("deck_id", id);
            d.insert("cards", c);
          }
          return map("deck", d.need("SELECT * FROM decks WHERE id=?", id));
        });
    a.add(
        "POST",
        "/api/import/preview",
        "student",
        false,
        "{text,delimiter:','|'tab'}",
        "{valid:[{front,back,row}],errors:[{row,message}],duplicates:[number]}",
        "VALIDATION",
        r ->
            csv(
                text(r.body, "text", 1, 1_800_000),
                str(r.body, "delimiter").equals("tab") ? '\t' : ','));
    a.add(
        "GET",
        "/api/quizzes",
        "public",
        false,
        "?q=&topic=&offset=&limit=",
        "{items:[Quiz]}",
        "",
        r ->
            map(
                "items",
                d.all(
                    "SELECT id,title,topic_id,status,duration,version,source,license FROM quizzes"
                        + " WHERE (status='approved' OR owner_id=?) AND title LIKE ? AND (?='' OR"
                        + " topic_id=?) ORDER BY title LIMIT ? OFFSET ?",
                    r.user == null ? "" : r.uid(),
                    "%" + r.q("q") + "%",
                    r.q("topic"),
                    r.q("topic"),
                    r.limit(),
                    r.offset())));
    a.add(
        "GET",
        "/api/quizzes/{id}",
        "public",
        false,
        "—",
        "{quiz,questions:[Question with accepted answers and explanation]}",
        "NOT_FOUND",
        r -> {
          Map<String, Object> q = quiz(r.p(), r.user == null ? "" : r.uid());
          List<Map<String, Object>> qs = questions(r.p());
          require(!qs.isEmpty(), 409, "EMPTY_QUIZ", "This quiz has no valid questions.");
          return map("quiz", q, "questions", qs);
        });
    a.add(
        "POST",
        "/api/quizzes",
        "moderator",
        true,
        "{title,topic_id,duration?,source,license,questions:[{kind,prompt,options[],accepted[],explanation,topic_id?}]}",
        "{quiz}",
        "VALIDATION",
        r -> {
          String id = id(), topic = text(r.body, "topic_id", 1, 80);
          d.need("SELECT * FROM topics WHERE id=?", topic);
          List<Map<String, Object>> qs = rows(json(r.body.get("questions")));
          require(
              qs.size() > 0 && qs.size() <= 100,
              422,
              "VALIDATION",
              "A quiz needs 1–100 questions.");
          for (Map<String, Object> q : qs) validateQuestion(q);
          d.insert(
              "quizzes",
              map(
                  "id",
                  id,
                  "owner_id",
                  r.uid(),
                  "title",
                  text(r.body, "title", 1, 120),
                  "topic_id",
                  topic,
                  "status",
                  "pending",
                  "duration",
                  r.body.get("duration") == null
                      ? null
                      : integer(r.body, "duration", 30, 7200, 300),
                  "updated",
                  now(),
                  "source",
                  text(r.body, "source", 3, 500),
                  "license",
                  text(r.body, "license", 3, 120)));
          int i = 0;
          for (Map<String, Object> q : qs)
            d.insert(
                "questions",
                map(
                    "id",
                    id(),
                    "quiz_id",
                    id,
                    "kind",
                    q.get("kind"),
                    "prompt",
                    q.get("prompt"),
                    "options",
                    json(q.getOrDefault("options", List.of())),
                    "accepted",
                    json(q.get("accepted")),
                    "explanation",
                    q.get("explanation"),
                    "topic_id",
                    topic,
                    "position",
                    i++));
          return map("quiz", d.need("SELECT * FROM quizzes WHERE id=?", id));
        });
    a.add(
        "GET",
        "/api/materials",
        "public",
        false,
        "?q=&course=&subject=&year=&file_type=&offset=&limit=",
        "{items:[Material metadata]}",
        "",
        r ->
            map(
                "items",
                d.all(
                    "SELECT"
                        + " m.id,m.owner_id,m.title,m.topic_id,m.year,m.file_type,m.bytes,m.sha256,m.source,m.license,m.status,m.verified_by,m.created,t.course,t.subject"
                        + " FROM materials m JOIN topics t ON t.id=m.topic_id WHERE"
                        + " (m.status='approved' OR m.owner_id=?) AND m.title LIKE ? AND (?='' OR"
                        + " t.course=?) AND (?='' OR t.subject=?) AND (?='' OR m.year=?) AND (?=''"
                        + " OR m.file_type=?) ORDER BY m.created DESC LIMIT ? OFFSET ?",
                    r.user == null ? "" : r.uid(),
                    "%" + r.q("q") + "%",
                    r.q("course"),
                    r.q("course"),
                    r.q("subject"),
                    r.q("subject"),
                    r.q("year"),
                    r.q("year"),
                    r.q("file_type"),
                    r.q("file_type"),
                    r.limit(),
                    r.offset())));
    a.add(
        "POST",
        "/api/materials",
        "student",
        true,
        "{title,topic_id,year,body,source,license}",
        "{material}",
        "VALIDATION",
        r -> {
          String id = id();
          d.need("SELECT * FROM topics WHERE id=?", str(r.body, "topic_id"));
          String body = text(r.body, "body", 1, 100000);
          d.insert(
              "materials",
              map(
                  "id",
                  id,
                  "owner_id",
                  r.uid(),
                  "title",
                  text(r.body, "title", 1, 120),
                  "topic_id",
                  r.body.get("topic_id"),
                  "year",
                  integer(r.body, "year", 1, 6, 1),
                  "file_type",
                  "text",
                  "body",
                  body,
                  "bytes",
                  body.getBytes(java.nio.charset.StandardCharsets.UTF_8).length,
                  "sha256",
                  hash(body),
                  "source",
                  text(r.body, "source", 3, 500),
                  "license",
                  text(r.body, "license", 3, 120),
                  "status",
                  "pending",
                  "created",
                  now()));
          return map("material", d.need("SELECT * FROM materials WHERE id=?", id));
        });
    a.add(
        "POST",
        "/api/materials/{id}/file",
        "student",
        true,
        "{offset,base64,complete:boolean,sha256,file_type:'pdf'|'png'|'jpeg'}",
        "{offset,complete}",
        "VALIDATION,UPLOAD_OFFSET,CHECKSUM_MISMATCH,QUOTA",
        r -> {
          Map<String, Object> m = d.need("SELECT * FROM materials WHERE id=?", r.p());
          r.owner(m);
          require(
              !str(m, "status").equals("approved"),
              409,
              "CONTENT_LOCKED",
              "Withdraw or create a new revision before replacing approved content.");
          String type = choice(r.body, "file_type", "pdf", "png", "jpeg");
          int offset = integer(r.body, "offset", 0, 10 * 1024 * 1024, 0);
          byte[] b;
          try {
            b = Base64.getDecoder().decode(text(r.body, "base64", 1, 1_400_000));
          } catch (IllegalArgumentException e) {
            throw new Fault(422, "VALIDATION", "Invalid base64");
          }
          require(offset + b.length <= 10 * 1024 * 1024, 413, "QUOTA", "File limit is 10 MB.");
          Path part = a.files.resolve(r.p() + ".partial");
          long size = Files.exists(part) ? Files.size(part) : 0;
          require(size == offset, 409, "UPLOAD_OFFSET", "Resume at offset " + size);
          Files.write(part, b, StandardOpenOption.CREATE, StandardOpenOption.APPEND);
          if (yes(r.body, "complete")) {
            byte[] all = Files.readAllBytes(part);
            String digest =
                HexFormat.of()
                    .formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(all));
            if (!digest.equals(str(r.body, "sha256"))) {
              Files.deleteIfExists(part);
              throw new Fault(422, "CHECKSUM_MISMATCH", "Checksum mismatch; restart upload.");
            }
            boolean magic =
                type.equals("pdf")
                        && new String(
                                all,
                                0,
                                Math.min(5, all.length),
                                java.nio.charset.StandardCharsets.US_ASCII)
                            .equals("%PDF-")
                    || type.equals("png") && all.length > 8 && all[0] == (byte) 137 && all[1] == 80
                    || type.equals("jpeg")
                        && all.length > 3
                        && all[0] == (byte) 255
                        && all[1] == (byte) 216;
            require(magic, 422, "VALIDATION", "File content does not match its type.");
            Path target = a.files.resolve(r.p() + ".bin");
            Files.move(part, target, StandardCopyOption.REPLACE_EXISTING);
            d.exec(
                "UPDATE materials SET"
                    + " file_key=?,file_type=?,bytes=?,sha256=?,status='pending',verified_by=NULL"
                    + " WHERE id=?",
                r.p() + ".bin",
                type,
                all.length,
                digest,
                r.p());
          }
          return map("offset", offset + b.length, "complete", yes(r.body, "complete"));
        });
    a.add(
        "GET",
        "/api/materials/{id}",
        "public",
        false,
        "?offset=byte offset",
        "{material,base64?,offset?,next_offset?,complete?}",
        "NOT_FOUND",
        r -> {
          Map<String, Object> m = material(r.p(), r.user == null ? "" : r.uid());
          if (m.get("file_key") == null) return map("material", m);
          Path path = a.files.resolve(str(m, "file_key"));
          require(
              Files.exists(path), 404, "FILE_UNAVAILABLE", "This file is temporarily unavailable.");
          byte[] all = Files.readAllBytes(path);
          int offset = Math.min(r.offset(), all.length),
              end = Math.min(offset + 256 * 1024, all.length);
          return map(
              "material",
              m,
              "base64",
              Base64.getEncoder().encodeToString(Arrays.copyOfRange(all, offset, end)),
              "offset",
              offset,
              "next_offset",
              end,
              "complete",
              end == all.length);
        });
  }

  Map<String, Object> deck(String id, String uid) {
    Map<String, Object> x = d.need("SELECT * FROM decks WHERE id=? AND status!='quarantined'", id);
    boolean room =
        str(x, "visibility").equals("room")
            && d.scalar(
                    "SELECT count(*) FROM memberships m JOIN rooms r ON m.room_id=r.id WHERE"
                        + " m.room_id=? AND m.user_id=? AND r.state='active'",
                    x.get("room_id"),
                    uid)
                > 0;
    require(
        str(x, "owner_id").equals(uid)
            || str(x, "status").equals("approved") && str(x, "visibility").equals("public")
            || room,
        404,
        "NOT_FOUND",
        "Deck unavailable.");
    return x;
  }

  Map<String, Object> quiz(String id, String uid) {
    return d.need(
        "SELECT * FROM quizzes WHERE id=? AND (status='approved' OR owner_id=?) AND"
            + " status!='quarantined'",
        id,
        uid);
  }

  Map<String, Object> material(String id, String uid) {
    Map<String, Object> material =
        d.need(
            "SELECT * FROM materials WHERE id=? AND (status='approved' OR owner_id=?) AND"
                + " status!='quarantined'",
            id,
            uid);
    boolean locked =
        d.scalar(
                "SELECT count(*) FROM catalog c WHERE c.kind='content' AND c.value=? AND c.active=1"
                    + " AND NOT EXISTS(SELECT 1 FROM inventory i WHERE i.item_id=c.id AND"
                    + " i.user_id=?)",
                id,
                uid)
            > 0;
    require(
        !locked || str(material, "owner_id").equals(uid),
        403,
        "CONTENT_LOCKED",
        "Unlock this optional resource with earned study coins in Rewards.");
    return material;
  }

  List<Map<String, Object>> questions(String id) {
    List<Map<String, Object>> qs =
        d.all("SELECT * FROM questions WHERE quiz_id=? ORDER BY position", id);
    for (Map<String, Object> q : qs) {
      q.put("options", list(str(q, "options")));
      q.put("accepted", list(str(q, "accepted")));
    }
    return qs;
  }

  void membership(String room, String uid) {
    d.need(
        "SELECT m.* FROM memberships m JOIN rooms r ON m.room_id=r.id WHERE m.room_id=? AND"
            + " m.user_id=? AND r.state='active'",
        room,
        uid);
  }

  void saveDeck(Api.Request r, String id, boolean edit) {
    String title = text(r.body, "title", 1, 120), topic = text(r.body, "topic_id", 1, 80);
    d.need("SELECT * FROM topics WHERE id=?", topic);
    List<Map<String, Object>> cs = rows(json(r.body.getOrDefault("cards", List.of())));
    require(cs.size() <= 500, 422, "VALIDATION", "Split decks larger than 500 cards.");
    Set<String> fingerprints = new HashSet<>();
    for (Map<String, Object> c : cs) {
      String f = text(c, "front", 1, 4000), b = text(c, "back", 1, 4000);
      String fp = hash(normalized(f) + "\0" + normalized(b));
      require(
          fingerprints.add(fp) || yes(r.body, "allow_duplicates"),
          422,
          "DUPLICATE_CARD",
          "Duplicate cards found; confirm import anyway.");
      if (!str(c, "image_id").isBlank()) {
        Map<String, Object> image = material(str(c, "image_id"), r.uid());
        require(
            Set.of("png", "jpeg").contains(str(image, "file_type")),
            422,
            "VALIDATION",
            "Card image must be PNG or JPEG.");
        text(c, "image_alt", 1, 500);
      }
      c.put("fingerprint", fp);
    }
    if (edit)
      d.exec(
          "UPDATE decks SET title=?,topic_id=?,version=version+1,updated=?,status=CASE WHEN"
              + " visibility='public' THEN 'pending' ELSE 'private' END WHERE id=?",
          title,
          topic,
          now(),
          id);
    else
      d.insert(
          "decks",
          map(
              "id",
              id,
              "owner_id",
              r.uid(),
              "title",
              title,
              "topic_id",
              topic,
              "updated",
              now(),
              "source",
              str(r.body, "source"),
              "license",
              str(r.body, "license")));
    Set<String> keep = new HashSet<>();
    int position = 0;
    for (Map<String, Object> c : cs) {
      String cid = str(c, "id");
      if (cid.isBlank()
          || edit && d.one("SELECT id FROM cards WHERE id=? AND deck_id=?", cid, id) == null)
        cid = id();
      if (!edit) {
        require(
            cid.matches("[a-fA-F0-9-]{36}"), 422, "VALIDATION", "New cards need UUID identifiers.");
        if (d.one("SELECT id FROM cards WHERE id=?", cid) != null) cid = id();
      }
      keep.add(cid);
      d.exec(
          "INSERT INTO cards VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET"
              + " front=excluded.front,back=excluded.back,image_id=excluded.image_id,image_alt=excluded.image_alt,fingerprint=excluded.fingerprint,position=excluded.position",
          cid,
          id,
          c.get("front"),
          c.get("back"),
          str(c, "image_id").isBlank() ? null : c.get("image_id"),
          str(c, "image_alt"),
          c.get("fingerprint"),
          position++);
    }
    for (Map<String, Object> old : d.all("SELECT id FROM cards WHERE deck_id=?", id))
      if (!keep.contains(str(old, "id"))) d.exec("DELETE FROM cards WHERE id=?", old.get("id"));
  }

  static void validateQuestion(Map<String, Object> q) {
    String kind = choice(q, "kind", "mcq", "boolean", "identification");
    text(q, "prompt", 1, 4000);
    text(q, "explanation", 1, 4000);
    List<Object> accepted = list(json(q.get("accepted"))),
        options = list(json(q.getOrDefault("options", List.of())));
    require(
        !accepted.isEmpty() && accepted.size() <= 20,
        422,
        "VALIDATION",
        "Mark at least one accepted answer.");
    for (Object answer : accepted)
      require(
          answer instanceof String
              && !answer.toString().isBlank()
              && answer.toString().length() <= 4000,
          422,
          "VALIDATION",
          "Invalid accepted answer.");
    if (!kind.equals("identification")) {
      require(options.size() >= 2 && options.size() <= 6, 422, "VALIDATION", "Choose 2–6 options.");
      require(
          new HashSet<>(options).size() == options.size() && options.containsAll(accepted),
          422,
          "VALIDATION",
          "Accepted answers must be distinct listed options.");
      if (kind.equals("boolean"))
        require(
            new HashSet<>(options).equals(Set.of("True", "False")),
            422,
            "VALIDATION",
            "True/false options must be True and False.");
    }
  }

  static Map<String, Object> csv(String text, char delimiter) {
    List<List<String>> records = new ArrayList<>();
    List<String> row = new ArrayList<>();
    StringBuilder field = new StringBuilder();
    boolean quoted = false;
    for (int i = 0; i < text.length(); i++) {
      char c = text.charAt(i);
      if (c == '"') {
        if (quoted && i + 1 < text.length() && text.charAt(i + 1) == '"') {
          field.append('"');
          i++;
        } else quoted = !quoted;
      } else if (c == delimiter && !quoted) {
        row.add(field.toString());
        field.setLength(0);
      } else if (c == '\n' && !quoted) {
        row.add(field.toString().replaceFirst("\r$", ""));
        records.add(row);
        row = new ArrayList<>();
        field.setLength(0);
      } else field.append(c);
    }
    if (!row.isEmpty() || field.length() > 0) {
      row.add(field.toString().replaceFirst("\r$", ""));
      records.add(row);
    }
    List<Object> valid = new ArrayList<>(), errors = new ArrayList<>(), dups = new ArrayList<>();
    Set<String> seen = new HashSet<>();
    int n = 0;
    for (List<String> cells : records) {
      n++;
      if (n == 1
          && cells.size() == 2
          && normalized(cells.get(0)).replace("\ufeff", "").equals("front")
          && normalized(cells.get(1)).equals("back")) continue;
      if (cells.size() != 2
          || cells.get(0).isBlank()
          || cells.get(1).isBlank()
          || cells.stream().anyMatch(s -> s.codePointCount(0, s.length()) > 4000)) {
        errors.add(
            map(
                "row",
                n,
                "message",
                "Expected two nonempty fields, each at most 4,000 characters."));
        continue;
      }
      String fp = hash(normalized(cells.get(0)) + "\0" + normalized(cells.get(1)));
      if (!seen.add(fp)) dups.add(n);
      valid.add(map("front", cells.get(0), "back", cells.get(1), "row", n));
    }
    if (quoted) {
      errors.add(map("row", n, "message", "Unclosed quoted field."));
      if (!valid.isEmpty()) valid.remove(valid.size() - 1);
    }
    return map("valid", valid, "errors", errors, "duplicates", dups);
  }
}
