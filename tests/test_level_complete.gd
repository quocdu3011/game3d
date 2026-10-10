@tool
extends McpTestSuite

# Hồi quy cho màn "hoàn thành màn":
#  - Quy tắc xếp sao theo thời gian hoàn thành.
#  - Panel hoàn thành có đủ thành phần và texture gắn đúng chỗ.
#  - Sao kỷ lục chỉ giữ lần tốt nhất và sống sót qua restart.

const GM_SCRIPT := "res://scripts/game_manager.gd"
const TMP_SAVE := "user://__test_complete.cfg"

var _gm: Node

func suite_name() -> String:
	return "level_complete"

func setup() -> void:
	var script: GDScript = load(GM_SCRIPT)
	_gm = script.new()
	_gm.save_path = TMP_SAVE

func teardown() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))
	if _gm != null and is_instance_valid(_gm):
		_gm.free()
	_gm = null

func test_stars_by_finish_time() -> void:
	# Màn 1: ngưỡng 3 sao = 20s, ngưỡng 2 sao = 45s.
	assert_eq(_gm.stars_for_time(1, 5.0), 3, "Rất nhanh -> 3 sao")
	assert_eq(_gm.stars_for_time(1, 20.0), 3, "Đúng ngưỡng 3 sao -> 3 sao")
	assert_eq(_gm.stars_for_time(1, 30.0), 2, "Giữa hai ngưỡng -> 2 sao")
	assert_eq(_gm.stars_for_time(1, 45.0), 2, "Đúng ngưỡng 2 sao -> 2 sao")
	assert_eq(_gm.stars_for_time(1, 120.0), 1, "Chậm -> 1 sao, không bao giờ 0")

func test_unknown_level_uses_default_thresholds() -> void:
	assert_eq(_gm.stars_for_time(99, 10.0), 3, "Màn chưa đặt ngưỡng -> dùng mặc định")
	assert_eq(_gm.stars_for_time(99, 90.0), 1, "Màn chưa đặt ngưỡng, chậm -> 1 sao")

func test_best_stars_only_improves() -> void:
	_gm.reset_progress()
	_gm.record_stars(1, 2)
	assert_eq(_gm.best_stars(1), 2, "Ghi 2 sao")
	_gm.record_stars(1, 1)
	assert_eq(_gm.best_stars(1), 2, "Chơi lại chỉ 1 sao -> giữ kỷ lục 2 sao")
	_gm.record_stars(1, 3)
	assert_eq(_gm.best_stars(1), 3, "Chơi tốt hơn -> nâng lên 3 sao")
	assert_eq(_gm.total_stars(), 3, "Tổng sao lấy từ kỷ lục")

func test_stars_and_wallet_survive_reload() -> void:
	_gm.reset_progress()
	_gm.mark_level_completed(1)
	_gm.record_stars(1, 3)
	_gm.coins = 120
	_gm.gems = 7
	_gm._save_progress()

	var reloaded: Node = load(GM_SCRIPT).new()
	reloaded.save_path = TMP_SAVE
	reloaded._load_progress()
	assert_eq(reloaded.best_stars(1), 3, "Sao phai con sau khi nap lai")
	assert_true(reloaded.is_level_completed(1), "Màn 1 van con hoan thanh")
	assert_eq(reloaded.coins, 120, "Coin phai con sau khi nap lai")
	assert_eq(reloaded.gems, 7, "Gem phai con sau khi nap lai")
	reloaded.free()

func test_reset_clears_stars_and_wallet() -> void:
	_gm.record_stars(1, 3)
	_gm.coins = 50
	_gm.gems = 2
	_gm.reset_progress()
	assert_eq(_gm.best_stars(1), 0, "Xoa tien do -> khong con sao")
	assert_eq(_gm.coins, 0, "Xoa tien do -> coin ve 0")
	assert_eq(_gm.gems, 0, "Xoa tien do -> gem ve 0")

