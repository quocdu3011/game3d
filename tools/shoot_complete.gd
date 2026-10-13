extends SceneTree

## Chụp màn "hoàn thành màn" ở hai trường hợp: màn có màn kế tiếp (nút hiện) và
## màn cuối (nút phải ẩn). Nút Chơi lại nằm bên trái, nút màn tiếp theo bên phải.

const OUT_DIR := "user://__shots"
const SIZE := Vector2i(1152, 648)
const TMP_SAVE := "user://__shot_complete.cfg"

## [tên ảnh, số màn vừa hoàn thành]
const SHOTS: Array[Array] = [["complete_has_next", 1], ["complete_last_level", 4]]

var _step := 0
var _shot := 0
var _live: Node
var _gm_save_path := ""

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	match _step:
		0:
			if _shot >= SHOTS.size():
				_cleanup()
				print("=== DONE ===")
				quit(0)
				return true
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
			root.size = SIZE
			root.content_scale_size = SIZE
			_live = root.get_node("GameManager")
			_gm_save_path = _live.save_path
			_live.save_path = TMP_SAVE
			var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
			root.add_child(hud)
			hud.show_level_complete(int(SHOTS[_shot][1]), 2, 18.5, 7)
			_step = 1
			return false
		1:
			if int(Engine.get_process_frames()) < 8:
				return false
			_step = 0
			_shoot(String(SHOTS[_shot][0]))
			_shot += 1
			return false
	return false

func _shoot(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	var err := img.save_png(path)
	print("%s -> %s (%s)" % [name, ProjectSettings.globalize_path(path),
		"OK" if err == OK else "LOI %d" % err])

func _cleanup() -> void:
	# Gỡ trước khi trả `save_path` về file thật để không ghi đè save người chơi.
	_live.save_path = _gm_save_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))