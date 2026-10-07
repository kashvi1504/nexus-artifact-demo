#!/usr/bin/env bash
# =============================================================================
# local-pipeline.sh
# Runs the SAME stages as the Jenkinsfile, but directly from your terminal.
# Use it to:
#   - test Nexus + Docker before Jenkins is set up
#   - have a backup during the demo if Jenkins misbehaves
#
# Usage:  cp .env.example .env   (then put your Nexus user/password in .env)
#         bash scripts/local-pipeline.sh
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  set -a; . ./.env; set +a
fi

APP_NAME="nexus-artifact-demo"
NEXUS_URL="${NEXUS_URL:-http://localhost:8081}"
NEXUS_REPO="${NEXUS_REPO:-devops-artifacts}"
APP_PORT="${APP_PORT:-3000}"
CONTAINER_NAME="${CONTAINER_NAME:-nexus-artifact-demo-app}"
# Local runs get a unique pre-release version, e.g. 1.0.0-local.1728212345
APP_VERSION="${APP_VERSION:-1.0.0-local.$(date +%s)}"
export APP_NAME NEXUS_URL NEXUS_REPO APP_VERSION

stage() { printf '\n\033[1;35m==== STAGE: %s ====\033[0m\n' "$*"; }

stage "Install Dependencies"
npm ci

stage "Automated Tests"
npm test

stage "Build / Package (version $APP_VERSION)"
# Work on a copy of package.json so the repo file is not modified
cp package.json package.json.bak; cp package-lock.json package-lock.json.bak
trap 'mv -f package.json.bak package.json; mv -f package-lock.json.bak package-lock.json' EXIT
npm version "$APP_VERSION" --no-git-tag-version
rm -rf dist && mkdir -p dist
npm pack --pack-destination dist
ls -l dist

stage "Publish Artifact to Nexus"
bash scripts/publish-to-nexus.sh "dist/${APP_NAME}-${APP_VERSION}.tgz"

stage "Fetch Artifact from Nexus"
rm -rf artifact
bash scripts/download-from-nexus.sh "$APP_VERSION" artifact/app.tgz

stage "Build Docker Image"
docker build -t "${APP_NAME}:${APP_VERSION}" -t "${APP_NAME}:latest" .

stage "Deploy Application"
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
docker run -d --name "$CONTAINER_NAME" -p "${APP_PORT}:3000" --restart unless-stopped \
  -e BUILD_NUMBER="local" \
  -e GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo local)" \
  -e ARTIFACT_SOURCE="${NEXUS_URL}/repository/${NEXUS_REPO}/${APP_NAME}/${APP_VERSION}/${APP_NAME}-${APP_VERSION}.tgz" \
  "${APP_NAME}:${APP_VERSION}"

stage "Verify Deployment"
bash scripts/verify-deployment.sh "http://localhost:${APP_PORT}" "$APP_VERSION"
