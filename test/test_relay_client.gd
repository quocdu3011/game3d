extends SceneTree
# Test headless relay: godot --headless -s test/test_relay_client.gd -- host|guest [room]

const CTRL_BYTE := 0xFF
var role := "host"
var room_to_join := ""
var known_peers: Array[int] = []
var my_id := 0
var ticks := 0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		role = args[0]
	if args.size() > 1:
		room_to_join = args[1]

	var mp := get_multiplayer()
	mp.peer_connected.connect(_on_peer_connected)
	mp.connected_to_server.connect(_on_connected)
	mp.connection_failed.connect(_on_fail)
	mp.server_disconnected.connect(_on_fail)
	process_frame.connect(_tick)

	if role == "host":
		_create_room_then_connect()
	else:
		_connect_ws(room_to_join)

func _create_room_then_connect() -> void:
	var http := HTTPRequest.new()
	root.add_child(http)
	await process_frame
	http.request("http://127.0.0.1:9080/create", ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")
	var result: Array = await http.request_completed
	http.queue_free()
	if result[1] != 200:
		printerr("TEST_FAIL: HTTP tao phong loi ", result[1])
		quit(1)
		return
	var parsed = JSON.parse_string(result[3].get_string_from_utf8())
	print("TEST_ROOM=", parsed["room"])
	_connect_ws(str(parsed["room"]))

func _connect_ws(room: String) -> void:
	var mp := get_multiplayer()
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client("ws://127.0.0.1:9080/?room=" + room, TLSOptions.client_unsafe())
	if err != OK:
		printerr("TEST_FAIL: create_client loi ", err)
		quit(1)
		return
	mp.multiplayer_peer = peer
	print("TEST: dang ket noi voi tu cach ", role)

func _tick() -> void:
	ticks += 1
	var mp := get_multiplayer()
	if mp.multiplayer_peer == null:
		return
	mp.multiplayer_peer.poll()

	while mp.multiplayer_peer.get_available_packet_count() > 0:
		var bytes: PackedByteArray = mp.multiplayer_peer.get_packet()
		if bytes.size() == 5 and bytes.decode_u8(0) == CTRL_BYTE:
			var pid := bytes.decode_s32(1)
			if pid > 0 and not known_peers.has(pid):
				known_peers.append(pid)
				print("TEST_PEER_JOINED id=", pid)
				_check_pass()
			elif pid < 0:
				known_peers.erase(-pid)

	if ticks == 600:
		printerr("TEST_TIMEOUT: khong thay peer khac. known=", known_peers)
		quit(1)

func _on_connected() -> void:
	my_id = get_multiplayer().get_unique_id()
	print("TEST_CONNECTED id=", my_id)
	if not known_peers.has(my_id):
		known_peers.append(my_id)

func _on_peer_connected(id: int) -> void:
	pass # relay dùng ctrl packets

func _check_pass() -> void:
	if known_peers.size() >= 2:
		print("TEST_PASS my_id=", my_id, " peers=", known_peers)
		quit(0)

func _on_fail() -> void:
	printerr("TEST_FAIL: ket noi that bai")
	quit(1)
