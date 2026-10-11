extends SceneTree

## Render Bomb: bom an, bom vua hien len, pha chuan bi, va lan no.
##   xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --rendering-driver vulkan --path . -s res://tools/render_bomb.gd

const OUT := "res://.render/bomb"

var _bomb: Node3D
var _cam: Camera3D
var _t := 0.0
var _shot := 0
var _ignited := false
var _t0 := -1.0          # thoi diem kich no

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_bomb = (load("res://scenes/Entity/Item/Bomb.tscn") as PackedScene).instantiate()
	root.add_child(_bomb)

	var key := DirectionalLight3D.new()
	key.light_energy = 1.2
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-45, 40, 0)
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.6
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-25, -130, 0)
	root.add_child(fill)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.10, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.53, 0.6)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 42.0
	root.add_child(_cam)

func _process(delta: float) -> bool:
	_t += delta
	# `look_at` phai chay o _process: node chua nam trong cay se bi Godot chan.
	# Camera lui xa o cac goc chup no — neu de sat, khoi se nuot man hinh.
	var cam_pos := Vector3(2.4, 1.6, 2.8) if _shot < 3 else Vector3(6.2, 3.4, 7.0)
	_cam.global_position = cam_pos
	_cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)

	match _shot:
		0:
			# 1. Bom an: khong gi thay.
			if _t > 0.4:
				_snap("01_an_khi_dat_vao_map")
				_ignite()
				_t = 0.0
				_shot = 1
		1:
			# 2. Vua cham: bom hien len (0.10s sau khi kich no).
			if _t - _t0 > 0.10:
				_snap("02_bom_hien_len")
				_t = 0.0
				_shot = 2
		2:
			# 3. Giua pha chay noi (fuse_time = 1.55s): den do + lua bay.
			if _t - _t0 > 1.15:
				_snap("03_chuan_bi_phat_no")
				_t = 0.0
				_shot = 3
		3:
			# 4. Sau khi no ~0.2s (no bat dau o 1.55s ke tu luc _ignite).
			if _t - _t0 > 1.72:
				_shot = 4          # lui camera TRUOC khi chup
				return false
				_shot = 4
		4:
			if _t - _t0 > 1.78:
				var ex := _bomb.get_node_or_null("Explosion") as GPUParticles3D
				var sm := _bomb.get_node_or_null("Smoke") as GPUParticles3D
				print("[diag] t-t0=%.2f  bomb=%s  fire.emitting=%s  smoke.emitting=%s  cam=%s" % [
					_t - _t0, is_instance_valid(_bomb),
					ex.emitting if ex else "-", sm.emitting if sm else "-", _cam.global_position])
				_snap("04_phat_no")
				_t = 0.0
				_shot = 5
		5:
			if _t - _t0 > 2.45:
				_snap("05_khoi_tan")
				quit(0)
				return true
	return false

func _ignite() -> void:
	if _ignited:
		return
	_ignited = true
	_t0 = _t
	_bomb._fusing = true
	_bomb._spent = true
	var trigger := _bomb.get_node_or_null("Trigger") as Area3D
	if trigger:
		trigger.set_deferred("monitoring", false)
	var m := _bomb.get_node_or_null("Model") as Node3D
	if m:
		m.visible = true
	var fl := _bomb.get_node_or_null("FuseLight") as OmniLight3D
	if fl:
		fl.visible = true
	var sp := _bomb.get_node_or_null("Sparks") as GPUParticles3D
	if sp:
		sp.emitting = true

func _snap(name: String) -> void:
	var img := root.get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [OUT, name])
		print("Da luu %s/%s.png" % [OUT, name])
