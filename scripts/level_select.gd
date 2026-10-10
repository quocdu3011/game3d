extends Control

const LOCK_TEXTURE := preload("res://assets/UI/Icons/Icon_Small_Lock.png")

@onready var btn_back: Button = %BtnBack
@onready var grid: GridContainer = $MainCard/VBox/GridContainer
@onready var progress: ProgressBar = $MainCard/VBox/BottomContainer/ProgressBar

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Tự động nối TẤT CẢ nút level trong grid (BtnLvl1...BtnLvl12)
	for child in grid.get_children():
		if child is Button and child.name.begins_with("BtnLvl"):
			var level_num := child.name.trim_prefix("BtnLvl").to_int()
			if not GameManager.LEVELS.has(level_num):
				# Level chưa được làm -> khoá, tooltip kiểu "sắp ra mắt".
				_lock_button(child, "Level %d sắp ra mắt!" % level_num)
			elif not GameManager.is_level_unlocked(level_num):
				# Level đã có nhưng chưa tới lượt -> khoá tuần tự.
				_lock_button(child, "Hoàn thành màn %d để mở khoá màn %d!" % [level_num - 1, level_num])
			else:
				child.pressed.connect(func(): _load_level(level_num))
				# Level đã hoàn thành -> hiện sao; scene đã có sẵn TextureRect
				# tên "Star" trên nút chơi được nên chỉ bật/tắt modulate.
				_mark_completion(child, level_num)

	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)

	_update_progress()


## Khoá một nút level: vô hiệu hoá, đặt tooltip và đảm bảo có icon ổ khoá.
func _lock_button(button: Button, reason: String) -> void:
	button.disabled = true
	button.tooltip_text = reason
	# Giữ số dễ đọc trên nút khoá (thay vì modulate làm mờ cả nút)
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.44, 0.5, 1))
	var star_texture := preload("res://assets/UI/Icons/Icon_Small_Star.png")
	var has_icon := false
	for icon in button.get_children():
		var icon_rect := icon as TextureRect
		if icon_rect != null and icon_rect.texture != null:
			has_icon = true
			icon_rect.modulate = Color(1, 1, 1, 0.7)
			if icon_rect.texture == star_texture:
				icon_rect.texture = LOCK_TEXTURE
	if not has_icon:
		var lock_rect := TextureRect.new()
		lock_rect.texture = LOCK_TEXTURE
		lock_rect.modulate = Color(1, 1, 1, 0.7)
		lock_rect.custom_minimum_size = Vector2(28, 28)
		lock_rect.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		lock_rect.offset_left = -26.0
		lock_rect.offset_top = -26.0
		lock_rect.offset_right = 2.0
		lock_rect.offset_bottom = 2.0
		lock_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(lock_rect)


## Bật icon sao trên nút level đã hoàn thành, ẩn đi nếu chưa chơi xong.
func _mark_completion(button: Button, level_num: int) -> void:
	var done := GameManager.is_level_completed(level_num)
	for icon in button.get_children():
		var tr := icon as TextureRect
		if tr != null and tr.texture == preload("res://assets/UI/Icons/Icon_Small_Star.png"):
			tr.modulate = Color(1, 1, 1, 1) if done else Color(1, 1, 1, 0)
			return
	if done:
		var star := TextureRect.new()
		star.name = "Star"
		star.texture = preload("res://assets/UI/Icons/Icon_Small_Star.png")
		star.custom_minimum_size = Vector2(32, 32)
		star.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		star.offset_left = -30.0
		star.offset_top = -30.0
		star.offset_right = 2.0
		star.offset_bottom = 2.0
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(star)


func _update_progress() -> void:
	if not progress:
		return
	# Mẫu số = số level thực sự chơi được; tử số = số level ĐÃ HOÀN THÀNH.
	# Trước đây tử số lấy LEVELS.size() (hằng số 4) nên thanh luôn hiện 4/12
	# kể cả khi người chơi chưa hoàn thành màn nào.
	progress.max_value = maxi(GameManager.LEVELS.size(), 1)
	progress.value = GameManager.completed_count()
	progress.show_percentage = true

func _load_level(level_num: int) -> void:
	if GameManager.current_mode == GameManager.GameMode.OFFLINE:
		GameManager.load_level(level_num)
	else:
		# Online: yêu cầu server phòng load level, cả 2 client được sync
		NetworkManager.request_level(level_num)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
