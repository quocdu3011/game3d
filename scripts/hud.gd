extends CanvasLayer

## Icon vật phẩm hiển thị ở ô 1 của thanh inventory (cung).
const INVENTORY_BOW_ICON := "res://assets/UI/Icons/bow_icon.png"
## Ô inventory rộng 72x68. Icon 44x44 canh giữa, lệch xuống một chút để
## không đè lên số thứ tự ở góc trên-trái.
const ICON_SIZE := Vector2(44.0, 44.0)
const ICON_POS := Vector2(14.0, 16.0)

signal bow_draw_started
signal bow_draw_released

# Node refs — dùng get_node_or_null để không crash khi scene thiếu node
@onready var lbl_level: Label = get_node_or_null("TopContainer/LblLevelInfo")
@onready var pause_overlay: ColorRect = get_node_or_null("PauseOverlay")
@onready var btn_pause: Button = get_node_or_null("TopContainer/BtnPause")
@onready var btn_change_camera: Button = get_node_or_null("TopContainer/BtnChangeCamera")
@onready var btn_resume: Button = get_node_or_null("PauseOverlay/PausePanel/PauseMenuContainer/BtnResume")
@onready var btn_restart: Button = get_node_or_null("PauseOverlay/PausePanel/PauseMenuContainer/BtnRestart")
@onready var btn_main_menu: Button = get_node_or_null("PauseOverlay/PausePanel/PauseMenuContainer/BtnMainMenu")
@onready var btn_close: Button = get_node_or_null("PauseOverlay/PausePanel/BtnClose")
@onready var btn_options: Button = get_node_or_null("PauseOverlay/PausePanel/PauseMenuContainer/BtnOptions")
@onready var options_overlay: Control = get_node_or_null("OptionsOverlay")
@onready var complete_overlay: Control = get_node_or_null("CompleteOverlay")
@onready var stars_row: HBoxContainer = get_node_or_null("CompleteOverlay/CompletePanel/StarsRow")
@onready var btn_replay: Button = get_node_or_null("CompleteOverlay/CompletePanel/BtnReplay")
@onready var btn_next: Button = get_node_or_null("CompleteOverlay/CompletePanel/BtnNextLevel")
@onready var btn_close_done: Button = get_node_or_null("CompleteOverlay/CompletePanel/BtnCloseDone")
@onready var lbl_coins: Label = get_node_or_null("CompleteOverlay/CompletePanel/StatsRow/CoinBadge/Row/Value")
@onready var lbl_coin_count: Label = get_node_or_null("TopContainer/CoinBox/Value")

var _inventory_bar: HBoxContainer
var _inventory_slots: Array[Panel] = []
var _selected_inventory_slot := 1
var _virtual_joystick: Control
var _virtual_jump_requested := false
var _jump_button: TextureButton
var _bow_button: TextureButton
## Màn sẽ sang khi bấm nút "màn tiếp theo"; -1 nghĩa là đã ở màn cuối.
var _next_level := -1


func _ready() -> void:
	add_to_group("hud")
	_create_inventory_bar()
	_setup_mobile_controls()
	if pause_overlay:
		pause_overlay.visible = false

	if lbl_level:
		lbl_level.text = "MÀN " + str(GameManager.current_level)

	# Bộ đếm coin trên HUD. Nối tín hiệu của GameManager để cập nhật ngay
	# khi nhặt đồng, không polling mỗi khung hình. Số hiện là coin của màn
	# đang chơi (luôn bắt đầu từ 0), không phải tổng coin trong ví.
	if not GameManager.level_coins_changed.is_connected(_refresh_coin_counter):
		GameManager.level_coins_changed.connect(_refresh_coin_counter)
	_refresh_coin_counter()

	if btn_pause:
		btn_pause.pressed.connect(_toggle_pause)
	if btn_change_camera:
		btn_change_camera.pressed.connect(_toggle_camera_mode)
	if btn_resume:
		btn_resume.pressed.connect(_resume)
	if btn_restart:
		btn_restart.pressed.connect(_restart)
	if btn_main_menu:
		btn_main_menu.pressed.connect(_return_to_main_menu)
	if btn_close:
		btn_close.pressed.connect(_resume)
	if btn_options:
		btn_options.pressed.connect(_open_options)
	if options_overlay:
		options_overlay.closed.connect(_close_options)
	if complete_overlay:
		complete_overlay.visible = false
	# Theo dõi trạng thái hiển thị của từng overlay để giấu thanh inventory
	# đúng lúc, kể cả khi ai đó bật/tắt trực tiếp thay vì qua menu tạm dừng.
	for overlay in [pause_overlay, options_overlay, complete_overlay]:
		if overlay:
			overlay.visibility_changed.connect(_on_overlay_visibility_changed)
	if btn_replay:
		btn_replay.pressed.connect(_restart)
	if btn_next:
		btn_next.pressed.connect(_on_next_level_pressed)
		# Màn cuối không có màn kế tiếp thì giấu nút đi, tránh bấm nhầm.
		btn_next.visible = false
	if btn_close_done:
		btn_close_done.pressed.connect(_close_complete)
		_bind_hover(btn_close_done)

	for button in [btn_pause, btn_resume, btn_restart, btn_options, btn_main_menu, btn_close, btn_next]:
		_bind_hover(button)

