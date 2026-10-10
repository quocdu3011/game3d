extends SceneTree
# Verify: moi nut khoa (5-12) phai co icon lock, nut 1-4 giu star
func _init() -> void:
	await process_frame
	var scene = load("res://scenes/ui/level_select.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("MainCard/VBox/GridContainer")
	var lock_tex = load("res://assets/UI/Icons/Icon_Small_Lock.png")
	var bad := []
	for child in grid.get_children():
		var btn := child as Button
		if btn == null or not btn.name.begins_with("BtnLvl"):
			continue
		var num: int = btn.name.trim_prefix("BtnLvl").to_int()
		var has_lock := false
		var has_star := false
		for icon in btn.get_children():
			var tr := icon as TextureRect
			if tr != null and tr.texture != null:
				if tr.texture == lock_tex:
					has_lock = true
				elif tr.texture.resource_path.ends_with("Star.png"):
					has_star = true
		if num <= 4 and has_star and not has_lock:
			print("OK %s: star" % btn.name)
		elif num > 4 and has_lock and not has_star:
			print("OK %s: lock" % btn.name)
		else:
			bad.append("%s (lock=%s star=%s)" % [btn.name, has_lock, has_star])

	if bad.is_empty():
		print("TEST_PASS: tat ca 12 nut dung icon")
		quit(0)
	else:
		printerr("TEST_FAIL: ", ", ".join(bad))
		quit(1)
