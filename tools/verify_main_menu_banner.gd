extends SceneTree

## Kiem chung banner cam cua main menu luon can giua man hinh o moi ty le khung hinh.
##
## Truoc day `BannerOrange` la `Sprite2D` nam o toa do pixel cua (575, 103) —
## gan dung giua man hinh base 1152x648. Tren dien thoại man hinh rong hon
## (20:9, 19.5:9) thi viewport giu nguyen chieu cao 648 va noi rong ra, banner
## in het ve ben trai. Bay gio no la `TextureRect` neo giua theo `anchor_*`.

const SCENE := "res://scenes/ui/main_menu.tscn"

## Cac kich thuoc viewport thuong gap (chieu cao giu o 648 nhu may tinh).
const SIZES: Array[Vector2i] = [
	Vector2i(1152, 648),   # may tinh 16:9
	Vector2i(1440, 648),   # dien thoai 20:9
	Vector2i(1404, 648),   # dien thoai 19.5:9
	Vector2i(864, 648),    # tablet 4:3
]

const CENTER_TOLERANCE := 1.0

var _step := 0
var _scene: Control
var _index := 0
var _base_y := 0.0
var _bad := 0

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	match _step:
		0:
			_step = 1
			var gm := root.get_node("GameManager")
			gm.save_path = "user://__verify_main_menu_banner.cfg"
			_scene = (load(SCENE) as PackedScene).instantiate()
			root.add_child(_scene)
			return false
		1:
			# Cho `_ready()` va vong layout dau chay xong truoc khi do.
			if int(Engine.get_process_frames()) < 4:
				return false
			_step = 2
			_check_static()
			return false
		2:
			# Do tung kich thuoc mot lan moi frame: doi kich thuoc root roi
			# de cho layout chay lai truoc khi doc rect.
			if _index >= SIZES.size():
				print("")
				print("=== TAT CA DUNG ===" if _bad == 0 else "=== %d LOI ===" % _bad)
				quit(0 if _bad == 0 else 1)
				return true
			var size: Vector2i = SIZES[_index]
			root.size = size
			root.content_scale_size = size
			_index += 1
			_step = 3
			return false
		3:
			_step = 2
			_check_size(SIZES[_index - 1])
			return false
	return false

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_bad += 1
	print("%-46s : %s %s" % [label, "OK" if ok else "LOI", detail])

func _check_static() -> void:
	print("=== Kiem chung banner main menu ===")
	var banner := _scene.get_node_or_null("BannerOrange")
	_check("BannerOrange ton tai", banner != null)
	if banner == null:
		return
	_check("la TextureRect co texture",
		banner is TextureRect and (banner as TextureRect).texture != null,
		"(loai = %s)" % banner.get_class())
	if banner is Control:
		_check("nhay qua chuot (mouse_filter = IGNORE)",
			(banner as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"(=%d)" % (banner as Control).mouse_filter)
		_check("neo ngang giua theo anchor",
			is_equal_approx((banner as Control).anchor_left, 0.5)
				and is_equal_approx((banner as Control).anchor_right, 0.5),
			"(anchor_left = %.2f, anchor_right = %.2f)"
				% [(banner as Control).anchor_left, (banner as Control).anchor_right])

## Toa do giua cua hinh banner tren man hinh. Doc ca `Control` (qua rect) va
## `Node2D` (qua toa do cuc bo + texture) de tool bat duoc ca ban cu.
func _visual_centre(node: Node) -> Vector2:
	if node is Control:
		var ctrl := node as Control
		return ctrl.get_global_rect().get_center()
	var n2 := node as Node2D
	if n2 == null:
		return Vector2.ZERO
	var size := Vector2(64, 64)
	var tex := n2.get("texture") as Texture2D
	if tex != null:
		size = tex.get_size() * n2.get("scale")
	return n2.get_global_transform() * (size * 0.5)

func _check_size(size: Vector2i) -> void:
	var banner := _scene.get_node_or_null("BannerOrange")
	if banner == null:
		_bad += 1
		return
	var centre := _visual_centre(banner)
	if _index == 1:
		_base_y = centre.y
	_check("can giua ngang o %dx%d" % [size.x, size.y],
		absf(centre.x - size.x * 0.5) <= CENTER_TOLERANCE,
		"(banner x = %.1f, giua man hinh = %.1f, lech = %+.1f px)"
			% [centre.x, size.x * 0.5, centre.x - size.x * 0.5])
	_check("khong doi do cao o %dx%d" % [size.x, size.y],
		absf(centre.y - _base_y) <= CENTER_TOLERANCE,
		"(y = %.1f, lan dau = %.1f)" % [centre.y, _base_y])
