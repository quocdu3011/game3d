#!/usr/bin/env node
/**
 * Lobby server cho game3d — quản lý phòng chơi qua Internet bằng Room ID.
 *
 * Mỗi phòng = một tiến trình Godot headless (dedicated server) do lobby tự
 * khởi động ở một port riêng. Cả host lẫn guest đều kết nối RA NGOÀI tới
 * server phòng, nên không ai cần mở port trên máy mình.
 *
 * REST API:
 *   POST /create          -> {"room":"123456","port":9101}
 *   GET  /resolve?room=X  -> {"room":"X","port":9101}  (404 nếu không tồn tại)
 *   GET  /health          -> trạng thái tổng quan
 *
 * Biến môi trường:
 *   GODOT_BIN   đường dẫn binary Godot (bắt buộc khi tạo phòng)
 *   PROJECT_PATH đường dẫn dự án (mặc định: thư mục cha của file này)
 *   PORT        port của lobby (mặc định 9080)
 *   PORT_MIN/PORT_MAX dải port cho các phòng (mặc định 9100-9159)
 *   ROOM_TTL_MIN phút — phòng bị đóng sau thời gian này (mặc định 60)
 */
const http = require('http');
const { spawn } = require('child_process');
const path = require('path');
const net = require('net');

const PORT = parseInt(process.env.PORT || '9080', 10);
const PORT_MIN = parseInt(process.env.PORT_MIN || '9100', 10);
const PORT_MAX = parseInt(process.env.PORT_MAX || '9159', 10);
const ROOM_TTL_MS = parseInt(process.env.ROOM_TTL_MIN || '60', 10) * 60 * 1000;
const GODOT_BIN = process.env.GODOT_BIN || '';
const PROJECT_PATH = process.env.PROJECT_PATH || path.resolve(__dirname, '..');

// roomId -> { port, proc, createdAt }
const rooms = new Map();
const usedPorts = new Set();

function genRoomId() {
  let id;
  do { id = String(100000 + Math.floor(Math.random() * 900000)); } while (rooms.has(id));
  return id;
}

function allocPort() {
  for (let p = PORT_MIN; p <= PORT_MAX; p++) {
    if (!usedPorts.has(p)) { usedPorts.add(p); return p; }
  }
  return null;
}

function killRoom(roomId, reason) {
  const room = rooms.get(roomId);
  if (!room) return;
  rooms.delete(roomId);
  usedPorts.delete(room.port);
  if (room.proc && room.proc.exitCode === null) {
    room.proc.kill('SIGTERM');
    setTimeout(() => { try { room.proc.kill('SIGKILL'); } catch {} }, 5000);
  }
  console.log(`Dong phong ${roomId} (${reason})`);
}

function spawnRoom(roomId, port) {
  if (!GODOT_BIN) throw new Error('GODOT_BIN chua duoc cau hinh');
  const proc = spawn(GODOT_BIN, [
    '--headless', '--path', PROJECT_PATH,
    'res://scenes/dedicated_room.tscn',
    '--', `--port=${port}`, `--room=${roomId}`,
  ], { stdio: ['ignore', 'pipe', 'pipe'] });

  proc.stdout.on('data', (d) => process.stdout.write(`[${roomId}] ${d}`));
  proc.stderr.on('data', (d) => process.stderr.write(`[${roomId}] ${d}`));
  proc.on('exit', () => {
    if (rooms.has(roomId)) killRoom(roomId, 'tien trinh ket thuc');
  });
  return proc;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const json = (code, obj) => {
    res.writeHead(code, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(obj));
  };

  if (req.method === 'GET' && url.pathname === '/health') {
    return json(200, { ok: true, rooms: rooms.size, ports_in_use: usedPorts.size });
  }

  if (req.method === 'POST' && url.pathname === '/create') {
    if (!GODOT_BIN) return json(500, { err: 'GODOT_NOT_CONFIGURED' });
    if (rooms.size >= PORT_MAX - PORT_MIN + 1) return json(503, { err: 'SERVER_FULL' });
    const port = allocPort();
    if (!port) return json(503, { err: 'NO_FREE_PORT' });
    const roomId = genRoomId();
    let proc;
    try {
      proc = spawnRoom(roomId, port);
    } catch (e) {
      usedPorts.delete(port);
      return json(500, { err: 'SPAWN_FAILED', detail: String(e) });
    }
    rooms.set(roomId, { port, proc, createdAt: Date.now() });
    setTimeout(() => killRoom(roomId, 'het thoi gian (TTL)'), ROOM_TTL_MS);
    console.log(`Tao phong ${roomId} o port ${port}`);
    return json(200, { room: roomId, port });
  }

  if (req.method === 'GET' && url.pathname === '/resolve') {
    const roomId = url.searchParams.get('room') || '';
    const room = rooms.get(roomId);
    if (!room) return json(404, { err: 'ROOM_NOT_FOUND' });
    return json(200, { room: roomId, port: room.port });
  }

  res.writeHead(404);
  res.end();
});

server.listen(PORT, () => {
  console.log(`Lobby dang chay tai port ${PORT}`);
  if (!GODOT_BIN) console.log('CANH BAO: GODOT_BIN chua dat, khong tao duoc phong!');
});
