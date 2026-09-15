#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .deps
fetch() { local name="$1" url="$2"; if ! test -s ".deps/$name" || ! test -f ".deps/$name.url" || [[ "$(cat ".deps/$name.url")" != "$url" ]]; then curl -fsSL --retry 3 --max-time 120 "$url" -o ".deps/$name.tmp"; mv ".deps/$name.tmp" ".deps/$name"; printf "%s" "$url" > ".deps/$name.url"; fi; }
base=https://repo.maven.apache.org/maven2
fetch ecj.jar "$base/org/eclipse/jdt/ecj/3.42.0/ecj-3.42.0.jar"
fetch sqlite-jdbc.jar "$base/org/xerial/sqlite-jdbc/3.53.4.0/sqlite-jdbc-3.53.4.0.jar"
fetch jackson-databind.jar "$base/com/fasterxml/jackson/core/jackson-databind/2.19.2/jackson-databind-2.19.2.jar"
fetch jackson-core.jar "$base/com/fasterxml/jackson/core/jackson-core/2.19.2/jackson-core-2.19.2.jar"
fetch jackson-annotations.jar "$base/com/fasterxml/jackson/core/jackson-annotations/2.19.2/jackson-annotations-2.19.2.jar"
fetch slf4j-api.jar "$base/org/slf4j/slf4j-api/2.0.17/slf4j-api-2.0.17.jar"
fetch slf4j-nop.jar "$base/org/slf4j/slf4j-nop/2.0.17/slf4j-nop-2.0.17.jar"
