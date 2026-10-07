#!/usr/bin/env bash
# Shared helpers for the Nexus scripts. Sourced by the other scripts, not run directly.
# Works on macOS (bash 3.2 + BSD tools) and Linux.

NEXUS_URL="${NEXUS_URL:-http://localhost:8081}"
NEXUS_REPO="${NEXUS_REPO:-devops-artifacts}"
APP_NAME="${APP_NAME:-nexus-artifact-demo}"

log()  { printf '\033[1;34m[nexus]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK  ]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[FAIL ]\033[0m %s\n' "$*" >&2; exit 1; }

require_credentials() {
  [ -n "${NEXUS_USER:-}" ]     || fail "NEXUS_USER is not set (Jenkins: check the 'nexus-credentials' credential; manual: copy .env.example to .env)"
  [ -n "${NEXUS_PASSWORD:-}" ] || fail "NEXUS_PASSWORD is not set"
}

# Prints a curl config line with the credentials. It is passed to curl on
# stdin (-K -) so the password never appears in the process list or logs.
curl_auth_config() {
  local u p
  u=$(printf '%s' "$NEXUS_USER"     | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  p=$(printf '%s' "$NEXUS_PASSWORD" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  printf 'user = "%s:%s"\n' "$u" "$p"
}

# sha1 of a file (shasum on macOS, sha1sum on Linux)
sha1_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 1 "$1" | awk '{print $1}'
  else
    sha1sum "$1" | awk '{print $1}'
  fi
}

# Fails with a helpful message if Nexus is not reachable.
check_nexus_up() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$NEXUS_URL/service/rest/v1/status" || true)
  if [ "$code" != "200" ]; then
    fail "Nexus is not reachable at $NEXUS_URL (HTTP '$code'). Is the container running? Try: docker compose up -d nexus && docker logs -f nexus"
  fi
  ok "Nexus is up at $NEXUS_URL"
}

# Base URL of a version folder inside the raw repository
artifact_base_url() {
  printf '%s/repository/%s/%s/%s' "$NEXUS_URL" "$NEXUS_REPO" "$APP_NAME" "$1"
}

# Prints the SHA-1 that Nexus has on record for <base-url>/<file>.
# 1st choice: the checksum Nexus computes itself (<file>.sha1).
# Fallback:   the sha1 recorded in build-info.json at publish time.
remote_sha1() {
  local base="$1" file="$2" sum
  sum=$(curl_auth_config | curl -sf -K - "$base/$file.sha1" 2>/dev/null | awk '{print $1}' || true)
  if ! printf '%s' "$sum" | grep -Eq '^[0-9a-f]{40}$'; then
    sum=$(curl_auth_config | curl -sf -K - "$base/build-info.json" 2>/dev/null \
            | sed -n 's/.*"sha1": *"\([0-9a-f]\{40\}\)".*/\1/p' || true)
  fi
  printf '%s' "$sum"
}

explain_http_error() {
  case "$1" in
    401) echo "401 Unauthorized -> wrong Nexus username/password (check the Jenkins credential 'nexus-credentials')." ;;
    403) echo "403 Forbidden -> the user has no permission on repository '$NEXUS_REPO' (give its role nx-repository-view-raw-$NEXUS_REPO-*)." ;;
    404) echo "404 Not Found -> repository '$NEXUS_REPO' does not exist (create a 'raw (hosted)' repository with exactly this name) or this version was never uploaded." ;;
    400) echo "400 Bad Request -> this version already exists and the repository has 'Disable redeploy' (use a new version/build number)." ;;
    000) echo "No HTTP response -> Nexus is down or NEXUS_URL is wrong." ;;
    *)   echo "Unexpected HTTP status $1." ;;
  esac
}
