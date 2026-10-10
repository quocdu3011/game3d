extends SceneTree
# Test flow day du: create/join -> host chon level -> ca 2 nhan sync_level
# godot --headless -s test/test_client.gd -- create | join <room>

var mode := "create"
var room := ""
var ticks := 0
var got_peer := false
var got_level := false
var nm: Node = null

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		mode = args[0]
	if args.size() > 1:
		room = args[1]

	await process_frame
	nm = root.get_node_or_null("/root/NetworkManager")
	if nm == null:
		printerr("TEST_FAIL: khong thay NetworkManager autoload")
		quit(1)
		return

	nm.player_connected_net.connect(_on_peer_joined)
	nm.connection_failed_net.connect(_on_fail)
	nm.level_synced.connect(_on_level_synced)

	if mode == "create":
		_run_create()
	else:
		_run_join(room)

func _run_create() -> void:
	var rid = await nm.create_room()
	if rid == "":
		printerr("TEST_FAIL: tao phong that bai")
		quit(1)
		return
	print("ROOM=", rid)
	print("TEST_HOST_OK id=", get_multiplayer().get_unique_id())

func _run_join(r: String) -> void:
	if not await nm.join_room(r):
		printerr("TEST_FAIL: join phong that bai")
		quit(1)
		return
	print("TEST_JOIN_OK id=", get_multiplayer().get_unique_id())

func _on_peer_joined(id: int) -> void:
	got_peer = true
	print("TEST_PEER_JOINED id=", id, " my_id=", get_multiplayer().get_unique_id())
	if mode == "create" and nm.is_host():
		print("TEST: host yeu cau level 1 (sau 1s cho on dinh)...")
		await create_timer(1.0).timeout
		nm.request_level(1)

func _on_level_synced(level_num: int) -> void:
	got_level = true
	print("TEST_LEVEL_SYNCED level=", level_num)
	# Đợi thêm để client kịp báo ready và server spawn
	if not _pass_timer_started:
		_pass_timer_started = true
		await create_timer(3.0).timeout
		print("TEST_PASS (da doi spawn window)")
		quit(0)

var _pass_timer_started := false

func _tick() -> void:
	ticks += 1
	if ticks == 1800 and not got_level:
		printerr("TEST_TIMEOUT: got_peer=", got_peer, " got_level=", got_level)
		quit(1)

func _on_fail() -> void:
	printerr("TEST_FAIL: connection failed signal")
	quit(1)
