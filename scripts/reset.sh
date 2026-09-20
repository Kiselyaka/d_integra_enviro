#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."
docker compose down --volumes --remove-orphans
exec docker compose up --build -d

