package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import com.sun.net.httpserver.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.regex.*;

final class Api {
  interface Handler {
    Object apply(Request r) throws Exception;
  }

  record Route(
      String method,
      String path,
      String auth,
      boolean idempotent,
      String request,
      String response,
      String errors,
      Pattern regex,
      Handler handler) {}

  final List<Route> routes = new ArrayList<>();
  final Db db;
  final byte[] key;
  final boolean demo;
  final String origin;
  final Path web, files;

  Api(Db db, byte[] key, boolean demo, String origin, Path web, Path files) {
    this.db = db;
    this.key = key;
    this.demo = demo;
    this.origin = origin;
    this.web = web.toAbsolutePath().normalize();
    this.files = files;
  }

  void add(
      String method,
      String path,
      String auth,
      boolean idem,
      String request,
      String response,
      String errors,
      Handler h) {
    String regex = path.replaceAll("\\{[a-z_]+\\}", "([^/]+)");
    routes.add(
        new Route(
            method,
            path,
            auth,
            idem,
            request,
            response,
            errors,
            Pattern.compile("^" + regex + "$"),
            h));
  }

  final class Request {
    final HttpExchange x;
    final Route route;
    final Map<String, Object> body;
    final List<String> params;
    final Map<String, String> query;
    Map<String, Object> user;
    String token;

    Request(HttpExchange x, Route route, Map<String, Object> body, List<String> params) {
      this.x = x;
      this.route = route;
      this.body = body;
      this.params = params;
      query = new HashMap<>();
      String q = x.getRequestURI().getRawQuery();
      if (q != null)
        for (String pair : q.split("&")) {
          String[] p = pair.split("=", 2);
          query.put(
              URLDecoder.decode(p[0], StandardCharsets.UTF_8),
              p.length == 2 ? URLDecoder.decode(p[1], StandardCharsets.UTF_8) : "");
        }
    }

    String uid() {
      return str(user, "id");
    }

    String p() {
      return params.get(0);
    }

    String q(String k) {
      return query.getOrDefault(k, "");
    }

    int limit() {
      try {
        return Math.min(100, Math.max(1, Integer.parseInt(query.getOrDefault("limit", "30"))));
      } catch (Exception e) {
        throw new Fault(422, "VALIDATION", "Invalid page size");
      }
    }

    int offset() {
      try {
        return Math.max(0, Integer.parseInt(query.getOrDefault("offset", "0")));
      } catch (Exception e) {
        throw new Fault(422, "VALIDATION", "Invalid offset");
      }
    }

    void recent() {
      Map<String, Object> s =
          db.need("SELECT recent_auth FROM auth_sessions WHERE token_hash=?", hash(token));
      require(
          now() - num(s, "recent_auth") < 600,
          401,
          "REAUTH_REQUIRED",
          "Sign in again to confirm this action.");
    }

    void owner(Map<String, Object> row) {
      require(
          Objects.equals(row.get("owner_id"), uid()),
          403,
          "FORBIDDEN",
          "Only the owner can do that.");
    }

    boolean moderator() {
      return Set.of("teacher", "admin").contains(str(user, "role"));
    }

    void flag(String name) {
      require(db.flag(name), 403, "FEATURE_DISABLED", "This pilot is not enabled.");
    }
  }

