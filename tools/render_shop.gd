extends SceneTree

## Render man shop o hai trang thai: chua mua gi, va sau khi da mo khoa mot
## nhan vat. Chay qua xvfb vi can GPU.
##   xvfb-run -a -s "-screen 0 1600x900x24" \
##     godot --rendering-driver vulkan --path . -s res://tools/render_shop.gd

const OUT := "res://.render/shop"
const SAVE := "user://__render_shop.cfg"

var _t := 0.0
var _stage := 0
var _shop: Control
var _gm: Node

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_gm = root.get_node("GameManager")
	_gm.save_path = SAVE

func _process(delta: float) -> bool:
	_t += delta
	match _stage:
		0:
			_gm.reset_progress()
			_gm.coins = 30          # khong du gia -> the gdbot khoa nut MUA
			_gm.selected_skin = "gobot"
			_gm.unlocked_skins.clear()
			_shop = (load("res://scenes/ui/shop.tscn") as PackedScene).instantiate()
			root.add_child(_shop)
			_stage = 1
			_t = 0.0
		1:
			if _t > 1.2:
				_snap("01_shop_chua_mua")
				_stage = 2
				_t = 0.0
		2:
			if _t > 0.3:
				_gm.coins = 200
				_gm.unlock_skin("sophia")
				_gm.select_skin("sophia")
				for c in _shop.get_node("%CardRow").get_children():
					c.refresh()
				_shop.get_node("%LblMessage").text = "Đã chọn nhân vật Sophia"
				_stage = 3
				_t = 0.0
		3:
			if _t > 1.2:
				_snap("02_shop_da_mua")
				quit(0)
				return true
	return false

func _snap(name: String) -> void:
	var img := root.get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [OUT, name])
		print("Da luu %s/%s.png" % [OUT, name])