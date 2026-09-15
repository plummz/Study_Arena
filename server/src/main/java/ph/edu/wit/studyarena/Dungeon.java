package ph.edu.wit.studyarena;

import static ph.edu.wit.studyarena.Util.*;

import java.io.IOException;
import java.nio.file.*;
import java.util.*;

final class Dungeon {
  private final Path project;
  private Process game;

  Dungeon(Api a) {
    project = a.web.getParent().resolve("godot").resolve("dungeon_maze").normalize();
    a.add(
        "POST",
        "/api/dungeon/launch",
        "student",
        true,
        "{companion:moss|lumi|coral|sky|plum|sunny|mint|nova|ember|bubbles|byte|clover|mochi|comet|pebble|melody|taro|sol,difficulty:easy|average|hard|hell}",
        "{launched,already_running,companion,difficulty}",
        "VALIDATION,DUNGEON_UNAVAILABLE,DUNGEON_LAUNCH_FAILED",
        r -> launch(r.body));
  }

  private synchronized Object launch(Map<String, Object> body) {
    String companion =
        choice(body, "companion", "moss", "lumi", "coral", "sky", "plum", "sunny", "mint", "nova", "ember", "bubbles", "byte", "clover", "mochi", "comet", "pebble", "melody", "taro", "sol");
    String difficulty = choice(body, "difficulty", "easy", "average", "hard", "hell");
    require(
        Files.isRegularFile(project.resolve("project.godot")),
        409,
        "DUNGEON_UNAVAILABLE",
        "The local dungeon module is not installed.");
    if (game != null && game.isAlive())
      return map(
          "launched", true,
          "already_running", true,
          "companion", companion,
          "difficulty", difficulty);
    Path godot = findGodot();
    require(
        godot != null,
        409,
        "DUNGEON_UNAVAILABLE",
        "Godot was not found. Keep the downloaded Godot folder in Downloads.");
    try {
      copyCompanionAssets();
      game =
          new ProcessBuilder(
                  godot.toString(),
                  "--path",
                  project.toString(),
                  "--",
                  "--companion=" + companion,
                  "--difficulty=" + difficulty)
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
