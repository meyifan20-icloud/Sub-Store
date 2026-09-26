import http from 'node:http';

const port = Number(process.env.SUB_STORE_BACKEND_API_PORT || 3001);
const prefix = process.env.SUB_STORE_FRONTEND_BACKEND_PATH || '';
const normalized = prefix === '/' ? '' : prefix.replace(/\/$/, '');
const path = `${normalized}/api/utils/env`;

const req = http.get(
  {
    host: '127.0.0.1',
    port,
    path,
    timeout: 5000,
  },
  (res) => {
    res.resume();
    process.exit(res.statusCode && res.statusCode >= 200 && res.statusCode < 400 ? 0 : 1);
  },
);

req.on('timeout', () => {
  req.destroy();
  process.exit(1);
});
req.on('error', () => process.exit(1));
