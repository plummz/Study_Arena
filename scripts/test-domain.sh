#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/test-classes
java -jar .deps/ecj.jar -17 -encoding UTF-8 -warn:none -cp 'build/classes:.deps/sqlite-jdbc.jar:.deps/jackson-databind.jar:.deps/jackson-core.jar:.deps/jackson-annotations.jar' -d build/test-classes tests/DomainTests.java
java -cp 'build/test-classes:build/classes:.deps/*' ph.edu.wit.studyarena.DomainTests
