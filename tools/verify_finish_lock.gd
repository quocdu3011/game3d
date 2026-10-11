extends SceneTree

## Kiem chung: sau khi buoc vao CheckPoint_3 (finish), nguoi choi khong
## dich chuyen duoc, khong nhay duoc, nhung phim di chuyen van xoay nhan vat.

var _lv: Node3D
var _p: CharacterBody3D
var _skin: Node3D
var _settle := 0
var _locked_at := -1.0
var _lock_seen := -1.0
var _t := 0.0
var _pos_locked := Vector3.ZERO
var _facing: Array[float] = []
var _vel_max := 0.0
var _jump_attempts := 0
var _moved_ok := true
var _line := ""

func _initialize() -> void:
	# QUAN TRONG: bo test nay nap `level_1.tscn` va dua player vao CheckPoint3,
	# nen `level_controller._finish_level()` se chay that va ghi tien do.
	# Hay `save_path` sang file tam TRUOC KHI nap scene, neu khong no se ghi
	# de luu tien do that cua nguoi choi (da xay ra mot lan: 3 sao ma nguoi
	# choi chua bao gio dat duoc).
	var gm := root.get_node_or_null("GameManager")
	if gm:
		gm.save_path = "user://__verify_finish_lock.cfg"

	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 400)
	cs.shape = box
	cs.position = Vector3(0, -0.5, 0)
	body.add_child(cs)
	root.add_child(body)
	_lv = (load("res://scenes/maps/level_1.tscn") as PackedScene).instantiate()
	root.add_child(_lv)
	_p = (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	_p.position = Vector3(0, 2, 0)
	root.add_child(_p)

func _process(delta: float) -> bool:
	_t += delta
	_settle += 1
	if _skin == null:
		var slot := _p.get_node_or_null("SkinSlot")
		if slot and slot.get_child_count() > 0:
			_skin = slot.get_child(0)
	if _p == null or not is_instance_valid(_p):
		print("PLAYER BI XOA"); quit(1); return true

	# --- Chay pha 1: tu do ---
	if _locked_at < 0.0:
		if _settle > 30:
			# CheckPoint3 trong level_1 nam o day (doc tu file scene).
			_p.global_position = Vector3(145.72, 60.5, -0.85)
		if _settle > 40 and _p.is_movement_locked():
			# Cho roi xuong san truoc: khoa khong chan trong luc, nen nhan vat
			# van roi mot chung. Chi do lech do sau khi da dung chan.
			if _p.is_on_floor() and _t - _lock_seen > 0.5:
				_locked_at = _t
				_pos_locked = _p.global_position
			if _lock_seen < 0.0:
				_lock_seen = _t
		elif _settle > 400:
			print("KHONG KHOA DUOC"); quit(1); return true
		return false

	# --- Ph�� 2: sau khi khoa, bam phim di chuyen lien tuc ---
	var keys := [KEY_W, KEY_D, KEY_S, KEY_A]
	var key: int = keys[int(_t * 6.0) % keys.size()]
	Input.action_press("move_forward" if key == KEY_W else "move_right" if key == KEY_D else "move_back" if key == KEY_S else "move_left")
	if _settle % 20 == 0:
		_jump_attempts += 1
		Input.action_press("jump")

	if _settle % 4 == 0 and _skin:
		_facing.append(_skin.rotation.y)

	_vel_max = maxf(_vel_max, Vector2(_p.velocity.x, _p.velocity.z).length())
	# "Khong the di chuyen" tinh theo CHIEU NGANG (x/z). Chieu doc van bi
	# trong luc nhan vat roi dap san — do la trong luc, khong phai input.
	var d := _p.global_position - _pos_locked
	var drift := Vector2(d.x, d.z).length()
	if _t - _locked_at > 0.35 and drift > 0.05:
		_moved_ok = false
		if _line == "":
			_line = "\n  lech ngang: x=%+.3f z=%+.3f tai %+.2fs" % [d.x, d.z, _t - _locked_at]

	if _settle % 4 == 0:
		Input.action_release(key_action_of(key))
		Input.action_release("jump")

	if _t - _locked_at > 2.5:
		_report(drift)
		quit(0 if (_moved_ok and _facing.size() > 4) else 1)
		return true
	return false

func key_action_of(k: int) -> String:
	match k:
		KEY_W: return "move_forward"
		KEY_S: return "move_back"
		KEY_A: return "move_left"
		_: return "move_right"

func _report(drift: float) -> void:
	var lo := 999.0
	var hi := -999.0
	var changed := 0.0
	for i in range(_facing.size()):
		lo = minf(lo, _facing[i])
		hi = maxf(hi, _facing[i])
		if i > 0:
			changed += absf(angle_difference(_facing[i - 1], _facing[i]))
	print("=== Kiem chung khoa di chuyen sau khi thang ===")
	print("vao vung finish sau %.2fs" % _locked_at)
	print("")
	print("khong dich chuyen ngang: ", "OK" if _moved_ok else "LOI (%s)" % _line)
	print("roi dap san (doc)    : %.3f don vi (trong luc, khong phai input)" % (_p.global_position.y - _pos_locked.y))
	print("khong nhay duoc     : ", "OK" if _vel_max < 0.05 and _jump_attempts > 0 else "LOI")
	print("van xoay duoc       : ", "OK" if _facing.size() > 4 else "LOI")
	print("")
	print("giaoc do nhan vat  : min %.2f rad | max %.2f rad | tong bien doi %.2f rad" % [lo, hi, changed])
	print("toc do ngang toi da : %.3f (van bang 0)" % _vel_max)
	print("so lan bam nhay     : %d" % _jump_attempts)
	if not _moved_ok:
		print(_line)
