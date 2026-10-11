extends Control

## Cửa hàng: mua mở khoá nhân vật bằng coin đã nhặt trong các màn.
## Mỗi nhân vật là một `shop_card.tscn`; card tự lo phần ảnh 3D, giá và nút,
## còn màn này giữ tiền, xử lý mua/nhận diện và thông báo.

const SHOP_ITEMS := [
	{"skin": "gobot", "name": "Gobot"},
	{"skin": "gdbot", "name": "Gdbot"},
	{"skin": "sophia", "name": "Sophia"},
]

const CARD_SCENE := "res://scenes/ui/shop_card.tscn"

## Thời gian hiện thông báo (giây) rồi tự ẩn.
const MESSAGE_TIME := 2.2

@onready var card_row: HBoxContainer = get_node("%CardRow")
@onready var lbl_coins: Label = get_node("%LblCoins")
@onready var lbl_message: Label = get_node("%LblMessage")
@onready var btn_back: TextureButton = get_node("%BtnBack")

var _cards: Array = []
var _msg_t := 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Dựng card cho từng nhân vật trong bảng SHOP_ITEMS.
	var card_scene := load(CARD_SCENE) as PackedScene
	for item in SHOP_ITEMS:
		var card := card_scene.instantiate()
		card_row.add_child(card)
		card.setup(item["skin"], item["name"])
		card.action_requested.connect(_on_card_action)
		_cards.append(card)

	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)

	GameManager.purchase_result.connect(_on_purchase_result)
	_refresh()

func _process(delta: float) -> void:
	# Coin có thể đổi giữa các lần mở shop (đổi cảnh), nên nhãn ví luôn
	# lấy trực tiếp từ GameManager thay vì chỉ cập nhật lúc vào.
	if lbl_coins:
		lbl_coins.text = str(GameManager.coins)

	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0 and lbl_message:
			lbl_message.text = ""

func _refresh() -> void:
	if lbl_coins:
		lbl_coins.text = str(GameManager.coins)
	for card in _cards:
		card.refresh()

func _on_card_action(skin_name: String) -> void:
	var unlocked := GameManager.is_skin_unlocked(skin_name)

	if unlocked:
		# Đã sở hữu -> chỉ chọn nhân vật đó ra.
		if GameManager.select_skin(skin_name):
			_show_message("Đã chọn nhân vật %s" % skin_name.capitalize())
		_refresh()
		return

	# Chưa sở hữu -> mua. `unlock_skin` tự trừ coin và bắn tín hiệu kết quả.
	if GameManager.unlock_skin(skin_name):
		GameManager.select_skin(skin_name)
	_refresh()

func _on_purchase_result(_ok: bool, _skin_name: String, message: String) -> void:
	_show_message(message)

func _show_message(message: String) -> void:
	if lbl_message:
		lbl_message.text = message
		_msg_t = MESSAGE_TIME

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")