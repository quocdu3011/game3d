extends SceneTree
# Test runtime UI level_select: nút 1-4 có sự kiện, nút 5-12 bị khóa
# godot --headless -s test/test_level_select.gd

func _init() -> void:
	await process_frame
	var scene = load("res://scenes/ui/level_select.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("MainCard/VBox/GridContainer")
	var wired := []
	var locked := []
	for child in grid.get_children():
		var btn := child as Button
		if btn != null and btn.name.begins_with("BtnLvl"):
			var num: int = btn.name.trim_prefix("BtnLvl").to_int()
			var conns: int = btn.pressed.get_connections().size()
			if num <= 4:
				if conns > 0 and not btn.disabled:
					wired.append(btn.name)
				else:
					printerr("TEST_FAIL: %s phai co su kien va khong bi khoa (conns=%d disabled=%s)" % [btn.name, conns, btn.disabled])
					quit(1)
					return
			else:
				if btn.disabled and conns == 0:
					locked.append(btn.name)
				else:
					printerr("TEST_FAIL: %s phai bi khoa (conns=%d disabled=%s)" % [btn.name, conns, btn.disabled])
					quit(1)
					return

	print("TEST_WIRED=", ",".join(wired))
	print("TEST_LOCKED=", ",".join(locked))
	var progress: ProgressBar = scene.get_node("MainCard/VBox/BottomContainer/ProgressBar")
	print("TEST_PROGRESS value=", progress.value, " max=", progress.max_value)
	if progress.value == 4 and progress.max_value == 12:
		print("TEST_PASS")
		quit(0)
	else:
		printerr("TEST_FAIL: progress bar sai")
		quit(1)
