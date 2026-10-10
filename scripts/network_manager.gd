extends Node

# Quản lý mạng — CLIENT ONLY.
#
# Kiến trúc: phòng chơi là một tiến trình Godot headless (dedicated server)
# chạy trên VPS, do lobby server khởi tạo. Cả "host" lẫn "guest" đều là
# client kết nối RA NGOÀI tới server phòng → không ai cần mở port,
# chỉ cần Room ID.
#
# Host = client vào phòng TRƯỚC, do dedicated server chỉ định (xem sync_host).

## Lobby server. Mặc định localhost để chạy offline không cần cấu hình gì.
## Khi deploy VPS thì đặt biến môi trường LOBBY_HOST / LOBBY_PORT.
## Cùng giá trị này dùng cho lobby HTTP lẫn kết nối ENet tới phòng, vì
## relay và các phòng đều nằm trên cùng một máy chủ.
var lobby_host: String = "127.0.0.1"
var lobby_port: int = 9080

func lobby_url() -> String:
	return "http://%s:%d" % [lobby_host, lobby_port]

## Ghi đè cấu hình lobby từ biến môi trường. Biến rỗng -> giữ mặc định.
func _apply_env_config() -> void:
	var host := OS.get_environment("LOBBY_HOST")
	if not host.is_empty():
		lobby_host = host
	var port := OS.get_environment("LOBBY_PORT")
	if not port.is_empty():
		lobby_port = port.to_int()

signal player_connected_net(id: int)
signal player_disconnected_net(id: int)
signal connection_failed_net()
signal server_disconnected_net()
signal level_synced(level_num: int)
signal host_changed_net(peer_id: int)

## ID của host do dedicated server chỉ định. KHÔNG suy ra từ peer ID: Godot
## cấp ngẫu nhiên peer ID nên "ID nhỏ nhất" không phải người vào trước.
## Server là nguồn sự thật, client nhận qua RPC sync_host.
var host_peer_id: int = 0

## Server báo ai là host. Đây là nguồn duy nhất — client không tự suy luận.
@rpc("authority", "call_remote", "reliable")
func sync_host(peer_id: int) -> void:
	host_peer_id = peer_id
	print("Host cua phong la peer ", peer_id)
	host_changed_net.emit(peer_id)

var room_id: String = ""
var connected_peers: Array[int] = []
var player_skins: Dictionary = {} # id -> skin_name

var _room_peer: ENetMultiplayerPeer = null
var _in_room: bool = false

func _ready() -> void:
	_apply_env_config()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# -------------------- TẠO PHÒNG --------------------
## Xin lobby tạo phòng (spawn dedicated server) rồi kết nối vào.
## Trả về Room ID, hoặc "" nếu thất bại.
func create_room() -> String:
	leave_room()
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(lobby_url() + "/create", ["Content-Type: application/json"], HTTPClient.METHOD_POST, "{}")
	if err != OK:
		http.queue_free()
		push_error("Khong the ket noi lobby server!")
		return ""
	var result: Array = await http.request_completed
	http.queue_free()
	if result[1] != 200:
		push_error("Lobby tu choi tao phong (HTTP %d)" % result[1])
		return ""
	var parsed = JSON.parse_string(result[3].get_string_from_utf8())
	if parsed == null or not (parsed is Dictionary) or not parsed.has("room"):
		push_error("Phan hoi lobby khong hop le!")
		return ""
	room_id = str(parsed["room"])
	var port := int(parsed["port"])

	# Chờ dedicated server kịp mở cổng
	await get_tree().create_timer(1.0).timeout
	if not _connect_to_room(port):
		return ""
	GameManager.current_mode = GameManager.GameMode.ONLINE_HOST
	print("Da tao phong! Room ID: ", room_id)
	return room_id

# -------------------- THAM GIA PHÒNG --------------------
## target_address = ROOM ID (6 chữ số). Tra lobby lấy port rồi kết nối.
func join_room(target_address: String = "") -> bool:
	var room := target_address.strip_edges()
	if room.is_empty():
		connection_failed_net.emit()
		return false
	leave_room()

	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(lobby_url() + "/resolve?room=" + room)
	if err != OK:
		http.queue_free()
		connection_failed_net.emit()
		return false
	var result: Array = await http.request_completed
	http.queue_free()
	if result[1] != 200:
		print("Phong ", room, " khong ton tai (HTTP %d)" % result[1])
		connection_failed_net.emit()
		return false
	var parsed = JSON.parse_string(result[3].get_string_from_utf8())
	if parsed == null or not (parsed is Dictionary) or not parsed.has("port"):
		connection_failed_net.emit()
		return false

	if not _connect_to_room(int(parsed["port"])):
		return false
	room_id = room
	GameManager.current_mode = GameManager.GameMode.ONLINE_CLIENT
	return true

