#!/bin/bash
# Test relay: host tạo phòng -> lấy Room ID từ log -> guest join theo ID
GODOT="/home/quocdu/Bản tải về/Godot_v4.7.2-stable_linux.x86_64"
cd /home/quocdu/game-3d
rm -f /tmp/host.log /tmp/guest.log

timeout 30 "$GODOT" --headless --path . -s test/test_relay_client.gd -- host > /tmp/host.log 2>&1 &
HPID=$!

# Chờ host nhận được Room ID
ROOM=""
for i in $(seq 1 20); do
  ROOM=$(grep -o 'TEST_ROOM=[0-9]*' /tmp/host.log | cut -d= -f2)
  [ -n "$ROOM" ] && break
  sleep 0.5
done
echo "Room: $ROOM"

timeout 20 "$GODOT" --headless --path . -s test/test_relay_client.gd -- guest "$ROOM" > /tmp/guest.log 2>&1 &
GPID=$!
wait $GPID
wait $HPID
echo "=== HOST ==="; cat /tmp/host.log
echo "=== GUEST ==="; cat /tmp/guest.log
