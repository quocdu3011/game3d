@tool
extends McpTestSuite

# Hồi quy cho chế độ cảm biến con quay:
#  - Cờ bật/tắt được lưu và nạp lại đúng qua file tiến trình.
#  - Đọc gyro ra góc xoay đúng chiều, đúng độ lớn.
#  - Vùng chết chặn tay rung, và sai số (drift) được hiệu chỉnh dần về 0.
#  - Delta chỉ dùng được một lần cho mỗi khung.
#  - Màn tuỳ chọn có hàng bật/tắt nối vào GameManager.

const GM_SCRIPT := "res://scripts/game_manager.gd"
const TMP_SAVE := "user://__test_tilt.cfg"

var _gm: Node
var _sensor: Node

func suite_name() -> String:
	return "tilt_sensor"

func setup() -> void:
	var gm_script: GDScript = load(GM_SCRIPT)
	_gm = gm_script.new()
	_gm.save_path = TMP_SAVE
	_sensor = load("res://scripts/tilt_sensor.gd").new()
	# McpTestSuite extends RefCounted nên không add_child được. Trong ngữ cảnh
	# editor autoload `GameManager` chỉ là placeholder nên không gọi được method,
	# vì vậy sensor được trỏ sang bản sao riêng rồi gọi `_ready()` tay để
	# kiểm chứng đúng phần nối tín hiệu.
	_sensor.manager = _gm
	_sensor._ready()

func teardown() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))
	if _gm != null and is_instance_valid(_gm):
		_gm.free()
	_gm = null
	if _sensor != null and is_instance_valid(_sensor):
		_sensor.free()
	_sensor = null

## Mẫu sai số nằm giữa `deadzone` và `still_threshold`, đặt trên trục Y (trục
## quay ngang): lớn hơn ngưỡng chết để còn sinh góc xoay, nhỏ hơn ngưỡng "đứng
## yên" để được phép hiệu chỉnh.
func _bias_sample() -> Vector3:
	return Vector3(0.0, _sensor.deadzone + (_sensor.still_threshold - _sensor.deadzone) * 0.5, 0.0)

func test_toggle_persists_across_reload() -> void:
	_gm.reset_progress()
	_gm.set_tilt_camera_enabled(true)

	var reloaded: Node = load(GM_SCRIPT).new()
	reloaded.save_path = TMP_SAVE
	reloaded._load_progress()
	assert_eq(reloaded.tilt_camera_enabled, true, "Che do con quay phai con sau khi nap lai")
	reloaded.free()

func test_toggle_is_off_by_default() -> void:
	_gm.reset_progress()
	assert_eq(_gm.tilt_camera_enabled, false, "Mac dinh phai tat")

func test_save_without_the_key_stays_off() -> void:
	# Save cũ chưa từng ghi khoá này thì phải mặc định tắt, không lỗi.
	var config := ConfigFile.new()
	config.set_value("settings", "camera_mode", 0)
	config.save(TMP_SAVE)
	_gm._load_progress()
	assert_eq(_gm.tilt_camera_enabled, false, "Save cu khong co khoa -> van tat")
func test_reset_progress_leaves_toggle_untouched() -> void:
	# Đây là setting, không phải tiến độ chơi — xoá tiến độ không được làm
	# mất lựa chọn đã bật.
	_gm.set_tilt_camera_enabled(true)
	_gm.reset_progress()
	assert_eq(_gm.tilt_camera_enabled, true, "Xoa tien do khong duoc tat che do con quay")

func test_gyro_inside_deadzone_produces_nothing() -> void:
	# Tay luôn rung nhẹ khi cầm máy: phải bị bỏ qua hoàn toàn.
	var look: Vector2 = _sensor.feed_gyro(Vector3(0.05, 0.0, 0.05), 0.016)
	assert_eq(look, Vector2.ZERO, "Trong vung chet phai ra 0")

func test_gyro_outside_deadzone_turns_camera() -> void:
	# Máy cầm ngang: nghiêng trái/phải là quay quanh trục Y, gật/cúi đầu là
	# quay quanh trục X. Đọc sai trục là nguyên nhân camera chỉ xoay dọc.
	var yaw: float = _sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016).x
	assert_ne(yaw, 0.0, "Nghieng trai/phai ( truc Y) phai xoay ngang")
	var pitch: float = _sensor.feed_gyro(Vector3(1.0, 0.0, 0.0), 0.016).y
	assert_ne(pitch, 0.0, "Gat/cui dau ( truc X) phai doi goc pitch")

