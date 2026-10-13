extends Control

## Màn Tuỳ chọn (overlay nằm trong HUD): chỉnh âm lượng hiệu ứng, bật/tắt
## nhạc nền và bật/tắt xoay camera bằng cảm biến con quay.
##
## Cố ý là overlay chứ không phải scene riêng: mở lên từ menu tạm dừng
## thì đóng là quay lại đúng menu tạm dừng, không phải load lại màn chơi.

## dB nhỏ nhất tương ứng slider = 0 (coi như tắt hẳn).
const MIN_DB := -40.0

## Màu của nút tròn khi nhạc đang bật / tắt.
const ON_TINT := Color.WHITE
const OFF_TINT := Color(0.45, 0.45, 0.45, 1)

## HUD nghe tín hiệu này để mở lại menu tạm dừng.
signal closed

@onready var slider_sfx: HSlider = get_node_or_null("OptionsPanel/AudioRow/SliderAudio")
@onready var slider_music: HSlider = get_node_or_null("OptionsPanel/MusicRow/SliderMusic")
@onready var toggle_music: Button = get_node_or_null("OptionsPanel/MusicRow/ToggleMusic")
@onready var camera_mode: OptionButton = get_node_or_null("OptionsPanel/CameraRow/CameraMode")
@onready var toggle_tilt: Button = get_node_or_null("OptionsPanel/TiltRow/ToggleTilt")
@onready var slider_tilt: HSlider = get_node_or_null("OptionsPanel/TiltSensRow/SliderTiltSens")
@onready var btn_back: Button = get_node_or_null("OptionsPanel/BtnBack")

func _ready() -> void:
	if slider_sfx:
		slider_sfx.min_value = 0.0
		slider_sfx.max_value = 100.0
		slider_sfx.value = _slider_from_db(SfxPlayer.volume_db)
		slider_sfx.value_changed.connect(_on_sfx_volume_changed)

	if slider_music:
		slider_music.min_value = 0.0
		slider_music.max_value = 100.0
		slider_music.value = _slider_from_db(MusicPlayer.volume_db)
		slider_music.value_changed.connect(_on_music_volume_changed)

	if toggle_music:
		toggle_music.pressed.connect(_on_music_pressed)

	if camera_mode:
		camera_mode.clear()
		camera_mode.add_item("Góc nhìn thứ ba", GameManager.CameraMode.THIRD_PERSON)
		camera_mode.add_item("Góc nhìn thứ nhất", GameManager.CameraMode.FIRST_PERSON)
		camera_mode.select(GameManager.camera_mode)
		camera_mode.item_selected.connect(_on_camera_mode_selected)

	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)

	_setup_tilt_toggle()
	_setup_tilt_sensitivity()
	_refresh_music_state()
	_refresh_tilt_state()

## Cảm biến con quay chỉ có thật trên thiết bị di động. Trên máy tính (và cả
## trong editor) `Input.get_gyroscope()` luôn trả Vector3.ZERO nên bật lên cũng
## vô tác dụng — ta khoá nút và nói rõ lý do thay vì để người chơi bấm hoài.
## `pressed` vẫn nối luôn: `disabled` đã chặn thao tác, còn nối sẵn thì bật/tắt
## vẫn đúng ngay khi chạy trên điện thoại mà không phải ràng buộc lại.
func _setup_tilt_toggle() -> void:
	if toggle_tilt == null:
		return
	toggle_tilt.pressed.connect(_on_tilt_pressed)
	if not OS.has_feature("mobile"):
		toggle_tilt.disabled = true
		toggle_tilt.tooltip_text = "Thiết bị này không có cảm biến con quay"

func _on_tilt_pressed() -> void:
	GameManager.set_tilt_camera_enabled(not GameManager.tilt_camera_enabled)
	_refresh_tilt_state()

## Thanh trượt độ nhạy. Giá trị thật là số thập phân nhỏ (0.05..2.0) nên thanh
## trượt 0..100 chỉ là hình thức, quy đổi qua hai hàm dưới cùng chiều với
## `_slider_from_db()` của slider âm lượng.
func _setup_tilt_sensitivity() -> void:
	if slider_tilt == null:
		return
	slider_tilt.min_value = 0.0
	slider_tilt.max_value = 100.0
	slider_tilt.step = 1.0
	slider_tilt.value = _slider_from_sensitivity(GameManager.tilt_sensitivity)
	slider_tilt.value_changed.connect(_on_tilt_sensitivity_changed)
	_refresh_tilt_sensitivity_label()

func _on_tilt_sensitivity_changed(value: float) -> void:
	GameManager.set_tilt_sensitivity(_sensitivity_from_slider(value))
	_refresh_tilt_sensitivity_label()

## Ghi kèm số thập phân vào tooltip để người chơy chỉnh mù cũng biết đang ở mức
## nào, vì thanh trượt không hiện số.
func _refresh_tilt_sensitivity_label() -> void:
	if slider_tilt == null:
		return
	var value := GameManager.tilt_sensitivity
	slider_tilt.tooltip_text = "Tốc độ xoay camera: %.2f" % value

func _sensitivity_from_slider(value: float) -> float:
	return lerpf(GameManager.TILT_SENSITIVITY_MIN, GameManager.TILT_SENSITIVITY_MAX, value / 100.0)

func _slider_from_sensitivity(value: float) -> float:
	var span := GameManager.TILT_SENSITIVITY_MAX - GameManager.TILT_SENSITIVITY_MIN
	return clampf((value - GameManager.TILT_SENSITIVITY_MIN) / span * 100.0, 0.0, 100.0)

func _on_sfx_volume_changed(value: float) -> void:
	SfxPlayer.set_volume_db(_db_from_slider(value))

func _on_music_volume_changed(value: float) -> void:
	MusicPlayer.set_volume_db(_db_from_slider(value))

func _on_music_pressed() -> void:
	MusicPlayer.set_music_enabled(not MusicPlayer.is_music_enabled())
	_refresh_music_state()

func _on_camera_mode_selected(index: int) -> void:
	if camera_mode == null:
		return
	GameManager.set_camera_mode(camera_mode.get_item_id(index))

func _on_back_pressed() -> void:
	closed.emit()

## Nút tròn giữ nguyên art; trạng thái bật/tắt thể hiện bằng độ sáng
## (sáng = đang bật, tối = đang tắt) thay vì đổi texture.
func _refresh_music_state() -> void:
	if toggle_music == null:
		return
	var on := MusicPlayer.is_music_enabled()
	var art := toggle_music.get_node_or_null("Art") as TextureRect
	if art != null:
		art.modulate = ON_TINT if on else OFF_TINT
	toggle_music.tooltip_text = "Nhạc nền: ĐANG BẬT" if on else "Nhạc nền: ĐANG TẮT"

## Cùng kiểu hiển thị trạng thái với nút nhạc.
func _refresh_tilt_state() -> void:
	if toggle_tilt == null:
		return
	var on := GameManager.tilt_camera_enabled
	var art := toggle_tilt.get_node_or_null("Art") as TextureRect
	if art != null:
		art.modulate = ON_TINT if on else OFF_TINT
	if not toggle_tilt.disabled:
		toggle_tilt.tooltip_text = "Cảm biến con quay: ĐANG BẬT" if on else "Cảm biến con quay: ĐANG TẮT"

func _db_from_slider(value: float) -> float:
	return MIN_DB + (value / 100.0) * -MIN_DB

func _slider_from_db(db: float) -> float:
	return clampf((db - MIN_DB) / -MIN_DB * 100.0, 0.0, 100.0)
