@tool
extends McpTestSuite

# Hồi quy cho 2 lỗi đã tìm thấy:
#  1. completed_levels chỉ nằm trong RAM -> tắt game là mất sạch.
#  2. ProgressBar lấy LEVELS.size() làm tử số -> luôn hiện 4/12.
#
# Không dùng bản sao autoload `GameManager`: trong ngữ cảnh editor, autoload
# là placeholder nên không gọi được method của script. Test tự tạo instance
# và trỏ save_path sang file tạm để không đụng save thật của người chơi.

const TMP_SAVE := "user://__test_progress.cfg"
const GM_SCRIPT := "res://scripts/game_manager.gd"

var _gm: Node

func suite_name() -> String:
	return "progress_persistence"

func suite_setup(_ctx: Dictionary) -> void:
	_gm = _new_manager()
	_gm.save_path = TMP_SAVE

func suite_teardown() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))
	_free_manager(_gm)
	_gm = null

## Instance GameManager độc lập, tách khỏi cây editor.
func _new_manager() -> Node:
	var script: GDScript = load(GM_SCRIPT)
	var node: Node = script.new()
	return node

func _free_manager(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.free()

func test_completion_survives_a_reload() -> void:
	_gm.reset_progress()
	assert_eq(_gm.completed_count(), 0, "Save moi bat dau o 0 level")

	_gm.mark_level_completed(2)
	_gm.mark_level_completed(4)
	assert_eq(_gm.completed_count(), 2, "Hai level da choi xong")

	# Mô phỏng tắt/mở lại game: instance mới chỉ có dữ liệu từ đĩa.
	var reloaded: Node = _new_manager()
	reloaded.save_path = TMP_SAVE
	reloaded._load_progress()

	assert_true(reloaded.is_level_completed(2), "Level 2 phai con sau khi nap lai")
	assert_true(reloaded.is_level_completed(4), "Level 4 phai con sau khi nap lai")
	assert_eq(reloaded.completed_count(), 2, "Tien do phai khoi phuc day du")
	_free_manager(reloaded)

func test_progress_bar_counts_completions_not_existing_levels() -> void:
	# Đối chiếu nguyên văn với _update_progress() trong level_select.gd.
	_gm.reset_progress()
	assert_eq(_gm.completed_count(), 0, "Save moi: thanh tiến trinh phai 0, khong phai 4")
	assert_eq(maxi(_gm.LEVELS.size(), 1), 4, "Mau so la so level choi duoc")

	_gm.mark_level_completed(1)
	assert_eq(_gm.completed_count(), 1, "Tu so tang theo level DA CHOI XONG")

func test_unknown_level_is_not_recorded() -> void:
	_gm.reset_progress()
	_gm.mark_level_completed(99)
	assert_eq(_gm.completed_count(), 0, "Level 99 khong ton tai -> khong ghi")
	assert_false(_gm.is_level_completed(99), "Level 99 khong bao gio hoan thanh")

func test_corrupt_save_does_not_crash() -> void:
	var f := FileAccess.open(TMP_SAVE, FileAccess.WRITE)
	f.store_string("day la rac khong phai config file hop le[[[")
	f.close()

	_gm._load_progress()
	assert_eq(_gm.completed_count(), 0, "File hong -> tien trinh rong, khong crash")

func test_next_unfinished_level_tracks_progress() -> void:
	_gm.reset_progress()
	assert_eq(_gm.next_unfinished_level(), 1, "Chua choi gi -> level 1")

	_gm.mark_level_completed(1)
	_gm.mark_level_completed(2)
	assert_eq(_gm.next_unfinished_level(), 3, "Qua 1-2 -> level 3")

	_gm.mark_level_completed(3)
	_gm.mark_level_completed(4)
	assert_eq(_gm.next_unfinished_level(), -1, "Clear het -> -1")


func test_levels_unlock_sequentially() -> void:
	_gm.reset_progress()
	assert_true(_gm.is_level_unlocked(1), "Level 1 luôn mở khoá")
	assert_false(_gm.is_level_unlocked(2), "Level 2 khoá khi chưa xong màn 1")
	assert_false(_gm.is_level_unlocked(3), "Level 3 khoá khi chưa xong màn 2")
	assert_false(_gm.is_level_unlocked(4), "Level 4 khoá khi chưa xong màn 3")

	_gm.mark_level_completed(1)
	assert_true(_gm.is_level_unlocked(2), "Xong màn 1 -> mở màn 2")
	assert_false(_gm.is_level_unlocked(3), "Màn 3 vẫn khoá sau khi xong màn 1")

	_gm.mark_level_completed(2)
	assert_true(_gm.is_level_unlocked(3), "Xong màn 2 -> mở màn 3")

	_gm.mark_level_completed(3)
	assert_true(_gm.is_level_unlocked(4), "Xong màn 3 -> mở màn 4")

func test_unfinished_level_is_always_unlocked() -> void:
	# Người chơi mới phải vào được màn 1 dù chưa xong màn nào.
	_gm.reset_progress()
	assert_eq(_gm.next_unfinished_level(), 1, "Màn kế tiếp là 1")
	assert_true(_gm.is_level_unlocked(_gm.next_unfinished_level()), "Màn kế tiếp phải mở")

func test_nonexistent_level_is_never_unlocked() -> void:
	# Level 99 không có trong LEVELS: khoá bất kể hoàn thành bao nhiêu màn.
	_gm.reset_progress()
	_gm.mark_level_completed(1)
	_gm.mark_level_completed(2)
	_gm.mark_level_completed(3)
	_gm.mark_level_completed(4)
	assert_false(_gm.is_level_unlocked(99), "Level 99 khong ton tai -> luon khoa")
	assert_false(_gm.is_level_unlocked(5), "Level 5 chua lam -> luon khoa")

func test_unlock_state_survives_a_reload() -> void:
	_gm.reset_progress()
	_gm.mark_level_completed(1)

	var reloaded: Node = _new_manager()
	reloaded.save_path = TMP_SAVE
	reloaded._load_progress()
	assert_true(reloaded.is_level_completed(1), "Màn 1 xong phai con sau khi nap lai")
	assert_true(reloaded.is_level_unlocked(2), "Mở khoá màn 2 phai con sau khi nap lai")
	assert_false(reloaded.is_level_unlocked(3), "Màn 3 phai van khoá sau khi nap lai")
	_free_manager(reloaded)