func test_in_plane_spin_does_not_turn_camera() -> void:
	# Xoay trong mặt phẳng màn hình (trục Z) không phải cử chỉ của người
	# chơi, nên không được tạo ra góc xoay nào.
	var spin: Vector2 = _sensor.feed_gyro(Vector3(0.0, 0.0, 1.0), 0.016)
	assert_eq(spin, Vector2.ZERO, "Xoay trong mat phang man hinh phai bi bo qua")

func test_yaw_and_pitch_come_from_different_axes() -> void:
	# Nghiêng ngang không được lẫn sang pitch và ngược lại.
	var horizontal: Vector2 = _sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016)
	assert_eq(horizontal.y, 0.0, "Nghieng ngang khong duoc doi pitch")
	var vertical: Vector2 = _sensor.feed_gyro(Vector3(1.0, 0.0, 0.0), 0.016)
	assert_eq(vertical.x, 0.0, "Gat/cui khong duoc doi yaw")

func test_invert_flags_flip_direction() -> void:
	_sensor.invert_yaw = true
	var flipped: float = _sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016).x
	_sensor.invert_yaw = false
	var normal: float = _sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016).x
	assert_ne(flipped, normal, "invert_yaw phai dao chieu quay ngang")
	assert_true(is_equal_approx(flipped, -normal), "invert_yaw phai doi dau tinh")
	_sensor.invert_pitch = true
	var pitch_flipped: float = _sensor.feed_gyro(Vector3(1.0, 0.0, 0.0), 0.016).y
	_sensor.invert_pitch = false
	var pitch_normal: float = _sensor.feed_gyro(Vector3(1.0, 0.0, 0.0), 0.016).y
	assert_true(is_equal_approx(pitch_flipped, -pitch_normal), "invert_pitch phai doi dau tinh")

func test_gyro_scales_with_frame_time() -> void:
	# Cùng tốc độ xoay, khung dài hơn thì góc xoay phải lớn hơn. So sánh độ lớn
	# vì dấu phụ thuộc chiều nghiêng (nghiêng trái hay phải).
	var fast: float = absf(_sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016).x)
	var short: float = absf(_sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.004).x)
	assert_gt(fast, short, "Khung dai hon thi xoay nhieu hon (%.5f vs %.5f)" % [fast, short])

func test_sensitivity_scales_rotation() -> void:
	# Thanh trượt độ nhạy trong tuỳ chọn phải nắm được: gấp đôi độ nhạy thì
	# góc xoay gấp đôi.
	var base: float = absf(_sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016).x)
	_gm.set_tilt_sensitivity(_gm.tilt_sensitivity * 2.0)
	var faster: float = absf(_sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016).x)
	_gm.set_tilt_sensitivity(_gm.tilt_sensitivity * 0.5)
	assert_true(is_equal_approx(faster, base * 2.0),
		"Gap doi do nhay thi goc xoay gap doi (%.5f -> %.5f)" % [base, faster])

func test_sensitivity_is_clamped_and_persisted() -> void:
	_gm.set_tilt_sensitivity(99.0)
	assert_eq(_gm.tilt_sensitivity, _gm.TILT_SENSITIVITY_MAX, "Do nhay phai bi kep o moc cao")
	_gm.set_tilt_sensitivity(-5.0)
	assert_eq(_gm.tilt_sensitivity, _gm.TILT_SENSITIVITY_MIN, "Do nhay phai bi kep o moc thap")

	_gm.set_tilt_sensitivity(1.25)
	var reloaded: Node = load(GM_SCRIPT).new()
	reloaded.save_path = TMP_SAVE
	reloaded._load_progress()
	assert_true(is_equal_approx(reloaded.tilt_sensitivity, 1.25),
		"Do nhay phai con sau khi nap lai (%s)" % reloaded.tilt_sensitivity)
	reloaded.free()

func test_broken_saved_sensitivity_is_clamped() -> void:
	# Save hỏng ghi 0 hoặc số âm không được làm thanh trượt nhảy về cuối.
	var config := ConfigFile.new()
	config.set_value("settings", "tilt_sensitivity", -3.0)
	config.save(TMP_SAVE)
	_gm._load_progress()
	assert_eq(_gm.tilt_sensitivity, _gm.TILT_SENSITIVITY_MIN,
		"Gia tri luu hong phai duoc kep lai")
	assert_gt(_gm.tilt_sensitivity, 0.0, "Do nhay phai duong")

func test_steady_bias_is_trimmed_away() -> void:
	# Đứng yên, máy vẫn báo một tốc độ xoay nhỏ đều (sai số của con quay).
	# Không hiệu chỉnh thì delta cộng dồn và camera trôi.
	var bias := _bias_sample()
	var first: float = _sensor.feed_gyro(bias, 0.016).x
	var last := 0.0
	for _i in range(400):
		last = _sensor.feed_gyro(bias, 0.016).x
	assert_gt(absf(first), 0.0, "Chua hieu chinh thi van ra goc xoay")
	assert_true(absf(last) < absf(first),
		"Dung yen lau phai hieu chinh sai so ve 0 (dau %.5f -> cuoi %.5f)"
			% [first, last])

