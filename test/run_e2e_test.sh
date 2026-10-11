#!/bin/bash
# Test end-to-end: tao phong qua lobby -> 2 client headless join theo Room ID
#
# Script tu khoi dong/tat lobby relay. Truoc day script khong bat relay nen
# create_room() luon that bai voi "Lobby tu choi tao phong (HTTP 0)".
#
# Bien moi truong:
#   GODOT_BIN   duong dan binary Godot (mac dinh: tim trong ~/Ban tai ve)
#   LOBBY_PORT  port lobby (mac dinh 9080)
#   ROOM_PORT_MIN/ROOM_PORT_MAX  dai port cho cac phong (mac dinh 9100-9159)
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Tu tim binary Godot: env -> PATH -> thu muc tai ve trong home. Khong hardcode
# duong dan co dau tieng Viet de khong hong khi doi ten thu muc.
GODOT="${GODOT_BIN:-}"
if [ -z "$GODOT" ]; then
	GODOT="$(find "$HOME" -maxdepth 2 -type f -name 'Godot_v4*-stable_linux*.x86_64' 2>/dev/null | head -1)"
fi
if [ ! -x "$GODOT" ]; then
  echo "LOI: khong tim thay binary Godot. Dat bien GODOT_BIN." >&2
  exit 1
fi

export LOBBY_PORT="${LOBBY_PORT:-9080}"
ROOM_PORT_MIN="${ROOM_PORT_MIN:-9100}"
ROOM_PORT_MAX="${ROOM_PORT_MAX:-9159}"
export LOBBY_HOST="${LOBBY_HOST:-127.0.0.1}"

RELAY_PID=""
cleanup() {
  if [ -n "$RELAY_PID" ] && kill -0 "$RELAY_PID" 2>/dev/null; then
    kill "$RELAY_PID" 2>/dev/null
    wait "$RELAY_PID" 2>/dev/null
  fi
  pkill -f "res://scenes/dedicated_room.tscn" 2>/dev/null
}
trap cleanup EXIT

rm -f /tmp/p1.log /tmp/p2.log /tmp/relay.log

# --- Khoi dong lobby relay ---
GODOT_BIN="$GODOT" PROJECT_PATH="$PROJECT_DIR" PORT="$LOBBY_PORT" \
  PORT_MIN="$ROOM_PORT_MIN" PORT_MAX="$ROOM_PORT_MAX" \
  node relay/server.js > /tmp/relay.log 2>&1 &
RELAY_PID=$!

# Cho lobby san sang truoc khi client goi HTTP
READY=0
for _ in $(seq 1 40); do
  if curl -sf "http://$LOBBY_HOST:$LOBBY_PORT/health" > /dev/null 2>&1; then
    READY=1
    break
  fi
  if ! kill -0 "$RELAY_PID" 2>/dev/null; then
    break
  fi
  sleep 0.25
done

if [ "$READY" -ne 1 ]; then
  echo "LOI: lobby khong len duoc. Log:" >&2
  cat /tmp/relay.log >&2
  exit 1
fi
echo "Lobby san sang tren $LOBBY_HOST:$LOBBY_PORT"

# Client 1: tao phong (host)
timeout 40 "$GODOT" --headless --path . -s test/test_client.gd -- create > /tmp/p1.log 2>&1 &
P1=$!

ROOM=""
for _ in $(seq 1 60); do
  ROOM=$(grep -o 'ROOM=[0-9]*' /tmp/p1.log | cut -d= -f2)
  [ -n "$ROOM" ] && break
  sleep 0.5
done
echo "Room: $ROOM"

FAILED=0
if [ -z "$ROOM" ]; then
  echo "LOI: host khong tao duoc phong" >&2
  FAILED=1
else
  timeout 25 "$GODOT" --headless --path . -s test/test_client.gd -- join "$ROOM" > /tmp/p2.log 2>&1 &
  P2=$!
  sleep 8
  wait $P2 2>/dev/null
fi

kill $P1 2>/dev/null
wait $P1 2>/dev/null

echo "=== P1 (host) ==="; cat /tmp/p1.log
echo "=== P2 (guest) ==="; cat /tmp/p2.log

grep -q 'TEST_PASS' /tmp/p1.log || FAILED=1
if [ -n "$ROOM" ]; then
  grep -q 'TEST_PASS' /tmp/p2.log || FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  echo "=== E2E FAIL ===" >&2
  exit 1
fi
echo "=== E2E PASS ==="