  void handle(HttpExchange x) {
    String requestId = id();
    try {
      x.getResponseHeaders().set("X-Request-ID", requestId);
      x.getResponseHeaders().set("X-Content-Type-Options", "nosniff");
      x.getResponseHeaders().set("Referrer-Policy", "no-referrer");
      x.getResponseHeaders().set("Cache-Control", "no-store");
      String o = x.getRequestHeaders().getFirst("Origin");
      if (o != null) {
        require(
            o.equals(origin) || o.equals("https://localhost"),
            403,
            "ORIGIN_DENIED",
            "Origin is not allowed.");
        x.getResponseHeaders().set("Access-Control-Allow-Origin", o);
        x.getResponseHeaders().set("Vary", "Origin");
      }
      if (x.getRequestMethod().equals("OPTIONS")) {
        x.getResponseHeaders()
            .set("Access-Control-Allow-Headers", "Authorization, Content-Type, Idempotency-Key");
        x.getResponseHeaders()
            .set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
        send(x, 204, null);
        return;
      }
      String path = x.getRequestURI().getPath();
      if (!path.startsWith("/api/")) {
        staticFile(x, path);
        return;
      }
      Route found = null;
      Matcher match = null;
      for (Route route : routes) {
        Matcher m = route.regex().matcher(path);
        if (route.method().equals(x.getRequestMethod()) && m.matches()) {
          found = route;
          match = m;
          break;
        }
      }
      require(found != null, 404, "NOT_FOUND", "Endpoint does not exist.");
      List<String> params = new ArrayList<>();
      for (int i = 1; i <= match.groupCount(); i++) params.add(match.group(i));
      byte[] bytes = x.getRequestBody().readNBytes(2_000_001);
      require(bytes.length <= 2_000_000, 413, "BODY_TOO_LARGE", "Request exceeds 2 MB.");
      Map<String, Object> body =
          bytes.length == 0
              ? new LinkedHashMap<>()
              : obj(new String(bytes, StandardCharsets.UTF_8));
      if (bytes.length > 0)
        require(
            Objects.toString(x.getRequestHeaders().getFirst("Content-Type"), "")
                .startsWith("application/json"),
            415,
            "CONTENT_TYPE",
            "Use application/json.");
      Request r = new Request(x, found, body, params);
      Object output;
      synchronized (db) {
        // Rate accounting commits separately so rejected logins still consume the budget.
        String ip = x.getRemoteAddress().getAddress().getHostAddress();
        db.rate("http:" + ip, 600, 60);
        if (path.startsWith("/api/auth/")) db.rate("auth:" + ip, 40, 60);
        authenticate(r);
        db.c.setAutoCommit(false);
        try {
          String idem = x.getRequestHeaders().getFirst("Idempotency-Key"),
              fingerprint = hash(r.route.method() + path + json(body));
          if (found.idempotent()) {
            require(
                idem != null && idem.matches("[a-zA-Z0-9_-]{16,100}"),
                400,
                "IDEMPOTENCY_REQUIRED",
                "Supply a stable Idempotency-Key.");
            Map<String, Object> cached =
                db.one("SELECT * FROM idempotency WHERE user_id=? AND key=?", r.uid(), idem);
            if (cached != null) {
              require(
                  str(cached, "fingerprint").equals(fingerprint),
                  409,
                  "IDEMPOTENCY_CONFLICT",
                  "This key belongs to a different request.");
              output = obj(str(cached, "response"));
            } else {
              output = found.handler().apply(r);
              db.exec(
                  "INSERT INTO idempotency VALUES(?,?,?,?,?)",
                  r.uid(),
                  idem,
                  fingerprint,
                  json(output),
                  now());
            }
          } else output = found.handler().apply(r);
          db.c.commit();
        } catch (Exception e) {
          db.c.rollback();
          throw e;
        } finally {
          db.c.setAutoCommit(true);
        }
      }
      send(x, 200, output);
    } catch (Fault e) {
      send(
          x,
          e.status,
          map("error", map("code", e.code, "message", e.getMessage(), "request_id", requestId)));
    } catch (Exception e) {
      System.err.println("request=" + requestId + " exception=" + e.getClass().getSimpleName());
      e.printStackTrace(System.err);
      send(
          x,
          500,
          map(
              "error",
              map(
                  "code",
                  "INTERNAL_ERROR",
                  "message",
                  "Something went wrong. Your saved work is safe; retry with the same request key.",
                  "request_id",
                  requestId)));
    } finally {
      x.close();
    }
  }

  void authenticate(Request r) {
    String auth = r.x.getRequestHeaders().getFirst("Authorization");
    if (auth != null && auth.startsWith("Bearer ")) {
      r.token = auth.substring(7);
      r.user =
          db.one(
              "SELECT u.* FROM users u JOIN auth_sessions s ON u.id=s.user_id WHERE s.token_hash=?"
                  + " AND s.expires>? AND u.delete_after IS NULL AND u.suspended=0",
              hash(r.token),
              now());
    }
    if (!r.route.auth().equals("public")) {
      require(
          r.user != null,
          401,
          "AUTH_REQUIRED",
          "Please sign in again; local study work will remain saved.");
      if (r.route.auth().equals("admin"))
        require(
            str(r.user, "role").equals("admin"),
            403,
            "FORBIDDEN",
            "Administrator access required.");
      if (r.route.auth().equals("moderator"))
        require(r.moderator(), 403, "FORBIDDEN", "Moderator access required.");
    }
  }

  void staticFile(HttpExchange x, String path) throws Exception {
    require(x.getRequestMethod().equals("GET"), 405, "METHOD_NOT_ALLOWED", "Use GET.");
    Path p = web.resolve(path.equals("/") ? "index.html" : path.substring(1)).normalize();
    require(
        p.startsWith(web) && Files.isRegularFile(p) && !p.getFileName().toString().startsWith("."),
        404,
        "NOT_FOUND",
        "File does not exist.");
    String name = p.toString();
    String type =
        name.endsWith(".js")
            ? "text/javascript"
            : name.endsWith(".css")
                ? "text/css"
                : name.endsWith(".svg")
                    ? "image/svg+xml"
                    : name.endsWith(".json") || name.endsWith(".webmanifest")
                        ? "application/json"
                        : "text/html";
    x.getResponseHeaders().set("Content-Type", type + "; charset=utf-8");
    x.getResponseHeaders()
        .set(
            "Content-Security-Policy",
            "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob: data:;"
                + " connect-src 'self' "
                + origin
                + "; object-src 'none'; base-uri 'none'; frame-ancestors 'none'");
    byte[] b = Files.readAllBytes(p);
    x.sendResponseHeaders(200, b.length);
    x.getResponseBody().write(b);
  }

  void send(HttpExchange x, int status, Object value) {
    try {
      if (status == 204) {
        x.sendResponseHeaders(204, -1);
        return;
      }
      byte[] b = json(value).getBytes(StandardCharsets.UTF_8);
      x.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
      x.sendResponseHeaders(status, b.length);
      x.getResponseBody().write(b);
    } catch (IOException ignored) {
      /* A retry resolves committed mutations by idempotency key. */
    }
  }

  List<Object> contracts() {
    List<Object> list = new ArrayList<>();
    for (Route r : routes)
      list.add(
          map(
              "method",
              r.method(),
              "path",
              r.path(),
              "auth",
              r.auth(),
              "idempotency",
              r.idempotent(),
              "request",
              r.request(),
              "response",
              r.response(),
              "errors",
              r.errors()));
    return list;
  }
}
