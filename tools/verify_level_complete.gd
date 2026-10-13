extends SceneTree

## Kiem chung nut "man tiep theo" o man hoan thanh.
##
## Phan hinh anh/hanh vi phai chay thay vi editor: `hud.gd` khong phai `@tool`
## nen `_ready()` va `show_level_complete()` khong chay duoc trong editor.
##
## Kiem tra ca hinh thuc (nut nen trong panel) va hành vi thật (bấm nút có sang
## đúng màn kế tiếp không).

const TMP_SAVE := "user://__verify_level_complete.cfg"

var _step := 0
var _live: Node
var _gm_saved_path := ""
var _hud: CanvasLayer
var _bad := 0

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	match _step:
		0:
			_step = 1
			_live = root.get_node("GameManager")
			_gm_saved_path = _live.save_path
			_live.save_path = TMP_SAVE
			_hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
			root.add_child(_hud)
			return false
		1:
			if int(Engine.get_process_frames()) < 5:
				return false
			_step = 2
			_report_layout()
			_report_next_level_lookup()
			_report_visibility()
			_finish()
			quit(0 if _bad == 0 else 1)
			return true
	return false

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_bad += 1
	print("%-52s : %s %s" % [label, "OK" if ok else "LOI", detail])

func _report_layout() -> void:
	print("=== Man hoan thanh: bo cuc ===")
	var panel := _hud.get_node("CompleteOverlay/CompletePanel") as Control
	var replay := panel.get_node("BtnReplay") as Control
	var next_btn := panel.get_node("BtnNextLevel") as Control
	_check("co nut man tiep theo", next_btn != null)
	_check("co nut choi lai", replay != null)
	if next_btn == null or replay == null:
		return
	var box := Rect2(Vector2.ZERO, panel.size)
	_check("nut choi lai nam trong panel", box.encloses(replay.get_rect()), str(replay.get_rect()))
	_check("nut man tiep theo nam trong panel", box.encloses(next_btn.get_rect()), str(next_btn.get_rect()))
	_check("choi lai ben trai man tiep theo",
		replay.get_rect().end.x <= next_btn.get_rect().position.x,
		"(replay %s, next %s)" % [str(replay.get_rect()), str(next_btn.get_rect())])
	_check("hai nut cung hang", is_equal_approx(replay.get_rect().position.y, next_btn.get_rect().position.y))
	var art := next_btn.get_node_or_null("Art") as TextureRect
	_check("dung asset button-next-level.png",
		art != null and art.texture != null
			and art.texture.resource_path.ends_with("button-next-level.png"),
		"(%s)" % (art.texture.resource_path if art and art.texture else "?"))
	_check("nut da noi signal pressed", next_btn.pressed.get_connections().size() > 0)

func _report_next_level_lookup() -> void:
	print("")
	print("=== next_level_after ===")
	var last_level := 0
	for level_num in _live.LEVELS:
		last_level = maxi(last_level, level_num)
	for level_num in [1, 2, 3, last_level, 99]:
		var lv: int = level_num
		var expected: int = lv + 1 if lv < last_level else -1
		var got: int = _live.next_level_after(lv)
		_check("next_level_after(%d) = %d" % [level_num, expected], got == expected, "(=%d)" % got)
	_check("màn cuối là %d" % last_level, _live.next_level_after(last_level) == -1)

func _report_visibility() -> void:
	print("")
	print("=== An / hien nut ===")
	var panel := _hud.get_node("CompleteOverlay/CompletePanel")
	var next_btn := panel.get_node("BtnNextLevel") as Button
	_hud.show_level_complete(1, 2, 15.0, 3)
	_check("màn 1: có màn kế tiếp -> hiện nút", next_btn.visible)
	_check("màn 1: nút trỏ tới màn 2", _hud.get("_next_level") == 2,
		"(%s)" % _hud.get("_next_level"))

	var last_level := 0
	for level_num in _live.LEVELS:
		last_level = maxi(last_level, level_num)
	_hud.show_level_complete(last_level, 3, 10.0, 5)
	_check("màn cuối: không có màn kế tiếp -> ẩn nút", not next_btn.visible)
	_check("màn cuối: nút không trỏ màn nào", _hud.get("_next_level") == -1,
		"(%s)" % _hud.get("_next_level"))

	# Bấm nút ở màn cuối không được làm gì (không có màn để sang).
	_live.load_level(1)
	_hud.get("_on_next_level_pressed").call()
	_check("bấm nút khi không có màn kế tiếp thì không đổi màn",
		_live.current_level == 1, "(current_level = %d)" % _live.current_level)

func _finish() -> void:
	print("")
	print("=== TAT CA DUNG ===" if _bad == 0 else "=== %d LOI ===" % _bad)
	_live.save_path = _gm_saved_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))