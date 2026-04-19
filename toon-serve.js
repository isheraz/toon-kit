#!/usr/bin/env node
/**
 * ton serve — TOON Context Broker
 * Reads .toon files, decompresses to JSON, serves over HTTP
 * Port: 7878 (or TOON_SERVE_PORT env var)
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const { TOONConverter } = require('./converter.js');

const PORT = parseInt(process.env.TOON_SERVE_PORT || '7878');
const CONTEXT_DIR = process.env.TOON_CONTEXT_DIR ||
  path.join(process.env.HOME, '.claude', 'toon-context');
const PID_FILE = path.join(CONTEXT_DIR, '.ton-serve.pid');
const START_TIME = Date.now();

// Write PID file for process management
fs.mkdirSync(CONTEXT_DIR, { recursive: true });
fs.writeFileSync(PID_FILE, String(process.pid));
process.on('exit', () => { try { fs.unlinkSync(PID_FILE); } catch {} });
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));

function loadContext(name) {
  const file = path.join(CONTEXT_DIR, `${name}.toon`);
  if (!fs.existsSync(file)) return null;
  const toonStr = fs.readFileSync(file, 'utf-8');
  return TOONConverter.toonToJson(toonStr);
}

function loadAllContexts() {
  const result = {};
  if (!fs.existsSync(CONTEXT_DIR)) return result;
  const files = fs.readdirSync(CONTEXT_DIR).filter(f => f.endsWith('.toon'));
  for (const file of files) {
    const name = file.replace('.toon', '');
    try {
      const toonStr = fs.readFileSync(path.join(CONTEXT_DIR, file), 'utf-8');
      result[name] = TOONConverter.toonToJson(toonStr);
    } catch { result[name] = null; }
  }
  return result;
}

function respond(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
  res.end(JSON.stringify(body, null, 2));
}

const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];
  if (req.method !== 'GET') return respond(res, 405, { error: 'Method not allowed' });

  if (url === '/health') {
    const files = fs.existsSync(CONTEXT_DIR)
      ? fs.readdirSync(CONTEXT_DIR).filter(f => f.endsWith('.toon')).length : 0;
    return respond(res, 200, { status: 'ok', port: PORT, pid: process.pid,
      uptime: Math.floor((Date.now() - START_TIME) / 1000), files, context_dir: CONTEXT_DIR });
  }

  if (url === '/context') return respond(res, 200, loadAllContexts());

  const nameMatch = url.match(/^\/context\/(.+)$/);
  if (nameMatch) {
    const ctx = loadContext(decodeURIComponent(nameMatch[1]));
    if (!ctx) return respond(res, 404, { error: 'Context not found' });
    return respond(res, 200, ctx);
  }

  respond(res, 404, { error: 'Not found. Endpoints: /health, /context, /context/:name' });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`ton serve: listening on http://127.0.0.1:${PORT}`);
  console.log(`context dir: ${CONTEXT_DIR}`);
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`ton serve: port ${PORT} already in use. Set TOON_SERVE_PORT to use a different port.`);
    process.exit(1);
  }
  throw err;
});
