extends Control

const LOCK_TEXTURE := preload("res://assets/UI/Icons/Icon_Small_Lock.png")
const STAR_TEXTURE := preload("res://assets/UI/Icons/Icon_Small_Star.png")
const STAR_GREY_TEXTURE := preload("res://assets/UI/Icons/Icon_Small_StarGrey.png")

## Số sao tối đa — khớp `GameManager.stars_for_time()` (trả về 1..3).
const MAX_STARS := 3
## Bề rộng một sao. 3 sao = 78 px, vừa khít nút 95 px.
const STAR_SIZE := 26.0
## Khoảng hở giữa mép phải nút và sao cuối cùng.
const STAR_MARGIN_X := 8.0
## Khoảng hở phía dưới lớn hơn một chút để hàng sao không chồng lên
## viền tròn của nút.
const STAR_MARGIN_Y := 18.0

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
				# Level đã có thể chơi -> vẽ số sao đã kiếm được.
				_mark_completion(child, level_num)

	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)

	_update_progress()


## Khoá một nút level: vô hiệu hoá, đặt tooltip, đổi hàng sao thành icon ổ khoá.
func _lock_button(button: Button, reason: String) -> void:
	button.disabled = true
	button.tooltip_text = reason
	# Giữ số dễ đọc trên nút khoá (thay vì modulate làm mờ cả nút)
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.44, 0.5, 1))
	_remove_stars(button)
	var lock_rect := TextureRect.new()
	lock_rect.name = "LockIcon"
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
	lock_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(lock_rect)


## Vẽ số sao của màn: `best_stars()` sao vàng, phần còn lại sao xám mờ.
## Màn chưa hoàn thành (0 sao) vẫn thấy 3 sao xám — người chơi biết màn
## này có tối đa 3 sao thay vì tưởng chưa có gì.
func _mark_completion(button: Button, level_num: int) -> void:
	_prepare_stars(button)
	var stars := GameManager.best_stars(level_num)
	for i in range(MAX_STARS):
		var star := button.get_node("Star%d" % i) as TextureRect
		var earned := stars > i
		star.texture = STAR_TEXTURE if earned else STAR_GREY_TEXTURE
		star.modulate = Color(1, 1, 1, 1) if earned else Color(1, 1, 1, 0.45)


## Bảo đảm nút có đúng `MAX_STARS` TextureRect tên Star0..Star2 xếp cạnh nhau
## ở góc dưới-phải, và gỡ node `Star` cũ để dưa scene (để không thành 4 sao).
func _prepare_stars(button: Button) -> void:
	var legacy := button.get_node_or_null("Star")
	if legacy is TextureRect:
		button.remove_child(legacy)
		legacy.queue_free()
	for i in range(MAX_STARS):
		if button.get_node_or_null("Star%d" % i) is TextureRect:
			continue
		var star := TextureRect.new()
		star.name = "Star%d" % i
		button.add_child(star)
		star.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		# Sao 0 sát mép phải nhất, mỗi sao sau lùi thêm STAR_SIZE sang trái.
		var right := -STAR_MARGIN_X - float(i) * STAR_SIZE
		star.offset_left = right - STAR_SIZE
		star.offset_right = right
		star.offset_top = -STAR_MARGIN_Y - STAR_SIZE
		star.offset_bottom = -STAR_MARGIN_Y
		star.custom_minimum_size = Vector2(STAR_SIZE, STAR_SIZE)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Không được nuốt cú bấm của nút.
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Gỡ hết icon sao trên nút (cả `Star` cũ trong scene lẫn `Star0..2` sinh lúc chạy).
func _remove_stars(button: Button) -> void:
	for child in button.get_children():
		if String(child.name).begins_with("Star"):
			button.remove_child(child)
			child.queue_free()


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