func _connect_to_room(port: int) -> bool:
	_room_peer = ENetMultiplayerPeer.new()
	var err := _room_peer.create_client(lobby_host, port)
	if err != OK:
		push_error("Khong the ket noi toi phong (port %d): %s" % [port, error_string(err)])
		_room_peer = null
		connection_failed_net.emit()
		return false
	multiplayer.multiplayer_peer = _room_peer
	return true

func leave_room() -> void:
	_in_room = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_room_peer = null
	connected_peers.clear()
	player_skins.clear()
	host_peer_id = 0
	room_id = ""
	GameManager.current_mode = GameManager.GameMode.OFFLINE

## Host = peer mà dedicated server chỉ định (xem sync_host). Không suy ra từ
## peer ID vì Godot cấp peer ID ngẫu nhiên, người vào trước KHÔNG chắc là
## người có ID nhỏ nhất.
func is_host() -> bool:
	return _in_room and host_peer_id != 0 and host_peer_id == multiplayer.get_unique_id()


# -------------------- RPC GỬI SERVER --------------------
func send_skin_to_server() -> void:
	if _in_room:
		rpc_id(1, "register_skin", GameManager.selected_skin)

func request_level(level_num: int) -> void:
	if _in_room and is_host():
		rpc_id(1, "net_request_level", level_num)

## RPC khai báo giống nhau trên mọi máy (NetworkManager là autoload nên
## node path /root/NetworkManager luôn khớp).
@rpc("any_peer", "call_remote", "reliable")
func register_skin(skin_name: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	player_skins[sender] = skin_name
	print("Peer ", sender, " dung skin: ", skin_name)

@rpc("any_peer", "call_remote", "reliable")
func net_request_level(level_num: int) -> void:
	# Chỉ có ý nghĩa phía dedicated server
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var room_node := get_tree().root.get_node_or_null("/root/DedicatedRoom")
	if room_node != null:
		room_node.handle_request_level(sender, level_num)

## Client báo đã load xong level → server mới bắt đầu spawn player
## (tránh race: spawn packet đến trước khi MultiplayerSpawner tồn tại ở client).
func notify_ready() -> void:
	rpc_id(1, "net_client_ready")
@rpc("any_peer", "call_remote", "reliable")
func net_client_ready() -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var room_node := get_tree().root.get_node_or_null("/root/DedicatedRoom")
	if room_node != null:
		room_node.handle_client_ready(sender)

@rpc("authority", "call_remote", "reliable")
func sync_level(level_num: int) -> void:
	# Server bảo client load level này (chỉ chạy phía client)
	print("Server dong bo level ", level_num)
	level_synced.emit(level_num)
	if not multiplayer.is_server():
		GameManager.load_level(level_num)
		# Báo server đã load xong để server spawn player
		await get_tree().create_timer(0.5).timeout
		notify_ready()

# -------------------- CALLBACKS MULTIPLAYER API --------------------
func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		return # dedicated server không tự gửi skin
	if id == 1:
		return # server phòng
	if not connected_peers.has(id):
		connected_peers.append(id)
	player_connected_net.emit(id)
	send_skin_to_server()
	_in_room = true

func _on_peer_disconnected(id: int) -> void:
	if id == 1:
		return
	connected_peers.erase(id)
	player_skins.erase(id)
	player_disconnected_net.emit(id)

func _on_connected_to_server() -> void:
	print("Da ket noi vao phong! ID cua ban: ", multiplayer.get_unique_id())
	_in_room = true
	# Peer 1 (server) sẽ được thêm khi peer_connected(1) bắn... thực tế nó bắn với id=1
	if not connected_peers.has(multiplayer.get_unique_id()):
		connected_peers.append(multiplayer.get_unique_id())
	send_skin_to_server()

func _on_connection_failed() -> void:
	print("Ket noi phong that bai!")
	connection_failed_net.emit()

func _on_server_disconnected() -> void:
	print("Mat ket noi voi phong!")
	leave_room()
	server_disconnected_net.emit()
