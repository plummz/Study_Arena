package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import javax.net.ssl.*;

/** SMTP over implicit TLS (port 465). Messages stay in the durable outbox until acknowledged. */
final class Mail {
  static void deliver(Api a) throws Exception {
    String host = System.getenv("SMTP_HOST");
    if (host == null || host.isBlank()) return;
    List<Map<String, Object>> batch;
    synchronized (a.db) {
      batch =
          a.db.all(
              "SELECT * FROM outbox WHERE delivered IS NULL AND attempts<10 ORDER BY created LIMIT"
                  + " 3");
    }
    for (Map<String, Object> mail : batch) {
      try {
        send(
            host,
            Integer.parseInt(System.getenv().getOrDefault("SMTP_PORT", "465")),
            System.getenv("SMTP_USER"),
            System.getenv("SMTP_PASSWORD"),
            System.getenv("SMTP_FROM"),
            crypt(str(mail, "recipient_cipher"), a.key, false),
            str(mail, "subject"),
            crypt(str(mail, "body_cipher"), a.key, false));
        synchronized (a.db) {
          a.db.exec("UPDATE outbox SET delivered=? WHERE id=?", now(), mail.get("id"));
        }
      } catch (Exception ex) {
        synchronized (a.db) {
          a.db.exec("UPDATE outbox SET attempts=attempts+1 WHERE id=?", mail.get("id"));
        }
        System.err.println("mail_delivery_failed reference=" + mail.get("id"));
      }
    }
  }

  static void send(
      String host,
      int port,
      String user,
      String password,
      String from,
      String to,
      String subject,
      String body)
      throws Exception {
    require(
        from != null
            && from.matches("[^\\s<>@]+@[^\\s<>@]+")
            && to.matches("[^\\s<>@]+@[^\\s<>@]+"),
        500,
        "SMTP_CONFIGURATION",
        "Invalid SMTP address");
    try (SSLSocket socket = (SSLSocket) SSLSocketFactory.getDefault().createSocket()) {
      SSLParameters params = socket.getSSLParameters();
      params.setEndpointIdentificationAlgorithm("HTTPS");
      socket.setSSLParameters(params);
      socket.connect(new java.net.InetSocketAddress(host, port), 10000);
      socket.setSoTimeout(10000);
      socket.startHandshake();
      BufferedReader in =
          new BufferedReader(
              new InputStreamReader(socket.getInputStream(), StandardCharsets.US_ASCII));
      BufferedWriter out =
          new BufferedWriter(
              new OutputStreamWriter(socket.getOutputStream(), StandardCharsets.US_ASCII));
      expect(in, 220);
      command(out, in, "EHLO study-arena", 250);
      command(out, in, "AUTH LOGIN", 334);
      command(
          out, in, Base64.getEncoder().encodeToString(user.getBytes(StandardCharsets.UTF_8)), 334);
      command(
          out,
          in,
          Base64.getEncoder().encodeToString(password.getBytes(StandardCharsets.UTF_8)),
          235);
      command(out, in, "MAIL FROM:<" + from + ">", 250);
      command(out, in, "RCPT TO:<" + to + ">", 250);
      command(out, in, "DATA", 354);
      out.write(
          "From: "
              + from
              + "\r\nTo: "
              + to
              + "\r\nSubject: "
              + subject.replaceAll("[\\r\\n]", "")
              + "\r\n"
              + "MIME-Version: 1.0\r\n"
              + "Content-Type: text/plain; charset=UTF-8\r\n"
              + "Content-Transfer-Encoding: base64\r\n\r\n"
              + Base64.getMimeEncoder().encodeToString(body.getBytes(StandardCharsets.UTF_8))
              + "\r\n.\r\n");
      out.flush();
      expect(in, 250);
      command(out, in, "QUIT", 221);
    }
  }

  static void command(BufferedWriter out, BufferedReader in, String command, int code)
      throws Exception {
    out.write(command + "\r\n");
    out.flush();
    expect(in, code);
  }

  static void expect(BufferedReader in, int code) throws Exception {
    String line;
    do {
      line = in.readLine();
      if (line == null || line.length() < 3 || !line.startsWith("" + code))
        throw new IOException("SMTP operation rejected");
    } while (line.length() > 3 && line.charAt(3) == '-');
  }
}
