@tool
extends McpTestSuite

func suite_name() -> String:
	return "project_structure"

func test_pause_controls_are_nested_under_overlay() -> void:
	var hud_scene := load("res://scenes/ui/hud.tscn") as PackedScene
	assert_true(hud_scene != null, "HUD scene must load")
	var hud := hud_scene.instantiate()
	track(hud)
	var overlay := hud.get_node_or_null("PauseOverlay")
	assert_true(overlay != null, "PauseOverlay must exist")
	assert_true(overlay.get_node_or_null("PausePanel/PauseMenuContainer") != null, "Pause menu must be inside overlay")
	assert_true(overlay.get_node_or_null("PausePanel/PauseMenuContainer/BtnResume") != null, "Resume button must be inside pause menu")
	assert_true(overlay.get_node_or_null("PausePanel/PauseMenuContainer/BtnRestart") != null, "Restart button must be inside pause menu")
	assert_true(overlay.get_node_or_null("PausePanel/PauseMenuContainer/BtnMainMenu") != null, "Main menu button must be inside pause menu")

func test_all_levels_have_runtime_course_hooks() -> void:
	for level_num in range(1, 5):
		var path := "res://scenes/maps/level_%d.tscn" % level_num
		var scene := load(path) as PackedScene
		assert_true(scene != null, "%s must load" % path)
		var root := scene.instantiate()
		track(root)
		assert_true(root.get_script() != null, "%s must have a level controller" % path)
		assert_eq(root.get_script().resource_path, "res://scripts/level_controller.gd", "%s must use the shared level controller" % path)

func test_level_catalog_has_four_existing_scenes() -> void:
	assert_eq(GameManager.LEVELS.size(), 4, "Exactly four playable levels are configured")
	for level_num in range(1, 5):
		assert_true(ResourceLoader.exists(GameManager.LEVELS[level_num]), "Configured level path must exist")
