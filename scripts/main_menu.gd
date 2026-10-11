extends Control

@onready var btn_offline: Button = %BtnOffline
@onready var btn_shop: Button = %BtnShop
@onready var btn_quit: Button = %BtnQuit

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Nhạc nền bắt đầu từ main menu và nhờ autoload nên đi theo mọi scene sau.
	MusicPlayer.start()
	
	if btn_offline:
		btn_offline.pressed.connect(_on_offline_pressed)
	if btn_shop:
		btn_shop.pressed.connect(_on_shop_pressed)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)

func _on_offline_pressed() -> void:
	GameManager.current_mode = GameManager.GameMode.OFFLINE
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")

func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