func _setup_mobile_controls() -> void:
	_virtual_joystick = get_node_or_null("VirtualJoystick") as Control
	# Không nối tín hiệu nào của joystick: `VirtualJoystick` của Godot tự nhấn
	# các action `move_*` khi bị lệch, nên `player.gd` đọc thẳng qua InputMap.
	# (Các tên `joystick_moved` / `hardware_visibility_changed` từng được nối ở
	# đây không hề tồn tại — Godot chỉ có pressed/released/flicked/flick_canceled/
	# tapped — nên chúng chưa bao giờ chạy.)

	_jump_button = TextureButton.new()
	_jump_button.name = "JumpButton"
	_jump_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_jump_button.offset_left = -200.0
	_jump_button.offset_top = -195.0
	_jump_button.offset_right = -50.0
	_jump_button.offset_bottom = -45.0
	_jump_button.texture_normal = load("res://assets/UI/ButtonsIcons/jump_button.png")
	_jump_button.texture_pressed = load("res://assets/UI/ButtonsIcons/jump_button_active.png")
	_jump_button.ignore_texture_size = true
	_jump_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_jump_button.focus_mode = Control.FOCUS_NONE
	_jump_button.tooltip_text = "Nhảy"
	_jump_button.button_down.connect(_on_jump_button_down)
	_jump_button.button_up.connect(_on_jump_button_up)
	add_child(_jump_button)

	_bow_button = TextureButton.new()
	_bow_button.name = "BowButton"
	_bow_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_bow_button.offset_left = -200.0
	_bow_button.offset_top = -365.0
	_bow_button.offset_right = -50.0
	_bow_button.offset_bottom = -215.0
	_bow_button.texture_normal = load("res://assets/UI/ButtonsIcons/bow_button.png")
	_bow_button.texture_pressed = load("res://assets/UI/ButtonsIcons/bow_button_active.png")
	_bow_button.ignore_texture_size = true
	_bow_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_bow_button.focus_mode = Control.FOCUS_NONE
	_bow_button.tooltip_text = "Giương cung"
	_bow_button.button_down.connect(_on_bow_button_down)
	_bow_button.button_up.connect(_on_bow_button_up)
	add_child(_bow_button)

	# KHÔNG sao chép `_virtual_joystick.visible` sang hai nút này nữa. Joystick
	# đang để ở chế độ "chỉ hiện khi chạm" nên `visible` của nó nghĩa là "đang
	# được chạm", không phải "thiết bị này có màn hình cảm ứng" — đọc nó để quyết
	# định ẩn nút nhảy/cung sẽ làm hai nút đó biến mất vĩnh viễn.
	_jump_button.visible = true
	_bow_button.visible = true

func can_use_camera_touch_at(screen_position: Vector2) -> bool:
	if (pause_overlay and pause_overlay.visible) or (options_overlay and options_overlay.visible) or (complete_overlay and complete_overlay.visible):
		return false
	# Vùng joystick phải GIỮ CHỖ luôn, kể cả lúc chưa chạm: joystick đang ở
	# chế độ "chỉ hiện khi chạm" nên `visible` là false cho tới lần chạm đầu.
	# Nếu có xét `visible` như các control khác thì cử chỉ vuốt xoay camera ở
	# góc dưới bên trái sẽ lúc được chọn làm camera, lúc thành joystick.
	if _virtual_joystick and _virtual_joystick.get_global_rect().has_point(screen_position):
		return false
	for control in [_jump_button, _bow_button, _inventory_bar, btn_pause]:
		if control is Control and control.visible and control.get_global_rect().has_point(screen_position):
			return false
	return true

func consume_virtual_jump() -> bool:
	var requested := _virtual_jump_requested
	_virtual_jump_requested = false
	return requested

