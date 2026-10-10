extends Node
# Dedicated room server — AUTOLOAD, chỉ kích hoạt khi chạy với tham số:
#   godot --headless res://scenes/dedicated_room.tscn -- --port=X --room=YYYYYY
#
# Vì là autoload nên nó sống độc lập với scene, change_scene_to_file không
# làm mất logic phòng. Trên client thường (không có --port/--room) nó tự tắt.
#
# Các RPC (register_skin, net_request_level, sync_level, net_client_ready)
# được khai báo trong scripts/network_manager.gd — node path /root/NetworkManager
# giống nhau trên cả server lẫn client nên RPC luôn hợp lệ.

var room_port: int = -1
var room_id: String = ""
var chosen_level: int = -1
var level_loaded := false
var ready_peers: Array[int] = [] # client đã load xong level
## Host = client vào phòng ĐẦU TIÊN. Server là nguồn sự thật và gán qua
## thứ tự kết nối, không dùng peer ID (Godot cấp ID ngẫu nhiên).
var host_peer_id: int = 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			room_port = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--room="):
			room_id = arg.get_slice("=", 1)

	if room_port < 0 or room_id.is_empty():
		set_process(false)
		return # Client thường — không làm gì cả

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(room_port, 8)
	if err != OK:
		push_error("Khong mo duoc port %d: %s" % [room_port, error_string(err)])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# Đặt mode ONLINE để level_controller không chạy nhánh spawn offline,
	# rồi load scene menu như bình thường (chờ host chọn level).
	GameManager.current_mode = GameManager.GameMode.ONLINE_HOST
	print("[Room %s] Server dang lang tai o cong %d" % [room_id, room_port])

func _on_peer_connected(id: int) -> void:
	print("[Room %s] Peer %d da ket noi" % [room_id, id])
	ready_peers.erase(id)
	if host_peer_id == 0:
		host_peer_id = id
		print("[Room %s] Peer %d la host" % [room_id, id])
		_broadcast_host()
	if chosen_level > 0:
		NetworkManager.rpc_id(id, "sync_level", chosen_level)

## Báo cho mọi client biết host hiện tại.
func _broadcast_host() -> void:
	for pid in multiplayer.get_peers():
		NetworkManager.rpc_id(pid, "sync_host", host_peer_id)

func _on_peer_disconnected(id: int) -> void:
	print("[Room %s] Peer %d roi phong" % [room_id, id])
	ready_peers.erase(id)
	if level_loaded and get_tree().current_scene != null \
			and get_tree().current_scene.has_method("remove_player"):
		get_tree().current_scene.remove_player(id)
	# Host rời đi -> đẩy quyền cho người còn lại và báo lại cho cả phòng.
	if id == host_peer_id:
		host_peer_id = 0
		for pid in multiplayer.get_peers():
			host_peer_id = pid
			break
		if host_peer_id != 0:
			print("[Room %s] Peer %d thay the lam host" % [room_id, host_peer_id])
			_broadcast_host()

## Chỉ host (client vào phòng sớm nhất) mới được chọn level.
func handle_request_level(sender: int, level_num: int) -> void:
	if sender != host_peer_id:
		print("[Room %s] Tu choi peer %d chon level (khong phai host)" % [room_id, sender])
		return
	print("[Room %s] Host %d chon level %d" % [room_id, sender, level_num])
	chosen_level = level_num

	if not level_loaded:
		level_loaded = true
		# change_scene_to_file → cây node giống hệt client (/root/Level1/...),
		# điều kiện bắt buộc để MultiplayerSpawner/Synchronizer khớp path.
		get_tree().change_scene_to_file.call_deferred(GameManager.get_level_path(chosen_level))

	# Bảo mọi client load level này
	for pid in multiplayer.get_peers():
		NetworkManager.rpc_id(pid, "sync_level", chosen_level)

## Client báo đã load xong level → server spawn player cho nó.
func handle_client_ready(pid: int) -> void:
	if not ready_peers.has(pid):
		ready_peers.append(pid)
	var cs := get_tree().current_scene
	if cs == null or not cs.has_method("spawn_player_for"):
		print("[Room %s] Peer %d san sang nhung level chua load xong" % [room_id, pid])
		return
	print("[Room %s] Peer %d san sang, spawn player" % [room_id, pid])
	cs.spawn_player_for(pid)