func test_moving_device_is_not_trimmed() -> void:
	# Đang nghiêng thì không được "đính" sai số vào mẫu hiện tại, làm mất
	# phản hồi khi người chơi cầm máy chuyển động.
	var gyro := Vector3(0.0, 1.2, 0.0)
	var first: float = _sensor.feed_gyro(gyro, 0.016).x
	var second: float = _sensor.feed_gyro(gyro, 0.016).x
	assert_eq(second, first, "Dang nghieng phai giu nguyen do lon giua cac khung")
	assert_gt(absf(first), 0.0, "Van phai ra goc xoay dang ke khi dang xoay")

func test_delta_is_consumed_once() -> void:
	_sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016)
	var first: Vector2 = _sensor.consume_look_delta()
	var second: Vector2 = _sensor.consume_look_delta()
	assert_ne(first, Vector2.ZERO, "Khung co goc xoay thi lan doc dau phai ra gia tri")
	assert_eq(second, Vector2.ZERO, "Lan doc thu hai phai ra 0")

func test_disabled_sensor_produces_nothing() -> void:
	_gm.set_tilt_camera_enabled(false)
	# Dù cảm biến có báo gì thì lúc tắt cũng không được xoay camera.
	_sensor._process(0.016)
	assert_eq(_sensor.peek_look_delta(), Vector2.ZERO, "Tat thi khong duoc xoay camera")

func test_enabled_sensor_reads_gyro_in_process() -> void:
	# `_process` phải lấy gyro từ thiết bị và đổ vào delta của khung.
	_gm.set_tilt_camera_enabled(true)
	_sensor.reset_bias()
	# Máy tính không có gyro nên `_process` không đổi gì — nhưng đường dẫn
	# bật/tắt vẫn phải chạy không lỗi.
	_sensor._process(0.016)
	assert_eq(_sensor.peek_look_delta(), Vector2.ZERO,
		"Khong co gyro that thi khong co goc xoay nao")

func test_toggle_signal_resets_estimate() -> void:
	# Bật lại phải ước lượng lại từ đầu, không kế thừa sai số lần trước.
	# Hiệu chỉnh chỉ chạy sau `still_time_to_trim` giây đứng yên nên phải đổ
	# đủ khung thì sai số mới được ghi nhận.
	var bias := _bias_sample()
	for _i in range(60):
		_sensor.feed_gyro(bias, 0.016)
	assert_ne(_sensor.get_bias(), Vector3.ZERO, "Da uoc luong sai so")
	_gm.set_tilt_camera_enabled(true)
	assert_eq(_sensor.get_bias(), Vector3.ZERO, "Bat lai phai xoa sai so da uoc luong")

func test_sensor_reports_unavailable_on_desktop() -> void:
	# Máy tính/editor: `Input.get_gyroscope()` luôn trả Vector3.ZERO.
	assert_false(_sensor.is_sensor_available(),
		"Khong doc duoc gyro thi khong duoc bao co cam bien")

## Màn tuỳ chọn nối tín hiệu trong `_ready()`, nên HUD phải được đưa vào cây thật
## thì mới kiểm tra được phần nối.
func _open_options_overlay() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var hud := track((load("res://scenes/ui/hud.tscn") as PackedScene).instantiate())
	tree.root.add_child(hud)
	return hud

func test_options_panel_has_tilt_row() -> void:
	# Lưu ý: `options_menu.gd` không phải `@tool` nên `_ready()` KHÔNG chạy
	# trong editor — phần nối tín hiệu chỉ kiểm được lúc chạy thật, thuộc về
	# `tools/verify_tilt_camera.gd`. Ở đây chỉ kiểm tra cấu trúc scene.
	var hud := _open_options_overlay()
	var overlay := hud.get_node_or_null("OptionsOverlay") as Control
	assert_ne(overlay, null, "Phai co overlay tuy chon")
	if overlay == null:
		return
	assert_ne(overlay.get_script(), null, "Overlay phai gan script")
	assert_eq(str(overlay.get_script().resource_path), "res://scripts/options_menu.gd",
		"Overlay dung dung script tuy chon")

	var toggle := overlay.get_node_or_null("OptionsPanel/TiltRow/ToggleTilt") as Button
	assert_ne(toggle, null, "Phai co nut bat/tat cam bien trong man tuy chon")
	if toggle != null:
		assert_ne(toggle.get_node_or_null("Art"), null, "Nut bat/tat phai co art")

