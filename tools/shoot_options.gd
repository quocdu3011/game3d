extends SceneTree

## Chụp ảnh màn Tuỳ chọn ra PNG để soi bằng mắt — hàng cảm biến con quay phải
## nằm đúng chỗ (không đè hàng "GÓC NHÌN") và nút phải sáng khi đang bật.

const OUT_DIR := "user://__shots"
const SIZE := Vector2i(1152, 648)
const TMP_SAVE := "user://__shot_options.cfg"

## Các trạng thái cần chụp: tên file + trạng thái bật của cờ.
const SHOTS: Array[Array] = [["options_tilt_off", false], ["options_tilt_on", true]]

var _step := 0
var _hud: CanvasLayer
var _shot := 0
var _gm_save_path := ""
var _ready_at := 0

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	# Mỗi trạng thái cần: đặt cờ -> dựng HUD -> chờ vài khung cho layout -> chup.
	match _step:
		0, 3:
			if _shot >= SHOTS.size():
				_cleanup()
				print("=== DONE ===")
				quit(0)
				return true
			var entry: Array = SHOTS[_shot]
			_set_tilt(bool(entry[1]))
			if _hud != null:
				_hud.queue_free()
			_hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
			root.add_child(_hud)
			_hud.get_node("OptionsOverlay").visible = true
			_step += 1
			_ready_at = int(Engine.get_process_frames()) + 6
			return false
		1, 4:
			if int(Engine.get_process_frames()) < _ready_at:
				return false
			_shoot(String(SHOTS[_shot][0]))
			_shot += 1
			_step = 0
			return false
	return false

func _set_tilt(enabled: bool) -> void:
	var gm := root.get_node("GameManager")
	if _gm_save_path == "":
		_gm_save_path = gm.save_path
	gm.save_path = TMP_SAVE
	gm.set_tilt_camera_enabled(enabled)

func _shoot(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	var err := img.save_png(path)
	print("%s -> %s (%s)" % [name, ProjectSettings.globalize_path(path),
		"OK" if err == OK else "LOI %d" % err])

func _cleanup() -> void:
	var gm := root.get_node("GameManager")
	# Phải gỡ cờ TRƯỚC khi trả `save_path` về file thật: `set_tilt_camera_enabled()`
	# gọi `_save_progress()` nên nếu trả đường dẫn trước thì lần ghi đó rơi vào
	# save thật của người chơi.
	gm.set_tilt_camera_enabled(false)
	gm.save_path = _gm_save_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))
