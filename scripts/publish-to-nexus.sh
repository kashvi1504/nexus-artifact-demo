#!/usr/bin/env bash
# =============================================================================
# publish-to-nexus.sh
# Uploads the packaged application (.tgz made by `npm pack`) to the Nexus
# "raw (hosted)" repository, together with a small build-info.json file.
#
# Usage:   bash scripts/publish-to-nexus.sh dist/nexus-artifact-demo-1.0.5.tgz
#
# Needs these environment variables (Jenkins injects the credentials):
#   NEXUS_USER, NEXUS_PASSWORD       - Nexus account (never hardcode these)
#   NEXUS_URL   (default http://localhost:8081)
#   NEXUS_REPO  (default devops-artifacts)
#   APP_VERSION (default: read from the file name)
#   BUILD_NUMBER, GIT_COMMIT, BUILD_URL (optional, set by Jenkins)
#
# Result in Nexus:
#   devops-artifacts/
#     nexus-artifact-demo/
#       1.0.5/
#         nexus-artifact-demo-1.0.5.tgz   <- the artifact
#         build-info.json                 <- who/what/when built it
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

ARTIFACT_FILE="${1:-}"
[ -n "$ARTIFACT_FILE" ] || fail "Usage: $0 <path-to-artifact.tgz>"
[ -f "$ARTIFACT_FILE" ] || fail "Artifact file not found: $ARTIFACT_FILE (did the Build/Package stage run?)"

FILE_NAME="$(basename "$ARTIFACT_FILE")"
# nexus-artifact-demo-1.0.5.tgz -> 1.0.5
APP_VERSION="${APP_VERSION:-$(printf '%s' "$FILE_NAME" | sed -e "s/^${APP_NAME}-//" -e 's/\.tgz$//')}"

require_credentials
check_nexus_up

BASE_URL="$(artifact_base_url "$APP_VERSION")"
SHA1="$(sha1_of "$ARTIFACT_FILE")"

log "Artifact : $FILE_NAME"
log "Version  : $APP_VERSION"
log "SHA-1    : $SHA1"
log "Target   : $BASE_URL/$FILE_NAME"

upload() {   # upload <local-file> <remote-name>
  local code
  code=$(curl_auth_config | curl -s -K - -o /tmp/nexus-upload-response.$$ -w '%{http_code}' \
          --upload-file "$1" "$BASE_URL/$2" || true)
  if [ "$code" != "201" ] && [ "$code" != "200" ] && [ "$code" != "204" ]; then
    cat /tmp/nexus-upload-response.$$ 2>/dev/null || true
    rm -f /tmp/nexus-upload-response.$$
    fail "Upload of $2 failed: $(explain_http_error "$code")"
  fi
  rm -f /tmp/nexus-upload-response.$$
  ok "Uploaded $2 (HTTP $code)"
}

# 1) the application artifact
upload "$ARTIFACT_FILE" "$FILE_NAME"

# 2) build metadata, so anyone can trace an artifact back to its build/commit
INFO_FILE="$(dirname "$ARTIFACT_FILE")/build-info.json"
cat > "$INFO_FILE" <<EOF
{
  "name": "$APP_NAME",
  "version": "$APP_VERSION",
  "artifact": "$FILE_NAME",
  "sha1": "$SHA1",
  "jenkinsBuildNumber": "${BUILD_NUMBER:-manual}",
  "jenkinsBuildUrl": "${BUILD_URL:-n/a}",
  "gitCommit": "${GIT_COMMIT:-unknown}",
  "builtAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
upload "$INFO_FILE" "build-info.json"

# 3) confirm Nexus really stores it: download it back and compare checksums
CHECK_FILE="$(dirname "$ARTIFACT_FILE")/.nexus-roundtrip.tgz"
curl_auth_config | curl -sf -K - -o "$CHECK_FILE" "$BASE_URL/$FILE_NAME" \
  || fail "Could not download the artifact back from Nexus for verification"
REMOTE_SHA1="$(sha1_of "$CHECK_FILE")"
rm -f "$CHECK_FILE"
if [ "$REMOTE_SHA1" = "$SHA1" ]; then
  ok "Verified: the copy stored in Nexus is identical to the build output (sha1 $SHA1)"
else
  fail "Checksum mismatch after upload (local=$SHA1, nexus=$REMOTE_SHA1)"
fi

echo
ok "Artifact published to Nexus:"
echo "    $BASE_URL/$FILE_NAME"
echo "    Browse: $NEXUS_URL/#browse/browse:$NEXUS_REPO"
