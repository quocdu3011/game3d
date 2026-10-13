extends Node

# Quản lý trạng thái toàn cục của game
enum CameraMode { THIRD_PERSON, FIRST_PERSON }

signal camera_mode_changed(mode: CameraMode)

## Bắn ra khi người chơi bật/tắt chế độ điều khiển góc nhìn bằng cảm biến con quay.
signal tilt_camera_changed(enabled: bool)
## Bắn ra khi độ nhạy con quay bị kéo trong màn tuỳ chọn.
signal tilt_sensitivity_changed(value: float)

## Độ nhạy nhỏ nhất / lớn nhất mà thanh trượt trong màn tuỳ chọn cho phép.
## Khoảng này rộng có chủ đích: người chơi có thể cần xoay rất nhẹ (máy cầm
## ngang) hoặc rất mạnh (chơi bằng một tay).
const TILT_SENSITIVITY_MIN := 0.05
const TILT_SENSITIVITY_MAX := 2.0

var camera_mode: CameraMode = CameraMode.THIRD_PERSON
## Bật cảm biến con quay để xoay camera bằng cách nghiêng máy. Tắt mặc định vì
## máy tính không có cảm biến và người chơi vẫn xoay camera bằng chuột/vuốt tay.
var tilt_camera_enabled: bool = false
## Góc xoay camera (radian) cho mỗi 1 rad/s con quay báo. Người chơi chỉnh
## bằng thanh trượt trong màn tuỳ chọn; `TiltSensor` đọc giá trị này.
var tilt_sensitivity: float = 0.55
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

## Giá mua mỗi nhân vật, tính bằng coin. Nhân vật không có trong bảng này là
## miễn phí (gobot là nhân vật mặc định nên luôn sẵn có).
const SKIN_PRICES = {
	"gdbot": 50,
	"sophia": 120,
}

## Nhân vật luôn mở khoá từ đầu, không cần mua.
const DEFAULT_SKIN := "gobot"

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

## Bắn ra mỗi khi số coin trong màn đổi, để HUD cập nhật ngay khi nhặt đồng.
signal level_coins_changed(amount: int)

## Bắn ra khi ví coin đổi (mua/xoá) và khi coin vừa được nộp sau khi xong màn.
signal coins_changed(total: int)

## level -> số sao tốt nhất từng đạt được.
var level_stars: Dictionary = {}
## Bộ đếm tiền tệ trong túi người chơi, giữ qua các màn nhờ `_save_progress()`.
## Chỉ tăng khi nộp coin cuối màn (`bank_level_coins()`) hoặc giảm khi mua nhân vật.
var coins: int = 0
## Coin nhặt được trong màn đang chơi. Luôn bắt đầu từ 0 mỗi màn và chỉ được
## cộng vào ví khi `bank_level_coins()` chạy lúc hoàn thành màn — nên bỏ giữa
## màn (chết, bấm chơi lại) thì mất trắng, không mất tiền đã kiếm trước đó.
var level_coins: int = 0
## skin -> true cho mọi nhân vật đã mở khoá. Nhân vật mặc định luôn mở.
var unlocked_skins: Dictionary = {}

## Bắn ra khi ví coin đổi (mua/xoá) và khi có nhân vật mới được mở khoá.
signal purchase_result(ok: bool, skin_name: String, message: String)

## Coin nhặt được trong màn: cộng vào `level_coins`, KHÔNG đụng tới ví và
## không lưu đĩa. `coin.gd` gọi hàm này mỗi lần nhặt.
func add_coins(amount: int) -> void:
	if amount == 0:
		return
	level_coins = maxi(0, level_coins + amount)
	level_coins_changed.emit(level_coins)

## Đặt bộ đếm về 0. `level_controller` gọi lúc màn bắt đầu để số coin trên
## HUD luôn bắt đầu từ 0, không kế thừa coin của màn trước.
func reset_level_coins() -> void:
	level_coins = 0
	level_coins_changed.emit(level_coins)

## Nộp coin của màn vào ví rồi đặt bộ đếm về 0. Gọi đúng một lần lúc hoàn
## thành màn. Trả về số coin vừa nộp để màn hoàn thành hiện ra.
func bank_level_coins() -> int:
	var banked := level_coins
	level_coins = 0
	if banked > 0:
		coins += banked
		_save_progress()
		coins_changed.emit(coins)
	level_coins_changed.emit(0)
	return banked

## Trừ coin khỏi ví (mua nhân vật). Thiếu coin thì không làm gì.
func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	_save_progress()
	coins_changed.emit(coins)
	return true

func skin_price(skin_name: String) -> int:
	return int(SKIN_PRICES.get(skin_name, 0))

func is_skin_unlocked(skin_name: String) -> bool:
	if skin_name == DEFAULT_SKIN:
		return true
	return bool(unlocked_skins.get(skin_name, false))

