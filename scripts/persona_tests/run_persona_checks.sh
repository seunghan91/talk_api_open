#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[1/3] Routes compile check"
bundle exec rails routes > /tmp/talkk_persona_routes.txt

echo "[2/3] Persona request specs"
bundle exec rspec spec/requests/web/persona_flows_spec.rb

echo "[3/3] Frontend build check"
npx vite build > /tmp/talkk_persona_vite_build.log

echo "All persona checks passed."
echo "- routes: /tmp/talkk_persona_routes.txt"
echo "- vite log: /tmp/talkk_persona_vite_build.log"
