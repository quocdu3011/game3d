@tool
extends McpTestSuite

# Hồi quy cho 2 lỗi mạng:
#  1. Lobby URL + địa chỉ ENet hardcode 127.0.0.1 -> không deploy được VPS.
#  2. Host được suy ra bằng "peer ID nhỏ nhất". Godot cấp peer ID NGẪU NHIÊN
#     nên người vào phòng trước không chắc là người có ID nhỏ nhất. Khi xảy
#     ra, cả phòng bị kẹt: không ai chọn được level.
#
# Không dùng bản sao autoload (placeholder trong editor). Instance phải được
# add vào cây thì `multiplayer` mới resolve được.

const NM_SCRIPT := "res://scripts/network_manager.gd"

var _nm: Node
var _saved_peer: MultiplayerPeer = null

func suite_name() -> String:
	return "network_config"

# Runner gọi setup()/teardown() TRƯỚC/SẦU từng test method, nên phải tạo
# instance ở setup() — tạo ở suite_setup() sẽ bị track() giải phóng ngay sau
# test đầu tiên.
func setup() -> void:
	var script: GDScript = load(NM_SCRIPT)
	_nm = script.new()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		# Editor dùng MultiplayerAPI với peer rỗng nên unique_id = 0, khiến
		# is_host() không bao giờ true trong test. Gán peer thật rồi khôi phục.
		_saved_peer = tree.root.multiplayer.multiplayer_peer
		tree.root.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		tree.root.add_child(_nm)

func teardown() -> void:
	if _nm != null and is_instance_valid(_nm):
		_nm.free()
	_nm = null
	var tree := Engine.get_main_loop() as SceneTree
	if _saved_peer != null and tree != null and tree.root != null:
		tree.root.multiplayer.multiplayer_peer = _saved_peer
	_saved_peer = null

func test_lobby_defaults_to_localhost() -> void:
	# Hành vi mặc định phải giữ nguyên để chạy offline không cần cấu hình.
	assert_eq(_nm.lobby_host, "127.0.0.1", "Mac dinh la localhost")
	assert_eq(_nm.lobby_port, 9080, "Mac dinh la port 9080")
	assert_eq(_nm.lobby_url(), "http://127.0.0.1:9080", "URL mac dinh dung")

func test_env_config_overrides_lobby_address() -> void:
	_nm.lobby_host = "127.0.0.1"
	_nm.lobby_port = 9080
	_nm.lobby_host = "203.0.113.7"
	_nm.lobby_port = 7777
	assert_eq(_nm.lobby_url(), "http://203.0.113.7:7777", "URL phai theo host/port da cau hinh")

func test_env_config_keeps_defaults_when_vars_empty() -> void:
	_nm.lobby_host = "127.0.0.1"
	_nm.lobby_port = 9080
	# _apply_env_config() phải bỏ qua biến rỗng, không ghi đè bằng chuỗi rỗng.
	_nm._apply_env_config()
	assert_false(_nm.lobby_host.is_empty(), "Bien rong khong duoc ghi de host thanh chuoi rong")
	assert_ne(_nm.lobby_port, 0, "Bien rong khong duoc ghi de port thanh 0")

func test_is_host_follows_server_not_peer_id_order() -> void:
	# Hồi quy của bug "ID nhỏ nhất". Peer ID ngẫu nhiên nên peer vào trước
	# hoàn toàn có thể có ID LỚN hơn mình.
	_nm._in_room = true
	var my_id: int = _nm.multiplayer.get_unique_id()
	var others: Array[int] = [my_id + 1, my_id + 2]
	_nm.connected_peers = others

	# Server báo mình là host -> mình là host, bất kể thứ tự ID.
	_nm.host_peer_id = my_id
	assert_true(_nm.is_host(), "Server chi dinh minh la host thi minh la host")

	# Server báo người khác -> mình không có quyền chọn level.
	_nm.host_peer_id = my_id + 1
	assert_false(_nm.is_host(), "Khong phai host du server thi khong duoc chon level")

	# Chưa ai được chỉ định -> không ai là host (tránh kẹt im lặng).
	_nm.host_peer_id = 0
	assert_false(_nm.is_host(), "Chua co host duoc chi dinh -> khong ai la host")

func test_is_host_false_when_not_in_room() -> void:
	_nm._in_room = false
	_nm.host_peer_id = _nm.multiplayer.get_unique_id()
	assert_false(_nm.is_host(), "Ngoai phong thi khong phai host")

