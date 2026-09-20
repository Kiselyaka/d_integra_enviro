#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/../../integration-platform/backend"
python -m pytest

cd "$(dirname "$0")/../../demo-business-systems/mini-shop"
python -m pytest

cd "$(dirname "$0")/../../demo-business-systems/crm"
python -m pytest

