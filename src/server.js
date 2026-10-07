const { createApp } = require('./app');
const pkg = require('../package.json');

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || '0.0.0.0'; // 0.0.0.0 so it is reachable inside Docker

const app = createApp();

const server = app.listen(PORT, HOST, () => {
  console.log(`${pkg.name} v${pkg.version} listening on http://localhost:${PORT}`);
});

// Graceful shutdown so "docker stop" exits cleanly
function shutdown(signal) {
  console.log(`${signal} received, shutting down...`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 5000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
