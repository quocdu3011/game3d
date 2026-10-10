extends Node

# Quản lý trạng thái toàn cục của game
enum GameMode { OFFLINE, ONLINE_HOST, ONLINE_CLIENT }
enum CameraMode { THIRD_PERSON, FIRST_PERSON }

signal camera_mode_changed(mode: CameraMode)

var current_mode: GameMode = GameMode.OFFLINE
var camera_mode: CameraMode = CameraMode.THIRD_PERSON
var selected_skin: String = "gobot" # "gobot", "gdbot", "sophia"
var current_level: int = 1
var completed_levels: Dictionary = {}

## Đường dẫn file lưu. Để là `var` (không phải `const`) để test trỏ vào
## file tạm thay vì ghi đè save thật của người chơi.
var save_path: String = "user://parkour_rush.cfg"

const SKINS = {
	"gobot": "res://addons/character/gdquest_gobot/gobot_skin.tscn",
	"gdbot": "res://addons/character/gdquest_gdbot/gdbot_skin.tscn",
	"sophia": "res://addons/character/gdquest_sophia/sophia_skin.tscn"
}

const LEVELS = {
	1: "res://scenes/maps/level_1.tscn",
	2: "res://scenes/maps/level_2.tscn",
	3: "res://scenes/maps/level_3.tscn",
	4: "res://scenes/maps/level_4.tscn"
}

func _ready() -> void:
	_load_progress()

## Ngưỡng xếp sao theo thời gian hoàn thành (giây), từng màn:
## [ngưỡng 3 sao, ngưỡng 2 sao]. Dưới ngưỡng đầu -> 3 sao, dưới ngưỡng sau
## -> 2 sao, chậm hơn -> 1 sao. Mán chưa có số riêng thì dùng [30, 60].
## Cần chỉnh lại sau khi chơi thử thật để độ khó khớp với người chơi.
const STAR_TIMES: Dictionary = {
	1: [20.0, 45.0],
	2: [25.0, 55.0],
	3: [25.0, 55.0],
	4: [30.0, 65.0],
}

## level -> số sao tốt nhất từng đạt được.
var level_stars: Dictionary = {}
## Bộ đếm tiền tệ. Chưa có màn nào rơi coin/gem nên vẫn là 0 cho tới khi
## thêm vật phẩm thu thập; hiện tại chỉ để màn hoàn thành có chỗ hiển thị.
var coins: int = 0
var gems: int = 0

## 3 sao nếu nhanh hơn ngưỡng đầu, 2 sao nếu nhanh hơn ngưỡng sau, còn lại 1.
func stars_for_time(level_num: int, seconds: float) -> int:
	var thresholds: Array = STAR_TIMES.get(level_num, [30.0, 60.0])
	if seconds <= float(thresholds[0]):
		return 3
	if seconds <= float(thresholds[1]):
		return 2
	return 1

## Ghi lại kỷ lục sao của màn (chỉ giữ lần tốt nhất) rồi lưu.
func record_stars(level_num: int, stars: int) -> void:
	var best: int = int(level_stars.get(level_num, 0))
	if stars <= best:
		return
	level_stars[level_num] = stars
	_save_progress()

func best_stars(level_num: int) -> int:
	return int(level_stars.get(level_num, 0))

func total_stars() -> int:
	var sum := 0
	for level_num in level_stars:
		sum += int(level_stars[level_num])
	return sum

## Nạp tiến trình từ đĩa. File hỏng/thiếu -> bắt đầu từ đầu, không được làm
## game crash lúc khởi động.
func _load_progress() -> void:
	completed_levels.clear()
	level_stars.clear()
	coins = 0
	gems = 0
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	for level_num in LEVELS:
		if config.get_value("progress", str(level_num), false):
			completed_levels[level_num] = true
		var stars := int(config.get_value("stars", str(level_num), 0))
		if stars > 0:
			level_stars[level_num] = stars
	coins = int(config.get_value("wallet", "coins", 0))
	gems = int(config.get_value("wallet", "gems", 0))
	camera_mode = clampi(int(config.get_value("settings", "camera_mode", CameraMode.THIRD_PERSON)), CameraMode.THIRD_PERSON, CameraMode.FIRST_PERSON) as CameraMode

func _save_progress() -> void:
	var config := ConfigFile.new()
	for level_num in completed_levels:
		config.set_value("progress", str(level_num), true)
	for level_num in level_stars:
		config.set_value("stars", str(level_num), int(level_stars[level_num]))
	config.set_value("wallet", "coins", coins)
	config.set_value("wallet", "gems", gems)
	config.set_value("settings", "camera_mode", int(camera_mode))
	var err := config.save(save_path)
	if err != OK:
		push_error("Khong luu duoc tien do vao %s (loi %d)" % [save_path, err])

## Ghi đè toàn bộ tiến trình. Dùng cho test và nút "chơi lại từ đầu".
func reset_progress() -> void:
	completed_levels.clear()
	level_stars.clear()
	coins = 0
	gems = 0
	_save_progress()

## Số level đã hoàn thành — nguồn sự thật cho thanh tiến trình.
func completed_count() -> int:
	return completed_levels.size()

## Level kế tiếp chưa chơi, hoặc -1 nếu đã clear hết.
func next_unfinished_level() -> int:
	for level_num in LEVELS:
		if not is_level_completed(level_num):
			return level_num
	return -1

## Mở khoá tuần tự: level đầu tiên luôn mở, level sau chỉ mở khi level
## liền trước đã hoàn thành. Level không tồn tại thì không bao giờ mở.
func is_level_unlocked(level_num: int) -> bool:
	if not LEVELS.has(level_num):
		return false
	var ordered := _ordered_levels()
	var index: int = ordered.find(level_num)
	if index <= 0:
		return true
	return is_level_completed(ordered[index - 1])

## Danh sách level theo thứ tự tăng dần, độc lập với thứ tự khai báo.
func _ordered_levels() -> Array:
	var keys: Array = LEVELS.keys()
	keys.sort()
	return keys

func set_camera_mode(mode: int) -> void:
	var next_mode: CameraMode = clampi(mode, CameraMode.THIRD_PERSON, CameraMode.FIRST_PERSON) as CameraMode
	if camera_mode == next_mode:
		return
	camera_mode = next_mode
	_save_progress()
	camera_mode_changed.emit(camera_mode)

func get_skin_path(skin_name: String = "") -> String:
	var name_to_use = skin_name if skin_name != "" else selected_skin
	return SKINS.get(name_to_use, SKINS["gobot"])

func get_level_path(level_num: int = -1) -> String:
	var num_to_use = level_num if level_num > 0 else current_level
	return LEVELS.get(num_to_use, LEVELS[1])

func load_level(level_num: int) -> void:
	if not LEVELS.has(level_num):
		return
	current_level = level_num
	var path = get_level_path(level_num)
	get_tree().change_scene_to_file(path)

func mark_level_completed(level_num: int) -> void:
	if not LEVELS.has(level_num):
		return
	completed_levels[level_num] = true
	_save_progress()

func is_level_completed(level_num: int) -> bool:
	return completed_levels.get(level_num, false)