func test_completion_panel_has_all_parts() -> void:
	var scene := load("res://scenes/ui/hud.tscn") as PackedScene
	assert_true(scene != null, "HUD scene must load")
	if scene == null:
		return
	var hud := scene.instantiate()
	track(hud)

	var panel := hud.get_node_or_null("CompleteOverlay/CompletePanel")
	assert_true(panel != null, "CompletePanel phai ton tai")
	if panel == null:
		return

	var stars := panel.get_node_or_null("StarsRow")
	assert_true(stars != null, "StarsRow phai ton tai")
	if stars != null:
		assert_eq(stars.get_child_count(), 3, "Phai co dung 3 ngoi sao")

	assert_true(panel.get_node_or_null("BannerComplete") != null, "Banner hoan thanh")
	assert_true(panel.get_node_or_null("BtnReplay/Art") != null, "Nut choi lai + art")
	assert_true(panel.get_node_or_null("BtnCloseDone/Art") != null, "Nut X + art")
	assert_true(panel.get_node_or_null("StatsRow/CoinBadge/Row/Icon") != null, "Badge coin")
	assert_true(panel.get_node_or_null("StatsRow/GemBadge/Row/Icon") != null, "Badge gem")
	assert_true(panel.get_node_or_null("StatsRow/CoinBadge/Row/Value") != null, "So coin")
	assert_true(panel.get_node_or_null("StatsRow/GemBadge/Row/Value") != null, "So gem")

	# Art phải neo kín nút (dùng cùng kích thước) để không bị méo khi kéo.
	var replay_art := panel.get_node_or_null("BtnReplay/Art") as TextureRect
	var replay_btn := panel.get_node_or_null("BtnReplay") as Control
	if replay_art != null and replay_btn != null:
		assert_eq(replay_art.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
			"Art nut choi lai phai giu ti le")

func test_center_star_is_large_and_sides_are_small() -> void:
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	track(hud)
	var row := hud.get_node_or_null("CompleteOverlay/CompletePanel/StarsRow")
	assert_true(row != null, "StarsRow phai ton tai")
	if row == null:
		return
	var kids := row.get_children()
	assert_eq(kids.size(), 3, "Phai co 3 ngoi sao")
	if kids.size() != 3:
		return

	# So sanh custom_minimum_size: khi instantiate ngoài cây thì size vẫn là 0
	# (chưa có layout), nhưng kích thước tối thiểu mới là yêu cầu thiết kế.
	var side := kids[0] as Control
	var center := kids[1] as Control
	var side2 := kids[2] as Control
	assert_gt(center.custom_minimum_size.x, side.custom_minimum_size.x,
		"Sao giua phai lon hon hai sao ben")
	assert_gt(center.custom_minimum_size.y, side.custom_minimum_size.y,
		"Sao giua phai cao hon hai sao ben")
	assert_eq(side.custom_minimum_size.x, side2.custom_minimum_size.x,
		"Hai sao ben phai cung kich thuoc")

	# Nen mo phai nam sau cum sao va it mo hon (mờ).
	var panel := hud.get_node_or_null("CompleteOverlay/CompletePanel")
	var back := panel.get_node_or_null("StarsBack") as TextureRect
	assert_true(back != null, "Phai co nen StarsBack sau 3 sao")
	if back != null:
		assert_true(back.modulate.a < 1.0, "Nen phai mo (alpha < 1)")
		assert_eq(back.get_index() < row.get_parent().get_children().find(row), true,
			"Nen phai ve truoc StarsRow de khong che sao")

func test_badges_have_real_size() -> void:
	# Panel khong tu lay kich thuoc toi thieu tu stylebox -> se gon 0x0.
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	track(hud)
	for badge_name in ["CoinBadge", "GemBadge"]:
		var badge := hud.get_node_or_null("CompleteOverlay/CompletePanel/StatsRow/" + badge_name)
		assert_true(badge != null, "Thieu badge " + badge_name)
		if badge != null:
			var panel := badge as Control
			assert_gt(panel.custom_minimum_size.x, 0.0,
				badge_name + " phai co kich thuoc toi thieu tường minh")