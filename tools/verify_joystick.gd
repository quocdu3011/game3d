extends SceneTree

## Kiem chung can dieu khien ao "dong" (dynamic): cham o bat ky diem nao trong
## goc duoi ben trai (1/4 chieu ngang, 1/2 chieu doc) thi nut tron bam len tai
## do, va keo sang can phai se nhan action `move_*`.
##
## Su kien cham duoc day vao bang `push_input()` nen kiem duoc ca hinh vi
## (qua tin hieu `pressed`) va hanh dong (qua InputMap) — khong phai chi kiem
## hinh hoc.
##
## Joystick dang o `VISIBILITY_ALWAYS` nen `visible` luon true — thuoc tinh nay
## khong phan biet duoc "hien" voi "an", nhung kiem tra o day chi de bao dam
## control khong bi an ngoai y muon. Phan hinh anh duoc kiem o
## `tools/shoot_joystick.gd` (can chay co render, headless chup anh khong duoc).

const SIZE := Vector2i(1152, 648)

var _step := 0
var _hud: CanvasLayer
var _joystick: Control
var _bad := 0
var _presses := 0
var _releases := 0

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	match _step:
		0:
			_step = 1
			root.size = SIZE
			root.content_scale_size = SIZE
			_hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
			root.add_child(_hud)
			_joystick = _hud.get_node("VirtualJoystick")
			_joystick.pressed.connect(func(): _presses += 1)
			_joystick.released.connect(func(_v): _releases += 1)
			return false
		1:
			if int(Engine.get_process_frames()) < 8:
				return false
			_step = 2
			_check_geometry()
			return false
		2:
			# Cham o goc duoi ben trai, khac vi tri nut truoc day.
			_step = 3
			_touch_at(Vector2(40.0, 600.0), true)
			return false
		3:
			if int(Engine.get_process_frames()) < 14:
				return false
			_step = 4
			_check("chạm trong vùng -> joystick nhận cảm ứng", _presses == 1,
				"(so lan nhan = %d)" % _presses)
			_drag(Vector2(140.0, 600.0))
			return false
		4:
			if int(Engine.get_process_frames()) < 18:
				return false
			_step = 5
			_check("kéo sang phải -> nhấn move_right",
				Input.is_action_pressed("move_right")
					and not Input.is_action_pressed("move_left"),
				"(move_right = %s, move_left = %s)"
					% [Input.is_action_pressed("move_right"), Input.is_action_pressed("move_left")])
			_touch_at(Vector2(140.0, 600.0), false)
			return false
		5:
			if int(Engine.get_process_frames()) < 22:
				return false
			_step = 6
			_check("thả tay -> nhả action", not Input.is_action_pressed("move_right"),
				"(move_right = %s)" % Input.is_action_pressed("move_right"))
			_check("thả tay -> joystick nhận thả", _releases == 1,
				"(so lan tha = %d)" % _releases)
			# Cham ngoài vung (nửa trên bên phải): phai khong nhận cảm ứng.
			_touch_at(Vector2(700.0, 200.0), true)
			return false
		6:
			if int(Engine.get_process_frames()) < 28:
				return false
			_step = 7
			_check("chạm ngoài vùng -> joystick không nhận", _presses == 1,
				"(van con %d lan nhan)" % _presses)
			_check("chạm ngoài vùng -> không nhấn action di chuyển",
				not Input.is_action_pressed("move_right")
					and not Input.is_action_pressed("move_left"))
			_touch_at(Vector2(700.0, 200.0), false)
			return false
		7:
			if int(Engine.get_process_frames()) < 32:
				return false
			_report()
			quit(0 if _bad == 0 else 1)
			return true
	return false

func _touch_at(pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = pos
	event.pressed = pressed
	root.push_input(event)

func _drag(to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = to
	event.relative = to - Vector2(40.0, 600.0)
	root.push_input(event)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_bad += 1
	print("%-46s : %s %s" % [label, "OK" if ok else "LOI", detail])

func _check_geometry() -> void:
	print("=== Kiem chung can dieu khien ao dong ===")
	var vp := root.get_visible_rect().size
	var r := _joystick.get_global_rect()
	_check("vùng chạm rộng 1/4 chiều ngang",
		is_equal_approx(r.size.x, vp.x * 0.25),
		"(%.1f / %.1f)" % [r.size.x, vp.x * 0.25])
	_check("vùng chạm cao 1/2 chiều dọc",
		is_equal_approx(r.size.y, vp.y * 0.5),
		"(%.1f / %.1f)" % [r.size.y, vp.y * 0.5])
	_check("vùng chạm nằm sát góc dưới trái",
		is_equal_approx(r.position.x, 0.0) and is_equal_approx(r.end.y, vp.y),
		"(x %.1f..%.1f, y %.1f..%.1f)" % [r.position.x, r.end.x, r.position.y, r.end.y])
	_check("joystick ở chế độ Dynamic", _joystick.get("joystick_mode") == 1,
		"(joystick_mode = %s)" % _joystick.get("joystick_mode"))
	_check("joystick luôn hiện", _joystick.get("visibility_mode") == 0,
		"(visibility_mode = %s)" % _joystick.get("visibility_mode"))
	_check("nút nhảy vẫn hiện", (_hud.get_node("JumpButton") as Control).visible)
	_check("nút cung vẫn hiện", (_hud.get_node("BowButton") as Control).visible)

func _report() -> void:
	print("")
	print("=== TAT CA DUNG ===" if _bad == 0 else "=== %d LOI ===" % _bad)