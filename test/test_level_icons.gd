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
				var path: String = tr.texture.resource_path
				if tr.texture == lock_tex or path.get_file() == "LockIcon.png":
					has_lock = true
				# Sao da kiem: hoac vang `Icon_Small_Star.png`, hoac xam
				# `Icon_Small_StarGrey.png` cho nhung man chua co sao nao.
				elif path.ends_with("Star.png") or path.ends_with("StarGrey.png"):
					has_star = true
		# Màn <= 4 KHÔNG phải luôn mở: `GameManager.is_level_unlocked()` mở
		# tuần tự, nên màn 4 vẫn khoá nếu màn 3 chưa hoàn thành. Vì vậy kết
		# luận đúng là: có khoá thì KHÔNG được có sao, và ngược lại.
		if has_lock and not has_star:
			print("OK %s: lock" % btn.name)
		elif has_star and not has_lock:
			print("OK %s: star" % btn.name)
		else:
			bad.append("%s (lock=%s star=%s)" % [btn.name, has_lock, has_star])

	if bad.is_empty():
		print("TEST_PASS: tat ca 12 nut dung icon")
		quit(0)
	else:
		printerr("TEST_FAIL: ", ", ".join(bad))
		quit(1)
