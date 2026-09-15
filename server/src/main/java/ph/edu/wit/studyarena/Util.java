package ph.edu.wit.studyarena;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.text.Normalizer;
import java.util.*;
import javax.crypto.*;
import javax.crypto.spec.*;

final class Util {
  static final ObjectMapper JSON = new ObjectMapper();
  static final SecureRandom RANDOM = new SecureRandom();

  static String json(Object o) {
    try {
      return JSON.writeValueAsString(o);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  static Map<String, Object> obj(String s) {
    try {
      return Objects.requireNonNull(
          JSON.readValue(s, new TypeReference<LinkedHashMap<String, Object>>() {}));
    } catch (Exception e) {
      throw new Fault(400, "INVALID_JSON", "Send a JSON object.");
    }
  }

  static List<Map<String, Object>> rows(String s) {
    try {
      var result =
          Objects.requireNonNull(
              JSON.readValue(s, new TypeReference<List<Map<String, Object>>>() {}));
      require(
          result.stream().allMatch(Objects::nonNull),
          400,
          "INVALID_JSON",
          "List items cannot be null.");
      return result;
    } catch (Exception e) {
      throw new Fault(400, "INVALID_JSON", "Invalid list.");
    }
  }

  static List<Object> list(String s) {
    try {
      return Objects.requireNonNull(JSON.readValue(s, new TypeReference<List<Object>>() {}));
    } catch (Exception e) {
      throw new Fault(400, "INVALID_JSON", "Invalid list.");
    }
  }

  static Map<String, Object> map(Object... pairs) {
    Map<String, Object> m = new LinkedHashMap<>();
    for (int i = 0; i < pairs.length; i += 2) m.put((String) pairs[i], pairs[i + 1]);
    return m;
  }

  static String id() {
    return UUID.randomUUID().toString();
  }

  static double now() {
    return System.currentTimeMillis() / 1000.0;
  }

  static String str(Map<String, Object> m, String k) {
    return Objects.toString(m.get(k), "");
  }

  static String text(Map<String, Object> m, String k, int min, int max) {
    String s = str(m, k).strip();
    int len = s.codePointCount(0, s.length());
    require(
        len >= min && len <= max,
        422,
        "VALIDATION",
        k + " must contain " + min + "–" + max + " characters.");
    return s;
  }

  static int integer(Map<String, Object> m, String k, int min, int max, int fallback) {
    Object v = m.get(k);
    if (v == null) return fallback;
    try {
      double d = Double.parseDouble(v.toString());
      require(
          Double.isFinite(d) && d == Math.rint(d) && d >= min && d <= max,
          422,
          "VALIDATION",
          "Invalid " + k);
      return (int) d;
    } catch (NumberFormatException e) {
      throw new Fault(422, "VALIDATION", "Invalid " + k);
    }
  }

  static double num(Map<String, Object> m, String k) {
    Object v = m.get(k);
    if (v == null) return 0;
    try {
      double n = Double.parseDouble(v.toString());
      require(Double.isFinite(n), 422, "VALIDATION", "Invalid number");
      return n;
    } catch (NumberFormatException e) {
      throw new Fault(422, "VALIDATION", "Invalid " + k);
    }
  }

  static boolean yes(Map<String, Object> m, String k) {
    return Boolean.TRUE.equals(m.get(k))
        || Objects.equals(m.get(k), 1)
        || Objects.equals(m.get(k), "true");
  }

  static String choice(Map<String, Object> m, String k, String... values) {
    String v = str(m, k);
    require(Arrays.asList(values).contains(v), 422, "VALIDATION", "Invalid " + k);
    return v;
  }

  static void require(boolean ok, int status, String code, String message) {
    if (!ok) throw new Fault(status, code, message);
  }

  static String token() {
    byte[] b = new byte[32];
    RANDOM.nextBytes(b);
    return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
  }

  static String hash(String s) {
    try {
      return HexFormat.of()
          .formatHex(
              MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  static String normalized(String s) {
    return Normalizer.normalize(s, Normalizer.Form.NFKC)
        .strip()
        .toLowerCase(Locale.ROOT)
        .replaceAll("\\s+", " ");
  }

  static String password(String value) {
    byte[] salt = new byte[16];
    RANDOM.nextBytes(salt);
    return Base64.getEncoder().encodeToString(salt)
        + ":"
        + Base64.getEncoder().encodeToString(derive(value, salt));
  }

  static byte[] derive(String v, byte[] salt) {
    try {
      return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
          .generateSecret(new PBEKeySpec(v.toCharArray(), salt, 600000, 256))
          .getEncoded();
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  static boolean verify(String v, String stored) {
    try {
      String[] p = stored.split(":");
      return MessageDigest.isEqual(
          Base64.getDecoder().decode(p[1]), derive(v, Base64.getDecoder().decode(p[0])));
    } catch (Exception e) {
      return false;
    }
  }

  static String crypt(String value, byte[] key, boolean encrypt) {
    try {
      Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
      byte[] nonce = new byte[12];
      byte[] data;
      if (encrypt) {
        RANDOM.nextBytes(nonce);
        data = value.getBytes(StandardCharsets.UTF_8);
      } else {
        byte[] all = Base64.getDecoder().decode(value);
        nonce = Arrays.copyOfRange(all, 0, 12);
        data = Arrays.copyOfRange(all, 12, all.length);
      }
      c.init(
          encrypt ? Cipher.ENCRYPT_MODE : Cipher.DECRYPT_MODE,
          new SecretKeySpec(key, "AES"),
          new GCMParameterSpec(128, nonce));
      byte[] out = c.doFinal(data);
      if (!encrypt) return new String(out, StandardCharsets.UTF_8);
      byte[] all = new byte[12 + out.length];
      System.arraycopy(nonce, 0, all, 0, 12);
      System.arraycopy(out, 0, all, 12, out.length);
      return Base64.getEncoder().encodeToString(all);
    } catch (Exception e) {
      throw new IllegalStateException("Encryption operation failed", e);
    }
  }

  static final class Fault extends RuntimeException {
    final int status;
    final String code;

    Fault(int status, String code, String message) {
      super(message);
      this.status = status;
      this.code = code;
    }
  }
}
