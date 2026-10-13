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
	_gm._save_progress()

	var reloaded: Node = load(GM_SCRIPT).new()
	reloaded.save_path = TMP_SAVE
	reloaded._load_progress()
	assert_eq(reloaded.best_stars(1), 3, "Sao phai con sau khi nap lai")
	assert_true(reloaded.is_level_completed(1), "Màn 1 van con hoan thanh")
	assert_eq(reloaded.coins, 120, "Coin phai con sau khi nap lai")
	reloaded.free()

func test_reset_clears_stars_and_wallet() -> void:
	_gm.record_stars(1, 3)
	_gm.coins = 50
	_gm.reset_progress()
	assert_eq(_gm.best_stars(1), 0, "Xoa tien do -> khong con sao")
	assert_eq(_gm.coins, 0, "Xoa tien do -> coin ve 0")

func test_level_starts_at_zero_and_banks_on_finish() -> void:
	_gm.reset_progress()
	# Ví có sẵn 100 coin từ màn trước -> màn mới phải bắt đầu từ 0.
	_gm.coins = 100
	_gm.reset_level_coins()
	assert_eq(_gm.level_coins, 0, "Dau man phai bat dau tu 0")
	_gm.add_coins(1)
	_gm.add_coins(2)
	assert_eq(_gm.level_coins, 3, "Nhet 3 dong -> dem 3 trong man")
	assert_eq(_gm.coins, 100, "Chua xong man -> vi khong doi")

	# Hoan thanh man: coin cua man cong vao vi, bo dem ve 0.
	var banked: int = _gm.bank_level_coins()
	assert_eq(banked, 3, "Nop 3 coin")
	assert_eq(_gm.coins, 103, "Coin cua man cong vao vi hien co")
	assert_eq(_gm.level_coins, 0, "Sau khi nop, bo dem ve 0")

func test_bank_survives_reload_and_reset_clears_it() -> void:
	_gm.reset_progress()
	_gm.add_coins(5)
	_gm.bank_level_coins()

	var reloaded: Node = load(GM_SCRIPT).new()
	reloaded.save_path = TMP_SAVE
	reloaded._load_progress()
	assert_eq(reloaded.coins, 5, "Coin da nop phai con sau khi nap lai")
	assert_eq(reloaded.level_coins, 0, "Nap lai khong mang theo bo dem trong man")
	reloaded.free()

	_gm.reset_progress()
	assert_eq(_gm.level_coins, 0, "Xoa tien do -> bo dem trong man ve 0")

func test_spend_coins_respects_wallet() -> void:
	_gm.reset_progress()
	_gm.coins = 30
	assert_false(_gm.spend_coins(50), "Thieu coin -> khong tru")
	assert_eq(_gm.coins, 30, "Thieu coin -> vi giu nguyen")
	assert_true(_gm.spend_coins(20), "Du coin -> tru thanh cong")
	assert_eq(_gm.coins, 10, "Tru dung so da")

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
	assert_true(panel.get_node_or_null("StatsRow/CoinBadge/Row/Value") != null, "So coin")
	# Da bo hoan toan gem khoi man hoan thanh, chi con coin.
	assert_true(panel.get_node_or_null("StatsRow/GemBadge") == null, "Khong con badge gem")
	assert_true(hud.get_node_or_null("TopContainer/CoinBox/Value") != null, "Bo dem coin tren HUD")

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

func test_complete_panel_buttons_sit_side_by_side_inside_panel() -> void:
	# Hồi quy bố cục: nút "Chơi lại" bên trái, nút "màn tiếp theo" bên phải, cả
	# hai cùng nằm TRONG panel. Trước đây offset của chúng được tính theo tâm
	# panel (anchors_preset = 8) rồi đổi sang neo góc mà quên đổi công thức, khiến
	# nút chơi lại trôi ra ngoài panel.
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	track(hud)
	var panel := hud.get_node_or_null("CompleteOverlay/CompletePanel") as Control
	var replay := panel.get_node_or_null("BtnReplay") as Control
	var next_btn := panel.get_node_or_null("BtnNextLevel") as Control
	assert_ne(next_btn, null, "Phai co nut sang man tiep theo")
	if replay == null or next_btn == null:
		return

	# `panel.get_rect()` trả về rect so với CHA (overlay), còn rect của nút là so
	# với panel — nên phải so với `Rect2(Vector2.ZERO, panel.size)`.
	var panel_box := Rect2(Vector2.ZERO, panel.size)
	for entry in [["BtnReplay", replay], ["BtnNextLevel", next_btn]]:
		var r: Rect2 = (entry[1] as Control).get_rect()
		assert_true(panel_box.encloses(r),
			"%s phai nam trong panel (nut %s, panel 0..%s)" % [entry[0], str(r), str(panel.size)])

	assert_true(replay.get_rect().end.x <= next_btn.get_rect().position.x,
		"Nut choi lai phai ben trai nut man tiep theo")
	assert_eq(replay.get_rect().position.y, next_btn.get_rect().position.y,
		"Hai nut phai cung hang")

	# Nút màn tiếp theo phải dùng đúng asset yêu cầu.
	var art := next_btn.get_node_or_null("Art") as TextureRect
	assert_ne(art, null, "Nut man tiep theo phai co art")
	if art != null:
		assert_eq(art.texture.resource_path,
			"res://assets/UI/ButtonsText/button-next-level.png", "Dung asset nut man tiep theo")
		assert_eq(art.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
			"Art nut man tiep theo phai giu ti le")

# `show_level_complete()` nằm trong `hud.gd` — script này không phải @tool nên
	# không chạy được trong ngữ cảnh editor. Hành vi ẩn/hiện nút và việc bấm
	# nút có sang màn thật không được kiểm ở
	# `tools/verify_level_complete.gd` (chạy thật nên gọi được script).

func test_badges_have_real_size() -> void:
	# Panel khong tu lay kich thuoc toi thieu tu stylebox -> se gon 0x0.
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	track(hud)
	for badge_name in ["CoinBadge"]:
		var badge := hud.get_node_or_null("CompleteOverlay/CompletePanel/StatsRow/" + badge_name)
		assert_true(badge != null, "Thieu badge " + badge_name)
		if badge != null:
			var panel := badge as Control
			assert_gt(panel.custom_minimum_size.x, 0.0,
				badge_name + " phai co kich thuoc toi thieu tường minh")