func test_options_panel_has_tilt_sensitivity_slider() -> void:
	var hud := _open_options_overlay()
	var row := hud.get_node_or_null("OptionsOverlay/OptionsPanel/TiltSensRow") as Control
	assert_ne(row, null, "Phai co hang chinh do nhay con quay")
	if row == null:
		return
	var slider := row.get_node_or_null("SliderTiltSens") as HSlider
	assert_ne(slider, null, "Phai co thanh truot do nhay")
	if slider == null:
		return
	assert_eq(slider.min_value, 0.0, "Thanh truot bat dau tu 0")
	assert_eq(slider.max_value, 100.0, "Thanh truot ket thuc o 100")
	# Hàng độ nhạy phải nằm dưới hàng bật/tắt, không đè lên nhau.
	var toggle_row := hud.get_node_or_null("OptionsOverlay/OptionsPanel/TiltRow") as Control
	assert_ne(toggle_row, null, "Phai co hang bat/tat con quay")
	if toggle_row != null:
		assert_true(row.get_rect().position.y >= toggle_row.get_rect().end.y,
			"Hang do nhay phai nam duoi hang bat/tat, khong de chong")

func test_overlays_hide_inventory_but_never_the_joystick() -> void:
	# Hồi quy: mở overlay phải giấu thanh inventory (nó đè lên các hàng dưới
	# cùng của panel), nhưng TUYỆT ĐỐI không được đụng vào cần điều khiển ảo —
	# trước đây hàm này ẩn joystick mà không khôi phục, làm joystick mất vĩnh
	# viễn sau lần đầu mở Tuỳ chọn.
	var hud := track((load("res://scenes/ui/hud.tscn") as PackedScene).instantiate())
	(Engine.get_main_loop() as SceneTree).root.add_child(hud)
	var joystick := hud.get_node_or_null("VirtualJoystick") as Control
	var bar := hud.get_node_or_null("InventoryBar") as Control
	assert_ne(joystick, null, "Phai co can dieu khien ao")
	if joystick == null or bar == null:
		return
	assert_true(joystick.visible, "Can dieu khien ao phai hien khi vao man")

	var options := hud.get_node_or_null("OptionsOverlay") as Control
	options.visible = true
	assert_true(joystick.visible, "Mo overlay khong duoc lam mat can dieu khien ao")
	assert_false(bar.visible, "Mo overlay phai giau thanh inventory")

	options.visible = false
	assert_true(joystick.visible, "Dong overlay can dieu khien ao phai hien lai")
	assert_true(bar.visible, "Dong overlay thanh inventory phai hien lai")

	var pause := hud.get_node_or_null("PauseOverlay") as Control
	pause.visible = true
	assert_true(joystick.visible, "Mo menu tam dung cung khong duoc an can dieu khien ao")
	assert_false(bar.visible, "Menu tam dung phai giau thanh inventory")
	pause.visible = false
	assert_true(joystick.visible, "Dong menu tam dung can dieu khien ao phai hien lai")
	assert_true(bar.visible, "Dong menu tam dung thanh inventory phai hien lai")

func test_toggle_music_still_present() -> void:
	# Hồi quy: thêm hàng mới không được làm hỏng hàng nhạc nền.
	var hud := _open_options_overlay()
	assert_ne(hud.get_node_or_null("OptionsOverlay/OptionsPanel/MusicRow/ToggleMusic"), null,
		"Hang nhac nen phai con")
	assert_ne(hud.get_node_or_null("OptionsOverlay/OptionsPanel/AudioRow/SliderAudio"), null,
		"Hang am luong phai con")

func test_tilt_row_does_not_overlap_camera_row() -> void:
	# Hồi quy bố cục: hai hàng phải nằm chồng lên nhau là hỏng, vì đã có sẵn
	# hàng GÓC NHÌN chiếm đúng dải giữa panel.
	var hud := _open_options_overlay()
	var tilt := hud.get_node_or_null("OptionsOverlay/OptionsPanel/TiltRow") as Control
	var cam := hud.get_node_or_null("OptionsOverlay/OptionsPanel/CameraRow") as Control
	assert_ne(tilt, null, "Phai co hang cam bien")
	if tilt == null or cam == null:
		return
	var tilt_rect := tilt.get_rect()
	var cam_rect := cam.get_rect()
	assert_true(tilt_rect.position.y >= cam_rect.end.y
			or cam_rect.position.y >= tilt_rect.end.y,
		"Hang cam bien phai nam duoi hang goc nhin, khong de chong (%s vs %s)"
			% [str(tilt_rect), str(cam_rect)])
