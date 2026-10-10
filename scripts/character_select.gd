extends Control

@onready var btn_gobot: Button = %BtnGobot
@onready var btn_gdbot: Button = %BtnGdbot
@onready var btn_sophia: Button = %BtnSophia
@onready var btn_back: Button = %BtnBack

@onready var preview_slot: Node3D = %PreviewSlot
@onready var lbl_current: Label = %LblCurrent

var current_preview: String = "gobot"
var current_node: Node3D = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	current_preview = GameManager.selected_skin
	
	if btn_gobot:
		btn_gobot.pressed.connect(func(): _select_skin("gobot"))
	if btn_gdbot:
		btn_gdbot.pressed.connect(func(): _select_skin("gdbot"))
	if btn_sophia:
		btn_sophia.pressed.connect(func(): _select_skin("sophia"))
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
		
	_select_skin(current_preview)

func _select_skin(skin_name: String) -> void:
	current_preview = skin_name
	GameManager.selected_skin = skin_name
	
	if lbl_current:
		lbl_current.text = "Nhân vật đã chọn: " + skin_name.capitalize()
		
	if preview_slot:
		for child in preview_slot.get_children():
			child.queue_free()
		
		var path = GameManager.get_skin_path(skin_name)
		var scn = load(path)
		if scn:
			current_node = scn.instantiate()
			preview_slot.add_child(current_node)
			if current_node.has_method("idle"):
				current_node.idle()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
