#!/usr/bin/env bash
# =============================================================================
# download-from-nexus.sh
# Downloads a specific version of the application artifact FROM Nexus and
# verifies its SHA-1 checksum. The Docker image is built from this downloaded
# file (not from the local source code), which proves that deployments use
# the artifact stored in Nexus.
#
# Usage:  bash scripts/download-from-nexus.sh <version> [destination-file]
#         bash scripts/download-from-nexus.sh 1.0.5 artifact/app.tgz
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

VERSION="${1:-}"
DEST="${2:-artifact/app.tgz}"
[ -n "$VERSION" ] || fail "Usage: $0 <version> [destination-file]"

require_credentials
check_nexus_up

FILE_NAME="${APP_NAME}-${VERSION}.tgz"
URL="$(artifact_base_url "$VERSION")/$FILE_NAME"

mkdir -p "$(dirname "$DEST")"
rm -f "$DEST"

log "Downloading $URL"
code=$(curl_auth_config | curl -s -K - -o "$DEST" -w '%{http_code}' "$URL" || true)
if [ "$code" != "200" ]; then
  rm -f "$DEST"
  fail "Download failed: $(explain_http_error "$code")"
fi
ok "Downloaded to $DEST ($(wc -c < "$DEST" | tr -d ' ') bytes)"

EXPECTED_SHA1=$(remote_sha1 "$(artifact_base_url "$VERSION")" "$FILE_NAME")
ACTUAL_SHA1=$(sha1_of "$DEST")
if [ -z "$EXPECTED_SHA1" ] || [ "$EXPECTED_SHA1" != "$ACTUAL_SHA1" ]; then
  fail "Checksum verification failed (nexus='$EXPECTED_SHA1', downloaded=$ACTUAL_SHA1)"
fi
ok "Checksum verified: $ACTUAL_SHA1"

# Show what is inside the artifact (useful during the demo)
log "Artifact contents:"
tar -tzf "$DEST" | sed 's/^/    /'
