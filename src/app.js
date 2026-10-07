const express = require('express');
const pkg = require('../package.json');
const { calculate } = require('./utils/calculator');

const PROJECT_TITLE = 'Automated Artifact Management Using Nexus Repository';
const TEAM = ['Kashvi Vora', 'Rushabh Vora'];

/**
 * Information about the running build.
 * - version comes from package.json INSIDE the artifact, so the page proves
 *   which artifact version (from Nexus) is actually deployed.
 * - BUILD_NUMBER / GIT_COMMIT / ARTIFACT_SOURCE are passed in by Jenkins
 *   as environment variables when the container is started.
 */
function getBuildInfo() {
  return {
    name: pkg.name,
    version: pkg.version,
    buildNumber: process.env.BUILD_NUMBER || 'local',
    gitCommit: process.env.GIT_COMMIT || 'local',
    artifactSource: process.env.ARTIFACT_SOURCE || 'local source code',
    environment: process.env.NODE_ENV || 'development',
    nodeVersion: process.version,
  };
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function renderHomePage(info) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(PROJECT_TITLE)}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
           margin: 0; background: #f4f6fb; color: #1f2937; }
    header { background: #1b5e8a; color: #fff; padding: 28px 24px; }
    header h1 { margin: 0 0 6px; font-size: 26px; }
    header p { margin: 0; opacity: .85; }
    main { max-width: 860px; margin: 24px auto; padding: 0 16px; }
    .card { background: #fff; border-radius: 10px; padding: 20px 24px; margin-bottom: 18px;
            box-shadow: 0 1px 3px rgba(0,0,0,.08); }
    .card h2 { margin-top: 0; font-size: 18px; color: #1b5e8a; }
    table { border-collapse: collapse; width: 100%; }
    td { padding: 6px 8px; border-bottom: 1px solid #eef0f4; vertical-align: top; }
    td:first-child { font-weight: 600; width: 180px; }
    code { background: #eef2f7; padding: 2px 6px; border-radius: 4px; word-break: break-all; }
    .badge { display: inline-block; background: #16a34a; color: #fff; padding: 3px 10px;
             border-radius: 999px; font-size: 13px; }
    .flow { font-family: monospace; font-size: 14px; line-height: 1.6; }
  </style>
</head>
<body>
  <header>
    <h1>${escapeHtml(PROJECT_TITLE)}</h1>
    <p>DevOps Mini Project &middot; Team: ${TEAM.map(escapeHtml).join(' &amp; ')}</p>
  </header>
  <main>
    <div class="card">
      <h2>Deployment status <span class="badge">RUNNING v2</span></h2>
      <table>
        <tr><td>Application</td><td>${escapeHtml(info.name)}</td></tr>
        <tr><td>Artifact version</td><td><code>${escapeHtml(info.version)}</code></td></tr>
        <tr><td>Jenkins build</td><td>#${escapeHtml(info.buildNumber)}</td></tr>
        <tr><td>Git commit</td><td><code>${escapeHtml(info.gitCommit)}</code></td></tr>
        <tr><td>Artifact source</td><td><code>${escapeHtml(info.artifactSource)}</code></td></tr>
        <tr><td>Environment</td><td>${escapeHtml(info.environment)}</td></tr>
        <tr><td>Node.js</td><td>${escapeHtml(info.nodeVersion)}</td></tr>
      </table>
    </div>
    <div class="card">
      <h2>Pipeline</h2>
      <div class="flow">GitHub &rarr; Jenkins &rarr; npm ci &rarr; Jest tests &rarr; npm pack (.tgz)
        &rarr; <b>Nexus Repository</b> &rarr; download from Nexus &rarr; Docker image &rarr; Container</div>
    </div>
    <div class="card">
      <h2>Try the API</h2>
      <ul>
        <li><a href="/health">/health</a> &ndash; health check used by the pipeline</li>
        <li><a href="/api/info">/api/info</a> &ndash; build and artifact information (JSON)</li>
        <li><a href="/api/calculate?op=add&amp;a=10&amp;b=5">/api/calculate?op=add&amp;a=10&amp;b=5</a>
          &ndash; calculator (add, subtract, multiply, divide)</li>
      </ul>
    </div>
  </main>
</body>
</html>`;
}

function createApp() {
  const app = express();
  app.disable('x-powered-by');

  // Home page
  app.get('/', (req, res) => {
    res.type('html').send(renderHomePage(getBuildInfo()));
  });

  // Health check (used by Jenkins "Verify Deployment" stage and Docker HEALTHCHECK)
  app.get('/health', (req, res) => {
    res.json({
      status: 'UP',
      version: pkg.version,
      uptimeSeconds: Math.round(process.uptime()),
      timestamp: new Date().toISOString(),
    });
  });

  // Build / artifact information
  app.get('/api/info', (req, res) => {
    res.json({ project: PROJECT_TITLE, team: TEAM, ...getBuildInfo() });
  });

  // Calculator API: /api/calculate?op=add&a=2&b=3
  app.get('/api/calculate', (req, res) => {
    const { op, a, b } = req.query;
    try {
      const result = calculate(op, a, b);
      res.json({ op, a: Number(a), b: Number(b), result });
    } catch (err) {
      res.status(400).json({ error: err.message });
    }
  });

  // 404 for everything else
  app.use((req, res) => {
    res.status(404).json({ error: `Route ${req.method} ${req.path} not found` });
  });

  return app;
}

module.exports = { createApp, getBuildInfo, escapeHtml, PROJECT_TITLE };