## Trả về `true` nếu người chơi vừa mua được nhân vật đó. Đã mở khoá rồi
## thì trả `true` mà không tốn coin. Không đủ coin thì bỏ qua và bắn
## `purchase_result(false, ...)` cho UI hiện thông báo.
func unlock_skin(skin_name: String) -> bool:
	if not SKINS.has(skin_name):
		push_warning("Khong co nhan vat \"%s\" de mo khoa" % skin_name)
		return false
	if is_skin_unlocked(skin_name):
		return true

	var price := skin_price(skin_name)
	if coins < price:
		var short_by := price - coins
		var msg := "Thieu %d coin de mo khoa nhan vat nay" % short_by
		purchase_result.emit(false, skin_name, msg)
		push_warning(msg)
		return false

	spend_coins(price)
	unlocked_skins[skin_name] = true
	_save_progress()
	purchase_result.emit(true, skin_name, "Da mo khoa %s" % skin_name.capitalize())
	return true

## Chỉ đổi nhân vật đang chơi nếu nó đã mở khoá — chặn việc lách qua
## màn đổi nhân vật để dùng nhân vật chưa mua.
func select_skin(skin_name: String) -> bool:
	if not SKINS.has(skin_name) or not is_skin_unlocked(skin_name):
		return false
	selected_skin = skin_name
	_save_progress()
	return true

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
	unlocked_skins.clear()
	coins = 0
	level_coins = 0
	selected_skin = DEFAULT_SKIN
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
	# Chỉ nhận skin còn tồn tại trong SKINS để save cũ/không còn scene không
	# làm hỏng danh sách mở khoá. `get_section_keys` sẽ báo ERROR nếu section
	# chưa từng được ghi, nên phải kiểm tra trước.
	if config.has_section("unlock"):
		for skin_name in config.get_section_keys("unlock"):
			if SKINS.has(skin_name) and bool(config.get_value("unlock", skin_name, false)):
				unlocked_skins[skin_name] = true
	var saved_skin := str(config.get_value("settings", "selected_skin", DEFAULT_SKIN))
	# Skin đã lưu phải còn tồn tại và đã mở khoá, nếu không thì lùi về mặc định.
	selected_skin = saved_skin if is_skin_unlocked(saved_skin) else DEFAULT_SKIN
	camera_mode = clampi(int(config.get_value("settings", "camera_mode", CameraMode.THIRD_PERSON)), CameraMode.THIRD_PERSON, CameraMode.FIRST_PERSON) as CameraMode
	tilt_camera_enabled = bool(config.get_value("settings", "tilt_camera", false))
	# Save cũ chưa có khoá thì lấy mặc định; giá trị lưu bị hỏng cũng kẹp lại
	# trong khoảng hợp lệ để thanh trượt không nhảy về 0.
	tilt_sensitivity = clampf(float(config.get_value("settings", "tilt_sensitivity", 0.55)),
		TILT_SENSITIVITY_MIN, TILT_SENSITIVITY_MAX)

func _save_progress() -> void:
	var config := ConfigFile.new()
	for level_num in completed_levels:
		config.set_value("progress", str(level_num), true)
	for level_num in level_stars:
		config.set_value("stars", str(level_num), int(level_stars[level_num]))
	config.set_value("wallet", "coins", coins)
	for skin_name in unlocked_skins:
		if unlocked_skins[skin_name]:
			config.set_value("unlock", skin_name, true)
	config.set_value("settings", "camera_mode", int(camera_mode))
	config.set_value("settings", "tilt_camera", tilt_camera_enabled)
	config.set_value("settings", "tilt_sensitivity", tilt_sensitivity)
	config.set_value("settings", "selected_skin", selected_skin)
	var err := config.save(save_path)
	if err != OK:
		push_error("Khong luu duoc tien do vao %s (loi %d)" % [save_path, err])

## Ghi đè toàn bộ tiến trình. Dùng cho test và nút "chơi lại từ đầu".
func reset_progress() -> void:
	completed_levels.clear()
	level_stars.clear()
	unlocked_skins.clear()
	coins = 0
	level_coins = 0
	selected_skin = DEFAULT_SKIN
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

## Màn liền kề sau `level_num` trong thứ tự tăng dần, dùng cho nút "sang màn
## tiếp theo" ở màn hoàn thành. Trả -1 khi `level_num` không tồn tại hoặc đã là
## màn cuối — lúc đó UI nên ẩn nút đi.
func next_level_after(level_num: int) -> int:
	var ordered := _ordered_levels()
	var index: int = ordered.find(level_num)
	if index < 0 or index + 1 >= ordered.size():
		return -1
	return int(ordered[index + 1])

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

## Bật/tắt xoay camera bằng cảm biến con quay, lưu lại để nhớ qua các màn.
func set_tilt_camera_enabled(enabled: bool) -> void:
	if tilt_camera_enabled == enabled:
		return
	tilt_camera_enabled = enabled
	_save_progress()
	tilt_camera_changed.emit(tilt_camera_enabled)

## Đặt độ nhạy con quay, luôn kẹp trong khoảng hợp lệ và lưu lại.
func set_tilt_sensitivity(value: float) -> void:
	var next := clampf(value, TILT_SENSITIVITY_MIN, TILT_SENSITIVITY_MAX)
	if is_equal_approx(tilt_sensitivity, next):
		return
	tilt_sensitivity = next
	_save_progress()
	tilt_sensitivity_changed.emit(tilt_sensitivity)

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
