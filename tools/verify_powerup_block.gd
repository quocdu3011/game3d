extends SceneTree

## Kiem chung 3 powerup block: tao player that, cho roi xuong block, do DONG
## cao bay thuc te trong _physics_process va so sanh voi launch_height.
##
##   godot --headless --path . -s res://tools/verify_powerup_block.gd

var _steps: Array = []
var _i := 0
var _probe: Node = null
var _player: CharacterBody3D
var _peak := -999.0
var _vmax := 0.0
var _settle := 0
var _expected := 0.0
var _launch_speed_seen := 0.0
var _failures := 0

class Probe extends Node:
	var target: Node3D
	var peak := -999.0
	var vmax := 0.0
	var launched := false
	var launch_v := 0.0
	var ticks := 0
	func _physics_process(_d: float) -> void:
		ticks += 1
		if target == null or not is_instance_valid(target):
			return
		var y := target.global_position.y
		if y > peak:
			peak = y
		var v: float = (target as CharacterBody3D).velocity.y
		if v > vmax:
			vmax = v
		if not launched and v > 1.0:
			launched = true
			launch_v = v

func _initialize() -> void:
	for f in ["Powerup_block_1", "Powerup_block_2", "Powerup_block_3"]:
		var ps := load("res://scenes/Entity/Tile/%s.tscn" % f) as PackedScene
		if ps == null:
			_steps.append({"ten": f, "loi": "KHONG LOAD DUOC"}); continue
		_steps.append({"ten": f, "scene": ps})

func _process(_d: float) -> bool:
	if _i >= _steps.size():
		for l in _lines: print(l)
		print("")
		print("=== Ket qua ===")
		print("TAT CA KHOP" if _failures == 0 else "%d/3 KHONG KHOP" % _failures)
		quit(0 if _failures == 0 else 1); return true
	var st: Dictionary = _steps[_i]

	if _settle == 0:
		if st.has("loi"):
			_lines.append("%-18s %s" % [st["ten"], st["loi"]]); _failures += 1; _i += 1; return false
		_player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
		_player.position = Vector3(0, 4.0, 0)
		root.add_child(_player)
		var blk: Node3D = (st["scene"] as PackedScene).instantiate()
		root.add_child(blk)
		_expected = blk.launch_height
		_probe = Probe.new()
		_probe.target = _player
		root.add_child(_probe)
		_settle = 1
		return false

	# Dem theo TIC VAT LY, khong theo frame render: trong headless hai thang
	# khong cung nhip va bay cao can ~1.4 giay moi toi dinh.
	if _probe != null and (_probe as Probe).ticks < 260:
		return false

	var actual: float = (_probe as Probe).peak - 1.0     # mat san nam o y=1
	var vmax: float = (_probe as Probe).vmax
	var launch_v: float = (_probe as Probe).launch_v
	var launched: bool = (_probe as Probe).launched
	var ideal := sqrt(2.0 * 9.8 * _expected)
	var ok := launched and absf(actual - _expected) < 0.4
	if not ok: _failures += 1
	_lines.append("%-18s cao=%.1f  toc do bay=%.2f (ly thuyet %.2f)  dinh thuc te=%.2f  -> %s" % [
		st["ten"], _expected, launch_v, ideal, actual, "KHOP" if ok else "LECH"])

	_probe.queue_free(); _probe = null
	_player.queue_free(); _player = null
	_settle = 0
	_i += 1
	return false

var _lines: Array[String] = []
