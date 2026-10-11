extends SceneTree
var _step := 0
var _f := 0
var _shop: Control
func _initialize() -> void: pass
func _process(_d: float) -> bool:
	if _step == 0:
		_step = 1
		var gm := root.get_node("GameManager")
		gm.save_path = "user://__dbg.cfg"
		gm.reset_progress()
		_shop = (load("res://scenes/ui/shop.tscn") as PackedScene).instantiate()
		root.add_child(_shop)
		return false
	_f += 1
	if _f < 30: return false
	var gm2 := root.get_node("GameManager")
	print("=== SKINS trong GameManager ===")
	for k in gm2.SKINS:
		print("  %-8s -> %s" % [k, gm2.SKINS[k]])
	print("")
	print("=== card nao nap model gi ===")
	for c in _shop.get_node("%CardRow").get_children():
		var want: String = str(c.skin_name)
		var path: String = gm2.get_skin_path(want)
		var kids: Array = c.get_node("%PreviewSlot").get_children()
		var mesh_names := []
		for m in kids[0].get_children():
			mesh_names.append(m.name)
		print("  card %-8s -> get_skin_path = %s" % [want, path.get_file()])
		print("       model trong o: %s  | con: %s" % [kids[0].name, str(mesh_names)])
	quit(0); return true
