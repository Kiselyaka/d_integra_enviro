#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."
exec docker compose down --remove-orphans

