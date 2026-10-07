#!/usr/bin/env bash
# =============================================================================
# verify-deployment.sh
# Smoke test for the deployed container: waits until /health answers "UP",
# checks that the running version is the version we just built, and calls
# one real API endpoint.
#
# Usage:  bash scripts/verify-deployment.sh [base-url] [expected-version]
#         bash scripts/verify-deployment.sh http://localhost:3000 1.0.5
# =============================================================================
set -euo pipefail

BASE_URL="${1:-http://localhost:3000}"
EXPECTED_VERSION="${2:-}"
ATTEMPTS="${ATTEMPTS:-20}"

log()  { printf '\033[1;34m[verify]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK   ]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[FAIL  ]\033[0m %s\n' "$*" >&2; exit 1; }

log "Waiting for $BASE_URL/health ..."
HEALTH=""
i=1
while [ "$i" -le "$ATTEMPTS" ]; do
  HEALTH=$(curl -sf --max-time 3 "$BASE_URL/health" || true)
  if printf '%s' "$HEALTH" | grep -q '"status":"UP"'; then
    break
  fi
  HEALTH=""
  sleep 2
  i=$((i + 1))
done
[ -n "$HEALTH" ] || fail "Application did not become healthy. Check: docker logs nexus-artifact-demo-app"
ok "Health check: $HEALTH"

if [ -n "$EXPECTED_VERSION" ]; then
  if printf '%s' "$HEALTH" | grep -q "\"version\":\"$EXPECTED_VERSION\""; then
    ok "Running version is $EXPECTED_VERSION (the artifact downloaded from Nexus)"
  else
    fail "Expected version $EXPECTED_VERSION but the app reports: $HEALTH"
  fi
fi

CALC=$(curl -sf "$BASE_URL/api/calculate?op=multiply&a=6&b=7" || true)
printf '%s' "$CALC" | grep -q '"result":42' || fail "API check failed: $CALC"
ok "API check: /api/calculate?op=multiply&a=6&b=7 -> $CALC"

curl -sf "$BASE_URL/" | grep -q "Automated Artifact Management Using Nexus Repository" \
  || fail "Home page does not show the project title"
ok "Home page is served"

echo
ok "Deployment verified. Open $BASE_URL in your browser."
