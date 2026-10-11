extends SceneTree

## Kiem chung hien so sao tren man chon level.
## Luu Y: GameManager._ready() -> _load_progress() xoa sach level_stars roi
## nap tu dia. Phai gan du lieu gia lap SAU khi autoload san sang, va tro
## `save_path` sang file tam de khong co chay vao save that cua nguoi choi.

var _step := 0
var _scene: Control

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	if _step == 0:
		_step = 1
		var gm := root.get_node("GameManager")
		gm.save_path = "user://__verify_level_stars.cfg"
		gm.completed_levels.clear()
		gm.level_stars.clear()
		gm.level_stars[1] = 3
		gm.level_stars[2] = 2
		gm.level_stars[3] = 1
		gm.completed_levels[1] = true
		gm.completed_levels[2] = true
		gm.completed_levels[3] = true
		_scene = (load("res://scenes/ui/level_select.tscn") as PackedScene).instantiate()
		root.add_child(_scene)
		return false

	var grid := _scene.get_node_or_null("MainCard/VBox/GridContainer")
	if grid == null:
		print("KHONG TIM THAY GridContainer"); quit(1); return true

	print("=== Hien so sao tren man chon level ===")
	print("du lieu gia lap: L1=3 sao, L2=2 sao, L3=1 sao, L4 chua choi")
	print("")
	print("%-10s %8s %8s %6s %s" % ["nut", "sao vang", "sao xam", "khoa", "trang thai"])
	var gm := root.get_node("GameManager")
	var bad: Array[String] = []
	for child in grid.get_children():
		var btn := child as Button
		if btn == null or not btn.name.begins_with("BtnLvl"):
			continue
		var num: int = btn.name.trim_prefix("BtnLvl").to_int()
		var gold := 0
		var grey := 0
		var lock := false
		for icon in btn.get_children():
			var tr := icon as TextureRect
			if tr == null or tr.texture == null:
				continue
			var f: String = tr.texture.resource_path.get_file().get_basename()
			if f == "Icon_Small_Lock":
				lock = true
			elif f == "Icon_Small_Star":
				gold += 1
			elif f == "Icon_Small_StarGrey":
				grey += 1
		var expect: int = int(gm.level_stars.get(num, 0))
		var ok := gold == expect and grey == 3 - expect and not lock if num <= 4 else (lock and gold == 0 and grey == 0)
		if not ok:
			bad.append("%s (vang=%d xam=%d khoa=%s)" % [btn.name, gold, grey, lock])
		print("%-10s %8d %8d %6s %s" % [btn.name, gold, grey, lock, "OK" if ok else "SAI"])
	print("")
	if bad.is_empty():
		print("=== TAT CA 12 NUT DUNG ===")
	else:
		print("SAI: ", ", ".join(bad))
	quit(0 if bad.is_empty() else 1)
	return true
