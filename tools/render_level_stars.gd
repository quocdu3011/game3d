extends SceneTree

## Render man chon level voi du lieu sao gia lap (L1=3, L2=2, L3=1, L4=0).
##   xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --rendering-driver vulkan --path . -s res://tools/render_level_stars.gd

const OUT := "res://.render/level_select"

var _scene: Control
var _t := 0.0
var _ready := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_scene = (load("res://scenes/ui/level_select.tscn") as PackedScene).instantiate()
	root.add_child(_scene)

func _process(delta: float) -> bool:
	_t += delta
	if not _ready:
		_ready = true
		# Autoload `_load_progress()` chay luc scene vao cay nen gan du lieu
		# gia lap sau do, va tro save_path sang file tam.
		var gm := root.get_node("GameManager")
		gm.save_path = "user://__render_level_stars.cfg"
		gm.completed_levels.clear()
		gm.level_stars.clear()
		gm.level_stars[1] = 3
		gm.level_stars[2] = 2
		gm.level_stars[3] = 1
		gm.completed_levels[1] = true
		gm.completed_levels[2] = true
		gm.completed_levels[3] = true
		# Nap lai scene de `_ready()` cua level_select chay lai tren du lieu moi.
		root.remove_child(_scene)
		_scene.queue_free()
		_scene = (load("res://scenes/ui/level_select.tscn") as PackedScene).instantiate()
		root.add_child(_scene)
		return false

	if _t > 0.5:
		var img := root.get_texture().get_image()
		if img:
			img.save_png("%s/01_man_chon_level.png" % OUT)
			print("Da luu %s/01_man_chon_level.png" % OUT)
		quit(0)
		return true
	return false
