package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.net.*;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.*;
import java.security.spec.*;
import java.time.*;
import java.util.*;

/**
 * Firebase HTTP v1 adapter. No delivery happens without explicitly configured school credentials.
 */
final class Push {
  static String accessToken;
  static double expires;
  static final HttpClient HTTP =
      HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();

  static String b64(byte[] bytes) {
    return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
  }

  static String access(Map<String, Object> service) throws Exception {
    if (accessToken != null && now() < expires) return accessToken;
    long t = (long) now();
    String payload =
        b64(json(map("alg", "RS256", "typ", "JWT")).getBytes(StandardCharsets.UTF_8))
            + "."
            + b64(
                json(map(
                        "iss",
                        service.get("client_email"),
                        "scope",
                        "https://www.googleapis.com/auth/firebase.messaging",
                        "aud",
                        "https://oauth2.googleapis.com/token",
                        "iat",
                        t,
                        "exp",
                        t + 3600))
                    .getBytes(StandardCharsets.UTF_8));
    String pem =
        str(service, "private_key")
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replaceAll("\\s", "");
    PrivateKey key =
        KeyFactory.getInstance("RSA")
            .generatePrivate(new PKCS8EncodedKeySpec(Base64.getDecoder().decode(pem)));
    Signature signature = Signature.getInstance("SHA256withRSA");
    signature.initSign(key);
    signature.update(payload.getBytes(StandardCharsets.US_ASCII));
    String jwt = payload + "." + b64(signature.sign());
    HttpResponse<String> response =
        HTTP.send(
            HttpRequest.newBuilder(URI.create("https://oauth2.googleapis.com/token"))
                .timeout(Duration.ofSeconds(10))
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(
                    HttpRequest.BodyPublishers.ofString(
                        "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion="
                            + URLEncoder.encode(jwt, StandardCharsets.UTF_8)))
                .build(),
            HttpResponse.BodyHandlers.ofString());
    require(response.statusCode() == 200, 503, "PUSH_PROVIDER", "Push authentication failed.");
    Map<String, Object> result = obj(response.body());
    accessToken = str(result, "access_token");
    expires = now() + Math.max(60, num(result, "expires_in") - 60);
    return accessToken;
  }

  static void deliver(Api a) throws Exception {
    String path = System.getenv("FCM_SERVICE_ACCOUNT");
    if (path == null) return;
    Map<String, Object> service = obj(Files.readString(Path.of(path)));
    List<Map<String, Object>> pending;
    synchronized (a.db) {
      pending =
          a.db.all(
              "SELECT"
                  + " n.*,p.token,s.quiet_start,s.quiet_end,s.reminders,s.streak,s.invitations,s.challenges,s.rewards,u.timezone,u.competition"
                  + " FROM notifications n JOIN push_tokens p ON p.user_id=n.user_id JOIN users u"
                  + " ON u.id=n.user_id JOIN notification_settings s ON s.user_id=u.id WHERE"
                  + " n.created>? AND n.read=0 AND u.suspended=0 AND u.delete_after IS NULL AND NOT"
                  + " EXISTS (SELECT 1 FROM push_delivery x WHERE x.notification_id=n.id AND"
                  + " x.token=p.token) LIMIT 20",
              now() - 4 * 3600);
    }
    for (Map<String, Object> n : pending) {
      int h = ZonedDateTime.now(ZoneId.of(str(n, "timezone"))).getHour(),
          start = (int) num(n, "quiet_start"),
          end = (int) num(n, "quiet_end");
      boolean quiet = start < end ? h >= start && h < end : start > end && (h >= start || h < end);
      if (quiet
          || num(n, str(n, "category")) == 0
          || str(n, "category").equals("challenges") && num(n, "competition") == 0) continue;
      Map<String, Object> message =
          map(
              "message",
              map(
                  "token",
                  n.get("token"),
                  "notification",
                  map("title", "Study Arena", "body", n.get("body")),
                  "android",
                  map("ttl", "14400s", "notification", map("tag", n.get("id")))));
      String project = str(service, "project_id");
      require(project.matches("[a-z0-9-]+"), 500, "CONFIGURATION", "Invalid Firebase project id");
      HttpResponse<String> response =
          HTTP.send(
              HttpRequest.newBuilder(
                      URI.create(
                          "https://fcm.googleapis.com/v1/projects/" + project + "/messages:send"))
                  .timeout(Duration.ofSeconds(10))
                  .header("Authorization", "Bearer " + access(service))
                  .header("Content-Type", "application/json")
                  .POST(HttpRequest.BodyPublishers.ofString(json(message)))
                  .build(),
              HttpResponse.BodyHandlers.ofString());
      synchronized (a.db) {
        if (response.statusCode() == 200)
          a.db.exec(
              "INSERT OR IGNORE INTO push_delivery VALUES(?,?,?)",
              n.get("id"),
              n.get("token"),
              now());
        else if (response.statusCode() == 404)
          a.db.exec("DELETE FROM push_tokens WHERE token=?", n.get("token"));
      }
    }
  }
}
