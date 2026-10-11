extends SceneTree

## Render ảnh tổng quát level 2: dựng thẳng scene, đặt Camera3D bao trọn AABB thật
## của map, chụp lại khung hình và lưu PNG. Chạy ngoài editor nên không có HUD,
## không có Player — chỉ hình học của bản đồ.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --rendering-driver vulkan --path . -s res://tools/render_level_overview.gd
##
## Shadow bị tắt: ánh sáng chéo của map đổ bóng phủ đen toàn bộ đoạn xa, đọc
## hình không nổi. Ảnh này để bố trí map nên bỏ bóng là hợp lý.

const LEVEL := "res://scenes/maps/level_2.tscn"
const OUT_DIR := "res://.render"

var _level: Node3D
var _cam: Camera3D
var _light: DirectionalLight3D
var _bounds: AABB
var _shots: Array[Dictionary] = []
var _index := 0
var _settle := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# Cong cu nay nap scene level that. Neu scene do co finish checkpoint thi
	# `_finish_level()` co the chay va ghi de luu tien do — hay `save_path`
	# sang file tam cho an toan.
	var gm := root.get_node_or_null("GameManager")
	if gm:
		gm.save_path = "user://__render_level_overview.cfg"
	_level = (load(LEVEL) as PackedScene).instantiate()
	root.add_child(_level)

	_light = _level.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if _light:
		_light.shadow_enabled = false

	# Scene chi co mot DirectionalLight nen mat xa roi tu ve den. Them den phu doi
	# chieu va tang ambient de doc duoc hinh khoi (day la anh so do, khong can dep).
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.7
	fill.light_color = Color(0.85, 0.88, 1.0)
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-42, 125, 0)
	_level.add_child(fill)

	var env_node := _level.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		var env := env_node.environment
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.58, 0.64)
		env.ambient_light_energy = 0.9
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.10, 0.11, 0.14)

	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 50.0
	_cam.near = 0.05
	_cam.far = 3000.0
	root.add_child(_cam)

	_bounds = AABB()
	print("se do AABB o frame dau tien (node phai nam trong SceneTree moi doc duoc global_transform)")

	# Mỗi shot: hướng nhìn (Vector3 hướng về map) + hệ số lùi so với bán kính AABB.
	# 1.0 = vừa khít, lớn hơn = lùi xa thêm.
	_shots = [
		{"ten": "01_toan_canh_cheo", "dir": Vector3(-0.75, -0.60, -0.28), "khu": 1.05, "look": 0.45},
		{"ten": "02_nhin_thang_tieu", "dir": Vector3(0, -1, -0.001), "khu": 1.15, "look": 0.0},
		{"ten": "03_doc_cheo_thap", "dir": Vector3(-0.25, -0.22, -0.94), "khu": 0.75, "look": 0.5},
		{"ten": "04_doc_cheo_cao", "dir": Vector3(-0.15, -0.85, -0.50), "khu": 1.0, "look": 0.3},
		{"ten": "05_dau_cau3", "dir": Vector3(-0.55, -0.35, -0.75), "khu": 0.30, "look": 0.75},
		{"ten": "06_dau_cau1", "dir": Vector3(0.55, -0.35, -0.75), "khu": 0.30, "look": 0.15},
	]
	_settle = -1   # -1: chua do bounds; >=0: dem nghiep on dinh truoc khi chup

func _process(_delta: float) -> bool:
	# Frame dau: don Player/HUD do scene tu spawn, roi do AABB.
	if _settle == -1:
		# level_controller._ready() tu spawn Player offline, va player.gd ep
		# camera cua no thanh `current` — se de camera cua script nay. Bo han.
		var players := _level.get_node_or_null("Players")
		if players:
			for child in players.get_children():
				child.free()
		var hud := _level.get_node_or_null("HUD")
		if hud:
			hud.visible = false
		_cam.current = true

		_bounds = _world_bounds()
		print("AABB cua map: vi tri %s  kich thuoc %s" % [_bounds.position, _bounds.size])
		_settle = 0
		return false

	if _index >= _shots.size():
		quit(0)
		return true

	var shot: Dictionary = _shots[_index]

	if _settle == 0:
		var centre := _bounds.get_center()
		var target: Vector3 = centre + Vector3.UP * (_bounds.size.y * (shot["look"] as float) * 0.35)
		var dir: Vector3 = (shot["dir"] as Vector3).normalized()
		# Lùi xa đủ để AABB vừa khít khung hình theo cả chiều ngang và dọc.
		var radius := _bounds.size.length() * 0.5
		var dist: float = radius * (shot["khu"] as float) / tan(deg_to_rad(_cam.fov) * 0.5) * 0.85
		_cam.global_position = target - dir * dist
		_cam.look_at(target, Vector3.UP)
		_cam.current = true
		_settle = 1
		return false

	_settle += 1
	if _settle < 4:
		return false

	var image := root.get_texture().get_image()
	if image == null:
		printerr("Khong lay duoc khung hinh")
		_index += 1
		_settle = 0
		return false

	var path := "%s/%s.png" % [OUT_DIR, shot["ten"]]
	var err := image.save_png(path)
	if err == OK:
		print("Da luu %s  cam tai %s" % [path, _cam.global_position])
	else:
		printerr("Luu that bai ", path, " loi ", err)

	_index += 1
	_settle = 0
	return false

func _world_bounds() -> AABB:
	var world := _level.get_node_or_null("World")
	var out := AABB()
	var first := true
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out