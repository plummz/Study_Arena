package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.nio.file.*;
import java.sql.*;
import java.util.*;

final class Db implements AutoCloseable {
  final Connection c;

  Db(String path) throws Exception {
    Class.forName("org.sqlite.JDBC");
    c = DriverManager.getConnection("jdbc:sqlite:" + path);
    exec("PRAGMA foreign_keys=ON");
    exec("PRAGMA busy_timeout=5000");
    exec("PRAGMA journal_mode=WAL");
  }

  void schema() throws Exception {
    String sql =
        new String(
            getClass().getResourceAsStream("/schema.sql").readAllBytes(),
            java.nio.charset.StandardCharsets.UTF_8);
    StringBuilder statement = new StringBuilder();
    for (String line : sql.split("\n")) {
      statement.append(line).append('\n');
      if (line.strip().endsWith(";")) {
        exec(statement.toString());
        statement.setLength(0);
      }
    }
  }

  int exec(String sql, Object... args) {
    try (PreparedStatement s = c.prepareStatement(sql)) {
      bind(s, args);
      s.execute();
      return Math.max(0, s.getUpdateCount());
    } catch (SQLException e) {
      throw new IllegalStateException(e);
    }
  }

  List<Map<String, Object>> all(String sql, Object... args) {
    try (PreparedStatement s = c.prepareStatement(sql)) {
      bind(s, args);
      try (ResultSet r = s.executeQuery()) {
        List<Map<String, Object>> out = new ArrayList<>();
        while (r.next()) {
          Map<String, Object> row = new LinkedHashMap<>();
          for (int i = 1; i <= r.getMetaData().getColumnCount(); i++)
            row.put(r.getMetaData().getColumnLabel(i), r.getObject(i));
          out.add(row);
        }
        return out;
      }
    } catch (SQLException e) {
      throw new IllegalStateException(e);
    }
  }

  Map<String, Object> one(String sql, Object... args) {
    List<Map<String, Object>> r = all(sql, args);
    return r.isEmpty() ? null : r.get(0);
  }

  Map<String, Object> need(String sql, Object... args) {
    Map<String, Object> r = one(sql, args);
    require(r != null, 404, "NOT_FOUND", "That item is unavailable.");
    return r;
  }

  double scalar(String sql, Object... args) {
    Map<String, Object> r = one(sql, args);
    return r == null || r.values().iterator().next() == null
        ? 0
        : Double.parseDouble(r.values().iterator().next().toString());
  }

  static void bind(PreparedStatement s, Object[] a) throws SQLException {
    for (int i = 0; i < a.length; i++) s.setObject(i + 1, a[i]);
  }

  void audit(String actor, String action, String target, String reason) {
    Map<String, Object> last = one("SELECT entry_hash FROM audit ORDER BY rowid DESC LIMIT 1");
    String prev = last == null ? "genesis" : str(last, "entry_hash"), id = id();
    double t = now();
    String digest = hash(json(List.of(id, action, target, reason, t, prev)));
    exec(
        "INSERT INTO audit VALUES(?,?,?,?,?,?,?,?)",
        id,
        actor,
        action,
        target,
        reason,
        t,
        prev,
        digest);
  }

  void insert(String table, Map<String, Object> fields) {
    String columns = String.join(",", fields.keySet());
    exec(
        "INSERT INTO "
            + table
            + " ("
            + columns
            + ") VALUES ("
            + String.join(",", Collections.nCopies(fields.size(), "?"))
            + ")",
        fields.values().toArray());
  }

  boolean flag(String name) {
    return scalar("SELECT enabled FROM flags WHERE name=?", name) == 1;
  }

  void rate(String key, int limit, int seconds) {
    double t = now();
    Map<String, Object> r = one("SELECT * FROM rate_limits WHERE key=?", key);
    if (r == null || t - num(r, "window") > seconds)
      exec(
          "INSERT INTO rate_limits VALUES(?,?,1) ON CONFLICT(key) DO UPDATE SET"
              + " window=excluded.window,count=1",
          key,
          t);
    else {
      require(num(r, "count") < limit, 429, "RATE_LIMITED", "Please wait before trying again.");
      exec("UPDATE rate_limits SET count=count+1 WHERE key=?", key);
    }
  }

  public void close() throws Exception {
    c.close();
  }
}
