extends SceneTree

## Kiem chung tien te: nhac coin cong vao GameManager, HUD cap nhat, luu dia,
## coin bien mat. Cung kiem tra gem da duoc go khoi man hoan thanh.

var _gm: Node
var _step := 0
var _hud: CanvasLayer
var _coins: Array[Node3D] = []
var _player: CharacterBody3D
var _coin_before := 0
## Cac vi tri player se di qua, dung kiem chung 3 dong.
var _ROUTE: Array[Vector3] = [Vector3(-3.0, 1.2, 0), Vector3(0.0, 1.2, 0), Vector3(3.0, 1.2, 0), Vector3(9.0, 1.2, 0)]
var _route := 0
var _next_phys := 0
var _log: Array[String] = []
var _bad := 0

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	match _step:
		0:
			_step = 1
			_gm = root.get_node("GameManager")
			_gm.save_path = "user://__verify_coin.cfg"   # khong cham save that
			_gm.coins = 0
			_hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
			root.add_child(_hud)
			var floor_b := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(40, 1, 40)
			cs.shape = bx
			cs.position = Vector3(0, -0.5, 0)
			floor_b.add_child(cs)
			root.add_child(floor_b)
			for i in range(3):
				var c := (load("res://scenes/Entity/Item/coin.tscn") as PackedScene).instantiate() as Node3D
				c.position = Vector3(float(i) * 3.0 - 3.0, 1.0, 0)
				root.add_child(c)
				_coins.append(c)
			_player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
			root.add_child(_player)
			_coin_before = _gm.coins
			return false

		1:
			# Cho scene vua dung xong `_ready()` chay het truoc khi di.
			if int(Engine.get_physics_frames()) < 6:
				return false
			_step = 2
			_route = 0
			return false

		2:
			# Di qua tung dong, DUNG it nhat 12 khung VAT LY o moi vi tri.
			# Phai cho qua `Engine.get_physics_frames()` TRUOC khi teleport
			# lan sau, neu khong ca 3 lan teleport chay lien tiep trong mot
			# khung va player khong bao gio co mat trong vung cua dong nao.
			if int(Engine.get_physics_frames()) < _next_phys:
				return false
			if _route < _ROUTE.size():
				_player.global_position = _ROUTE[_route]
				_route += 1
				_next_phys = int(Engine.get_physics_frames()) + 12
				return false
			# Dong cuoi vua nhet chua kip bay xong (`collect_time` 0.35s
			# roi moi `queue_free()`) — cho no chay het truoc khi ket luan.
			_step = 3
			_next_phys = int(Engine.get_physics_frames()) + 40
			return false
		3:
			if int(Engine.get_physics_frames()) < _next_phys:
				return false
			_report()
			quit(0 if _bad == 0 else 1)
			return true
	return false

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok: _bad += 1
	print("%-34s : %s %s" % [label, "OK" if ok else "LOI", detail])

func _report() -> void:
	print("=== Kiem chung tien te ===")
	var got: int = int(_gm.coins) - _coin_before
	_check("nac 3 dong", got == 3, "(nhan %d)" % got)
	var lbl := _hud.get_node_or_null("TopContainer/CoinBox/Value") as Label
	_check("bo dem tren HUD", lbl != null and lbl.text == str(_gm.coins),
		"(HUD=\"%s\", GameManager=%d)" % [lbl.text if lbl else "?", _gm.coins])
	var cfg := ConfigFile.new()
	_check("da luu xuong dia", cfg.load("user://__verify_coin.cfg") == OK
		and int(cfg.get_value("wallet", "coins", -1)) == _gm.coins,
		"(file=%d)" % int(cfg.get_value("wallet", "coins", -1)))
	var alive := 0
	for c in _coins:
		if is_instance_valid(c): alive += 1
	_check("ca 3 dong da bien mat", alive == 0, "(con %d)" % alive)
	print("")
	print("--- man hoan thanh ---")
	var gem := _hud.get_node_or_null("CompleteOverlay/CompletePanel/StatsRow/GemBadge")
	_check("GemBadge da go khoi scene", gem == null)
	var coin_badge := _hud.get_node_or_null("CompleteOverlay/CompletePanel/StatsRow/CoinBadge")
	_check("CoinBadge con lai", coin_badge != null)
	var complete_lbl := _hud.get_node_or_null("CompleteOverlay/CompletePanel/StatsRow/CoinBadge/Row/Value") as Label
	_check("nhan coin tren man hoan thanh", complete_lbl != null and complete_lbl.text == str(_gm.coins),
		"(\"%s\")" % (complete_lbl.text if complete_lbl else "?"))
	print("")
	print("=== TAT CA DUNG ===" if _bad == 0 else "=== %d LOI ===" % _bad)
