# =============================================================================
# Dockerfile - builds the runtime image FROM THE NEXUS ARTIFACT
#
# The pipeline first downloads the versioned artifact from Nexus into
# artifact/app.tgz. This Dockerfile only copies that file (see .dockerignore:
# nothing else from the workspace is visible to Docker), so the image always
# contains exactly the artifact that is stored in Nexus.
# =============================================================================

# Official Node.js LTS image, Alpine variant = small image
FROM node:24-alpine

ARG APP_VERSION=unknown
LABEL org.opencontainers.image.title="nexus-artifact-demo" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.description="Automated Artifact Management Using Nexus Repository" \
      org.opencontainers.image.authors="Kashvi Vora, Rushabh Vora"

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

# 1) copy the artifact that was downloaded from Nexus
COPY artifact/app.tgz /tmp/app.tgz

# 2) unpack it (npm pack puts files under "package/") and install
#    production dependencies only (no Jest etc.)
RUN tar -xzf /tmp/app.tgz --strip-components=1 -C /app \
    && rm /tmp/app.tgz \
    && npm install --omit=dev --no-audit --no-fund \
    && npm cache clean --force \
    && chown -R node:node /app

# 3) do not run as root
USER node

# 4) the port the Express app listens on
EXPOSE 3000

# 5) Docker marks the container healthy/unhealthy using our /health endpoint
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

# 6) start the application
CMD ["node", "src/server.js"]