func _on_jump_button_down() -> void:
	_virtual_jump_requested = true
	Input.action_press("jump")

func _on_jump_button_up() -> void:
	Input.action_release("jump")

func _on_bow_button_down() -> void:
	bow_draw_started.emit()

func _on_bow_button_up() -> void:
	bow_draw_released.emit()

func _create_inventory_bar() -> void:
	_inventory_bar = HBoxContainer.new()
	_inventory_bar.name = "InventoryBar"
	_inventory_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_inventory_bar.position = Vector2(-190.0, -92.0)
	_inventory_bar.size = Vector2(380.0, 72.0)
	_inventory_bar.add_theme_constant_override("separation", 4)
	add_child(_inventory_bar)
	for index in range(5):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(72.0, 68.0)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inventory_bar.add_child(slot)
		_inventory_slots.append(slot)
		var number := Label.new()
		number.text = str(index + 1)
		number.position = Vector2(6.0, 4.0)
		number.add_theme_font_size_override("font_size", 14)
		slot.add_child(number)
		if index == 0:
			var icon := TextureRect.new()
			icon.texture = load(INVENTORY_BOW_ICON)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot.add_child(icon)
			# Phải đặt position/size SAU khi add_child: trước khi node vào
			# cây, Control tự lấy kích thước min bằng kích thước texture nên
			# gán trước sẽ bị ghi đè (bow_icon.png là 1254x1254).
			icon.position = ICON_POS
			icon.size = ICON_SIZE
	select_inventory_slot(1)

func select_inventory_slot(slot_number: int) -> void:
	if slot_number < 1 or slot_number > _inventory_slots.size():
		return
	_selected_inventory_slot = slot_number
	for index in range(_inventory_slots.size()):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.12, 0.88)
		style.border_width_left = 3 if index + 1 == slot_number else 1
		style.border_width_top = style.border_width_left
		style.border_width_right = style.border_width_left
		style.border_width_bottom = style.border_width_left
		style.border_color = Color(1.0, 0.82, 0.25, 1.0) if index + 1 == slot_number else Color(0.8, 0.8, 0.8, 0.75)
		_inventory_slots[index].add_theme_stylebox_override("panel", style)

## Các nút pause vẽ bằng TextureRect con tên "Art" nên không có stylebox hover
## của theme. Tô sáng trực tiếp TextureRect để giữ phản hồi khi rê chuột.
func _bind_hover(button: Button) -> void:
	if button == null:
		return
	var art := button.get_node_or_null("Art") as TextureRect
	if art == null:
		return
	var lit := func() -> void: art.modulate = Color(1.18, 1.18, 1.18)
	var normal := func() -> void: art.modulate = Color.WHITE
	button.mouse_entered.connect(lit)
	button.mouse_exited.connect(normal)
	button.focus_entered.connect(lit)
	button.focus_exited.connect(normal)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_1 and event.keycode <= KEY_5:
		select_inventory_slot(event.keycode - KEY_0)
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		_toggle_pause()

func _toggle_pause() -> void:
	if pause_overlay:
		var should_pause := not pause_overlay.visible
		pause_overlay.visible = should_pause
		get_tree().paused = should_pause
		_sync_overlay_chrome()
		if pause_overlay.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Thanh inventory nằm sát đáy màn hình, đè lên các hàng dưới cùng của panel
## Tuỳ chọn/Tạm dừng. Khi đang mở overlay che toàn màn thì thanh đó cũng vô
## nghĩa (không bấm được), nên ta ẩn đi cho khỏi che.
##
## Trạng thái được suy ra từ chính các overlay chứ không nhận tham số, và mọi
## thay đổi hiển thị đều gọi qua `_on_overlay_visibility_changed()` — nhờ vậy
## ai bật/tắt overlay bằng đường nào cũng không bị lệch.
##
## CHỈ thanh inventory mới bị ẩn. Cần điều khiển ảo thì không: nó nằm ở góc
## dưới bên trái, không hề chạm panel, và trạng thái hiện/ẩn của nó do tín hiệu
## `hardware_visibility_changed` quyết định. Trước đây hàm này có ẩn joystick
## khi mở overlay nhưng không khôi phục lại, khiến joystick biến mất vĩnh viễn
## sau lần đầu mở Tuỳ chọn.
func _sync_overlay_chrome() -> void:
	if _inventory_bar == null:
		return
	var overlay_open := (pause_overlay != null and pause_overlay.visible) \
		or (options_overlay != null and options_overlay.visible) \
		or (complete_overlay != null and complete_overlay.visible)
	_inventory_bar.visible = not overlay_open

