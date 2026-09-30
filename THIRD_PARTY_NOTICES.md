# Third-party components

The source package includes original Study Arena code and demo notes. Third-party code retains its original license. Consult the included JAR notices and each dependency package for the authoritative license text.

- SQLite JDBC / Xerial: Apache-2.0 and BSD-2-Clause components; underlying SQLite is public domain. Native SQLite libraries are included by its published JAR.
- Jackson Core, Databind and Annotations: Apache-2.0.
- SLF4J API/NOP: MIT.
- Capacitor Android/Core/CLI and official notification plugins: MIT.
- Playwright: Apache-2.0 (development dependency, not part of the runtime app).
- Eclipse Java compiler: EPL-2.0 (downloaded by the optional build script, not bundled in the executable JAR).
- Dungeon 3D models (`godot/dungeon_maze/assets/models/`): KayKit Skeletons, Adventurers, Dungeon Remastered and Halloween Bits packs by Kay Lousberg (kaylousberg.com), CC0 1.0 public domain. Credit is not required but is given here. Character animations were trimmed to the clips the game uses.
- Godot Engine 4.7 (dungeon runtime and web export): MIT.

Exact dependency versions are pinned in `server/pom.xml` and `package-lock.json`. `dist/build-manifest.json` records the runtime dependency hashes used for the delivered executable. No third-party textbook or copyrighted course packet is included. Starter educational text is original and labeled CC BY 4.0 for reuse with attribution.
