// Serves the web build (build/web) over HTTPS on the local network, so the
// app can be opened in a phone's browser (e.g. Safari on an iPhone), and
// passes /api/* — plain requests and the realtime WebSocket — on to the
// backend on this machine. HTTPS because browsers only give location to
// secure pages; one origin for page and API, so no CORS or mixed content.
//
//   flutter build web && node tool/web_serve.mjs
//
// The certificate is self-signed (made on first run into tool/.certs, for
// this machine's LAN addresses), so the phone shows a warning once:
// Safari → "Show Details" → "visit this website".
//
// Dev only. Env: PORT (default 8443), BACKEND (default http://localhost:3000).

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, statSync, createReadStream } from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import net from 'node:net';
import { networkInterfaces } from 'node:os';
import { dirname, extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', 'build', 'web');
const port = Number(process.env.PORT ?? 8443);
const backend = new URL(process.env.BACKEND ?? 'http://localhost:3000');

const lanAddresses = Object.values(networkInterfaces())
  .flat()
  .filter((a) => a && a.family === 'IPv4' && !a.internal)
  .map((a) => a.address);

function certificate() {
  const dir = join(here, '.certs');
  const key = join(dir, 'key.pem');
  const cert = join(dir, 'cert.pem');
  const ips = ['127.0.0.1', ...lanAddresses];
  const stamp = join(dir, 'ips');
  // Remade when the machine's addresses change (another Wi-Fi network).
  if (!existsSync(cert) || !existsSync(stamp) || readFileSync(stamp, 'utf8') !== ips.join(',')) {
    mkdirSync(dir, { recursive: true });
    const san = ['DNS:localhost', ...ips.map((ip) => `IP:${ip}`)].join(',');
    execFileSync('openssl', [
      'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '365',
      '-keyout', key, '-out', cert, '-subj', '/CN=HERE dev', '-addext', `subjectAltName=${san}`,
    ], { stdio: 'ignore' });
    execFileSync('sh', ['-c', `printf %s "${ips.join(',')}" > "${stamp}"`]);
  }
  return { key: readFileSync(key), cert: readFileSync(cert) };
}

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wav': 'audio/wav',
  '.mp3': 'audio/mpeg',
  '.ico': 'image/x-icon',
};

/// "/api/area/summary?x" → "/area/summary?x"; "/api/?token=…" → "/?token=…".
const backendPath = (url) => {
  const rest = url.slice('/api'.length);
  return rest.startsWith('/') ? rest : `/${rest}`;
};

function proxy(req, res) {
  const upstream = http.request(
    {
      host: backend.hostname,
      port: backend.port,
      method: req.method,
      path: backendPath(req.url),
      headers: { ...req.headers, host: backend.host },
    },
    (reply) => {
      res.writeHead(reply.statusCode ?? 502, reply.headers);
      reply.pipe(res);
    },
  );
  upstream.on('error', () => {
    if (!res.headersSent) res.writeHead(502, { 'content-type': 'text/plain' });
    res.end('Backend not reachable');
  });
  req.pipe(upstream);
}

function serveFile(req, res) {
  const path = normalize(decodeURIComponent(new URL(req.url, 'https://x').pathname));
  let file = join(root, path);
  if (!file.startsWith(root)) {
    res.writeHead(403).end();
    return;
  }
  if (!existsSync(file) || statSync(file).isDirectory()) file = join(root, 'index.html');
  res.writeHead(200, {
    'content-type': types[extname(file)] ?? 'application/octet-stream',
    // Always the latest build while developing.
    'cache-control': 'no-cache',
  });
  createReadStream(file).pipe(res);
}

const server = https.createServer(certificate(), (req, res) => {
  if (req.url === '/api' || req.url.startsWith('/api/') || req.url.startsWith('/api?')) proxy(req, res);
  else serveFile(req, res);
});

// WebSocket upgrades: replay the handshake to the backend, then splice the
// two sockets together.
server.on('upgrade', (req, socket, head) => {
  if (!req.url.startsWith('/api')) {
    socket.destroy();
    return;
  }
  const upstream = net.connect(Number(backend.port), backend.hostname, () => {
    const headers = { ...req.headers, host: backend.host };
    const lines = [`${req.method} ${backendPath(req.url)} HTTP/1.1`];
    for (const [name, value] of Object.entries(headers)) {
      for (const v of Array.isArray(value) ? value : [value]) lines.push(`${name}: ${v}`);
    }
    upstream.write(`${lines.join('\r\n')}\r\n\r\n`);
    if (head?.length) upstream.write(head);
    upstream.pipe(socket);
    socket.pipe(upstream);
  });
  const close = () => {
    socket.destroy();
    upstream.destroy();
  };
  upstream.on('error', close);
  socket.on('error', close);
});

server.listen(port, '0.0.0.0', () => {
  console.log(`HERE web: serving ${root}`);
  console.log(`API → ${backend.origin}`);
  for (const ip of lanAddresses) console.log(`  open on your phone: https://${ip}:${port}`);
});
