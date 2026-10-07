const request = require('supertest');
const { createApp, escapeHtml, PROJECT_TITLE } = require('../src/app');
const pkg = require('../package.json');

const app = createApp();

describe('web application - API tests', () => {
  test('GET / returns the home page with the project title', async () => {
    const res = await request(app).get('/');
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/html/);
    expect(res.text).toContain(PROJECT_TITLE);
    expect(res.text).toContain('Kashvi Vora');
    expect(res.text).toContain('Rushabh Vora');
  });

  test('GET /health reports status UP and the app version', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('UP');
    expect(res.body.version).toBe(pkg.version);
  });

  test('GET /api/info returns build information', async () => {
    const res = await request(app).get('/api/info');
    expect(res.status).toBe(200);
    expect(res.body.name).toBe('nexus-artifact-demo');
    expect(res.body.version).toBe(pkg.version);
    expect(res.body.team).toEqual(['Kashvi Vora', 'Rushabh Vora']);
  });

  test('GET /api/info picks up Jenkins build variables', async () => {
    process.env.BUILD_NUMBER = '42';
    process.env.GIT_COMMIT = 'abc1234';
    const res = await request(app).get('/api/info');
    expect(res.body.buildNumber).toBe('42');
    expect(res.body.gitCommit).toBe('abc1234');
    delete process.env.BUILD_NUMBER;
    delete process.env.GIT_COMMIT;
  });

  test('GET /api/calculate adds two numbers', async () => {
    const res = await request(app).get('/api/calculate?op=add&a=10&b=5');
    expect(res.status).toBe(200);
    expect(res.body.result).toBe(15);
  });

  test('GET /api/calculate returns 400 for division by zero', async () => {
    const res = await request(app).get('/api/calculate?op=divide&a=1&b=0');
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Division by zero/);
  });

  test('GET /api/calculate returns 400 for bad input', async () => {
    const res = await request(app).get('/api/calculate?op=add&a=x&b=1');
    expect(res.status).toBe(400);
  });

  test('unknown routes return 404', async () => {
    const res = await request(app).get('/does-not-exist');
    expect(res.status).toBe(404);
  });

  test('escapeHtml prevents HTML injection on the home page', () => {
    expect(escapeHtml('<script>"x"</script>')).toBe(
      '&lt;script&gt;&quot;x&quot;&lt;/script&gt;'
    );
  });
});