func _on_overlay_visibility_changed() -> void:
	_sync_overlay_chrome()

func _resume() -> void:
	if pause_overlay:
		pause_overlay.visible = false
	get_tree().paused = false
	_sync_overlay_chrome()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Đổi qua lại góc nhìn thứ ba / thứ nhất. `GameManager.set_camera_mode()` tự
## lưu và phát `camera_mode_changed`, mà `player.gd` đang lắng nghe nên không
## cần gọi thêm gì ở đây.
func _toggle_camera_mode() -> void:
	var next: int = GameManager.CameraMode.FIRST_PERSON \
		if GameManager.camera_mode == GameManager.CameraMode.THIRD_PERSON \
		else GameManager.CameraMode.THIRD_PERSON
	GameManager.set_camera_mode(next)


## Mở màn tuỳ chọn ngay trên menu tạm dừng. Cây vẫn ở trạng thái paused
## nên người chơi vẫn dừng, và đóng là quay lại đúng menu tạm dừng.
func _open_options() -> void:
	if options_overlay:
		options_overlay.visible = true
	# Ẩn khung pause để không chồng hai khung lên nhau.
	if pause_overlay:
		pause_overlay.visible = false
	_sync_overlay_chrome()

func _close_options() -> void:
	if options_overlay:
		options_overlay.visible = false
	if pause_overlay:
		pause_overlay.visible = true
	_sync_overlay_chrome()

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func set_status(message: String) -> void:
	if lbl_level:
		lbl_level.text = message

## Đưa số coin của màn lên bộ đếm trên HUD. `_amount` là tham số của tín hiệu
## `GameManager.level_coins_changed`; để mặc định để còn gọi trực tiếp khi
## vào màn.
func _refresh_coin_counter(_amount: int = -1) -> void:
	if lbl_coin_count:
		lbl_coin_count.text = str(GameManager.level_coins)

## Màn hoàn thành: 3 ngôi sao theo thời gian, số coin vừa thu thập, nút chơi
## lại. Cây vẫn paused để nhân vật giữ pose VictorySign.
## `earned_coins` là số coin màn này vừa nộp vào ví (mặc định -1 = lấy bộ đếm
## hiện tại, hữu ích khi gọi trực tiếp từ test).
func show_level_complete(level_num: int, stars: int, seconds: float, earned_coins: int = -1) -> void:
	if complete_overlay == null:
		return
	_set_stars(stars)
	_refresh_coin_counter()
	if lbl_coins:
		lbl_coins.text = str(GameManager.level_coins if earned_coins < 0 else earned_coins)
	_refresh_next_level_button(level_num)
	complete_overlay.visible = true
	_sync_overlay_chrome()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

## Tính màn kế tiếp và ẩn/hiện nút cho vừa. Ở màn cuối (hoặc màn không có trong
## `LEVELS`) không có gì để sang nên nút bị ẩn hoàn toàn.
func _refresh_next_level_button(level_num: int) -> void:
	_next_level = GameManager.next_level_after(level_num)
	if btn_next:
		btn_next.visible = _next_level > 0

## Sang thẳng màn kế tiếp. Cây đang paused (nhân vật giữ pose VictorySign) nên
## phải bỏ pause trước khi đổi scene.
func _on_next_level_pressed() -> void:
	if _next_level <= 0:
		return
	get_tree().paused = false
	GameManager.load_level(_next_level)

## Sao giữa dung ban Large, hai ben dung ban Small. Tô sáng từ trái sang
## phải: đạt `stars` ngôi sao đầu tiên sẽ vàng, phần còn lại xám.
func _set_stars(stars: int) -> void:
	if stars_row == null:
		return
	const CENTER := 1
	var gold := load("res://assets/UI/Icons/Icon_Large_Star.png") as Texture2D
	var grey := load("res://assets/UI/Icons/Icon_Large_StarGrey.png") as Texture2D
	var gold_small := load("res://assets/UI/Icons/Icon_Small_Star.png") as Texture2D
	var grey_small := load("res://assets/UI/Icons/Icon_Small_StarGrey.png") as Texture2D
	var index := 0
	for child in stars_row.get_children():
		var icon := child as TextureRect
		if icon != null:
			var earned := index < stars
			if index == CENTER:
				icon.texture = gold if earned else grey
			else:
				icon.texture = gold_small if earned else grey_small
		index += 1

func _close_complete() -> void:
	if complete_overlay:
		complete_overlay.visible = false
	_sync_overlay_chrome()

func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
