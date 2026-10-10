extends Control

## Màn Tuỳ chọn (overlay nằm trong HUD): chỉnh âm lượng hiệu ứng và
## bật/tắt nhạc nền.
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

	_refresh_music_state()

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

func _db_from_slider(value: float) -> float:
	return MIN_DB + (value / 100.0) * -MIN_DB

func _slider_from_db(db: float) -> float:
	return clampf((db - MIN_DB) / -MIN_DB * 100.0, 0.0, 100.0)
