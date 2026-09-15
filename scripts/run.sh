#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test -f build/classes/ph/edu/wit/studyarena/Main.class || bash scripts/build.sh
exec java -Xms64m -Xmx256m -cp 'build/classes:.deps/*' ph.edu.wit.studyarena.Main "$@"
