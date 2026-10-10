extends Control

@onready var btn_host: Button = %BtnHost
@onready var btn_join: Button = %BtnJoin
@onready var btn_start_game: Button = %BtnStartGame
@onready var btn_back: Button = %BtnBack

@onready var txt_room_id: LineEdit = %TxtIP # Giữ tên node cũ, giờ dùng cho Room ID
@onready var lbl_room_id: Label = %LblRoomID
@onready var lbl_status: Label = %LblStatus
@onready var lbl_player_count: Label = %LblPlayerCount

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if btn_host:
		btn_host.pressed.connect(_on_host_pressed)
	if btn_join:
		btn_join.pressed.connect(_on_join_pressed)
	if btn_start_game:
		btn_start_game.pressed.connect(_on_start_game_pressed)
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)

	NetworkManager.player_connected_net.connect(_on_player_connected)
	NetworkManager.player_disconnected_net.connect(_on_player_disconnected)
	NetworkManager.connection_failed_net.connect(_on_connection_failed)

	btn_start_game.visible = false

func _on_host_pressed() -> void:
	btn_host.disabled = true
	lbl_status.text = "Dang tao phong qua relay server..."
	var room_code = await NetworkManager.create_room()
	btn_host.disabled = false
	if room_code != "":
		lbl_room_id.text = "MA PHONG (ROOM ID): " + room_code
		lbl_status.text = "Da tao phong! Cho ban be nhap ma phong de vao..."
		_update_player_count()
		btn_start_game.visible = true
	else:
		lbl_status.text = "Tao phong that bai! Khong ket noi duoc relay server."

func _on_join_pressed() -> void:
	var room_code = txt_room_id.text.strip_edges()
	if room_code.is_empty():
		lbl_status.text = "Vui long nhap ma phong (6 chu so)!"
		return

	lbl_status.text = "Dang tham gia phong " + room_code + "..."
	if not await NetworkManager.join_room(room_code):
		lbl_status.text = "Khong the ket noi toi relay server!"

func _on_start_game_pressed() -> void:
	if NetworkManager.is_host():
		# Chuyển tới giao diện chọn Level cho Host
		get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")

func _on_player_connected(id: int) -> void:
	lbl_status.text = "Nguoi choi ID " + str(id) + " da tham gia phong!"
	_update_player_count()

func _on_player_disconnected(id: int) -> void:
	lbl_status.text = "Nguoi choi ID " + str(id) + " da roi phong."
	_update_player_count()

func _on_connection_failed() -> void:
	btn_host.disabled = false
	lbl_status.text = "Ket noi that bai! Vui long kiem tra ma phong."

func _update_player_count() -> void:
	var count = NetworkManager.connected_peers.size()
	lbl_player_count.text = "So nguoi choi trong phong: " + str(count) + " / 2"

func _on_back_pressed() -> void:
	NetworkManager.leave_room()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
