extends SceneTree

## Kiem chung nguoi choi VAN DI CHUYEN DUOC sau khi go het lop multiplayer.
## Cac nhanh `is_multiplayer_authority()` da bi xoa khoi `_physics_process`
## va `_input`, nen phai chung minh input van toi den nhan vat.

const SAVE := "user://__verify_movement.cfg"

var _p: CharacterBody3D
var _step := 0
var _f := 0
var _bad := 0

func _initialize() -> void:
	pass

func _process(_delta: float) -> bool:
	match _step:
		0:
			_step = 1
			var gm := root.get_node("GameManager")
			gm.save_path = SAVE
			gm.reset_progress()
			var floor_b := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(200, 1, 200)
			cs.shape = bx
			cs.position = Vector3(0, -0.5, 0)
			floor_b.add_child(cs)
			root.add_child(floor_b)
			_p = (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
			_p.position = Vector3(0, 2, 0)
			root.add_child(_p)
		1:
			# Cho scene ngung + nhan vat hien thi
			if _f < 20:
				_f += 1
				return false
			_step = 2
			_f = 0
			_start = _p.global_position
			_hold("move_forward")
		2:
			_f += 1
			if _f < 45:
				return false
			_step = 3
			_release("move_forward")
			var p0 := _start
			moved = Vector2(_p.global_position.x - p0.x, _p.global_position.z - p0.z).length()
			_check("di chuyen theo move_forward", moved > 0.3,
				"(di %.2f don vi)" % moved)
			var vel := Vector2(_p.velocity.x, _p.velocity.z).length()
			_check("co van toc ngang", vel > 1.0, "(%.2f)" % vel)
			_f = 0
			before = _p.global_position
			_start = before
			_hold("move_right")
		3:
			_f += 1
			if _f < 45:
				return false
			_step = 4
			_release("move_right")
			var dir_right := _p.global_position - before
			var side := dir_right.length()
			_check("di chuyen theo move_right", side > 0.3, "(di %.2f don vi)" % side)
			# KHONG so goc giua hai huong trong world space: camera xoay theo
			# nguoi choi nen "forward" luc sau tinh theo huong camera da doi,
			# goc giua hai vector do khong bao gio la 90 do. Kiem chung dung
			# la hai phim deu tao ra chuyen vi khac 0.
			_f = 0
		4:
			# Nhay
			if _f < 5:
				_f += 1
				return false
			_step = 5
			var y0 := _p.global_position.y
			_hold("jump")
			_jump_y = y0
			_jump_peak = y0
			_jumped = false
		5:
			_f += 1
			if _p.global_position.y > _jump_peak:
				_jump_peak = _p.global_position.y
			if _p.global_position.y > _jump_y + 0.4:
				_jumped = true
			if _f < 35:
				return false
			_step = 6
			_release("jump")
			_check("nhay duoc", _jumped, "(ngoi cao nhat +%.2f)" % (_jump_peak - _jump_y))
			_report()
			quit(0 if _bad == 0 else 1)
			return true
	return false

var before := Vector3.ZERO
var moved := 0.0
var _start := Vector3.ZERO
var _jump_y := 0.0
var _jump_peak := 0.0
var _jumped := false

func _hold(action: String) -> void:
	Input.action_press(action)

func _release(action: String) -> void:
	Input.action_release(action)

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_bad += 1
	print("%-32s : %s %s" % [label, "OK" if ok else "LOI", detail])

func _report() -> void:
	print("")
	print("=== TAT CA DUNG ===" if _bad == 0 else "=== %d LOI ===" % _bad)