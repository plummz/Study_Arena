#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec java -jar dist/study-arena.jar --demo
