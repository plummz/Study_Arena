#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/fetch-deps.sh
mkdir -p build/classes
classpath=$(find .deps -name '*.jar' -printf '%p:' )
java -jar .deps/ecj.jar -17 -encoding UTF-8 -warn:none -cp "$classpath" -d build/classes server/src/main/java/ph/edu/wit/studyarena/*.java
cp server/src/main/resources/* build/classes/
