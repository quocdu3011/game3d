extends SceneTree

## Kiem chung Bomb: an -> cham -> den lao -> no -> ve checkpoint -> bom bi xoa.
## Do thoi gian cham no tu luc bom HIEN ra den luc hat no bat dau.
## Chay 10 lan de bac ngau nhien va do lan mau.

var _runs := 10
var _i := 0
var _t := 0.0
var _state := 0            # 0 cho player, 1 den lao, 2 sau khi no
var _mine: Array[Node] = []

var _seen_hidden := false
var _seen_model := false
var _seen_light := false
var _seen_sparks := false
var _seen_fire := false
var _seen_smoke := false
var _seen_flash := false
var _seen_audio := false
var _seen_respawn := false
var _seen_deleted := false

var _t_visible := -1.0     # bom bat len
var _t_boom := -1.0        # hat no bat dau
var _t_respawn := -1.0     # player ve checkpoint
var _t_deleted := -1.0     # bom bi xoa
var _fuses: Array[float] = []
var _log: Array[String] = []

func _initialize() -> void:
	randomize()
	_spawn()

func _spawn() -> void:
	# Chi goi 2 node TEST tao. Autoload cung la con cua `root` — danh het
	# se lam GameManager bi free va moi thu sap.
	for n in _mine:
		if is_instance_valid(n):
			root.remove_child(n)
			n.free()
	_mine.clear()

	var floor_body := StaticBody3D.new()
	var fshape := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(60, 1, 60)
	fshape.shape = fbox
	fshape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(fshape)
	floor_body.position = Vector3(0, 0, 0)
	root.add_child(floor_body)

	var b := (load("res://scenes/Entity/Item/Bomb.tscn") as PackedScene).instantiate()
	root.add_child(b)
	var p := (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	# Checkpoint o x=50: sau khi no, player phai quay ve day.
	p.position = Vector3(50, 3, 0)
	p.set_respawn_position(Vector3(50, 3, 0))
	root.add_child(p)
	_mine = [floor_body, b, p]

	_state = 0
	_t = 0.0
	_seen_hidden = false
	_seen_model = false
	_seen_light = false
	_seen_sparks = false
	_seen_fire = false
	_seen_smoke = false
	_seen_flash = false
	_seen_audio = false
	_seen_respawn = false
	_seen_deleted = false
	_t_visible = -1.0
	_t_boom = -1.0
	_t_respawn = -1.0
	_t_deleted = -1.0

func _process(delta: float) -> bool:
	_t += delta
	var b := root.get_node_or_null("Bomb")
	var p := root.get_node_or_null("Player") as CharacterBody3D

	# Bom da bi xoa -> ket thuc luot nay
	if _state > 0 and b == null:
		_t_deleted = _t
		_seen_deleted = true
		_record()
		return _next()

	match _state:
		0:
			if b == null:
				return false
			var m0 := b.get_node_or_null("Model") as Node3D
			if m0 and not m0.visible:
				_seen_hidden = true
			if _t > 0.3:
				if p:
					p.global_position = Vector3(0, 1.5, 0)
				_state = 1
		1:
			# --- Pha chay nổ ---
			var m1 := b.get_node_or_null("Model") as Node3D
			var fl := b.get_node_or_null("FuseLight") as OmniLight3D
			var sp := b.get_node_or_null("Sparks") as GPUParticles3D
			var ex := b.get_node_or_null("Explosion") as GPUParticles3D
			if m1 and m1.visible and _t_visible < 0.0:
				_t_visible = _t
			if m1 and m1.visible:
				_seen_model = true
			if fl and fl.visible and fl.light_energy > 0.05:
				_seen_light = true
			if sp and sp.emitting:
				_seen_sparks = true
			if ex and ex.emitting and _t_boom < 0.0:
				_seen_fire = true   # day la khoanh hat no bat dau
				_t_boom = _t
				_fuses.append(_t_boom - _t_visible)
				_state = 2
		2:
			# --- Sau khi nổ: hiệu ứng, hất, checkpoint, xoá ---
			var ex2 := b.get_node_or_null("Explosion") as GPUParticles3D
			var sm := b.get_node_or_null("Smoke") as GPUParticles3D
			var fh := b.get_node_or_null("Flash") as OmniLight3D
			var bo := b.get_node_or_null("Boom") as AudioStreamPlayer3D
			if ex2 and ex2.emitting: _seen_fire = true
			if sm and sm.emitting: _seen_smoke = true
			if fh and fh.visible: _seen_flash = true
			if bo and bo.playing: _seen_audio = true
			if _t_respawn < 0.0 and p and p.global_position.x > 40.0:
				_t_respawn = _t
				_seen_respawn = true
			if _t > _t_boom + 5.0:      # bom chua bi xoa -> that
				_record()
				return _next()
	return false

func _record() -> void:
	_log.append("  lan %2d | cham %.3fs | ve checkpoint %+.2fs | xoa bom %+.2fs" % [
		_i + 1, _fuses[_fuses.size() - 1],
		_t_respawn - _t_boom, _t_deleted - _t_boom])

func _next() -> bool:
	_i += 1
	if _i >= _runs:
		_report()
		quit(0)
		return true
	_spawn()
	return false

func _report() -> void:
	print("=== Kiem chung Bomb (%d lan) ===" % _runs)
	for l in _log: print(l)
	print("")
	print("thoi gian cham no : TB %.3fs | min %.3fs | max %.3fs" % [_stat(_fuses, 0), _stat(_fuses, 1), _stat(_fuses, 2)])
	print("")
	print("an khi moi dat vao map : ", "OK" if _seen_hidden else "LOI")
	print("hien len khi cham     : ", "OK" if _seen_model else "LOI")
	print("chuong bi chay (den)   : ", "OK" if _seen_light else "LOI")
	print("chuong bi chay (lua)   : ", "OK" if _seen_sparks else "LOI")
	print("hat no                : ", "OK" if _seen_fire else "LOI")
	print("khoi tan              : ", "OK" if _seen_smoke else "LOI")
	print("den loang             : ", "OK" if _seen_flash else "LOI")
	print("am thanh              : ", "OK" if _seen_audio else "LOI")
	print("ve checkpoint         : ", "OK" if _seen_respawn else "LOI")
	print("bom bi xoa sau no     : ", "OK" if _seen_deleted else "LOI")

func _stat(a: Array[float], mode: int) -> float:
	if a.is_empty():
		return 0.0
	if mode == 0:
		var s := 0.0
		for v in a: s += v
		return s / a.size()
	if mode == 1:
		var m := 999.0
		for v in a: m = minf(m, v)
		return m
	var m := -999.0
	for v in a: m = maxf(m, v)
	return m
