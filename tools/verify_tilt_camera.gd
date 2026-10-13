extends SceneTree

## Kiem chung chu dung chu dong cam bien con quay (chay headless, khong can
## dien thoai that).
##
## `TiltSensor` doc `Input.get_gyroscope()` ma may tinh luon tra Vector3.ZERO,
## nen phai day truc tiep mau qua `feed_gyro()` de kiem chung phan tinh toan.
## Cac buoc kiem tra phan con lai chay that voi scene that.

const GM_SCRIPT := "res://scripts/game_manager.gd"
const TMP_SAVE := "user://__verify_tilt.cfg"

var _gm: Node
var _sensor: Node
var _player: CharacterBody3D
var _step := 0
var _bad := 0
## Luu lai de tra lai dung sau khi kiem chung xong.
var _gm_saved_path := ""
var _live: Node

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	match _step:
		0:
			_step = 1
			_live = root.get_node("GameManager")
			_gm_saved_path = _live.save_path
			# Phải trỏ save thật sang file tạm TRƯỚC khi bật cờ, vì
			# `set_tilt_camera_enabled()` ghi đĩa ngay.
			_live.save_path = TMP_SAVE
			_gm = load(GM_SCRIPT).new()
			_gm.save_path = TMP_SAVE
			_sensor = load("res://scripts/tilt_sensor.gd").new()
			_sensor._ready()
			_player = (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
			root.add_child(_player)
			return false
		1:
			if int(Engine.get_physics_frames()) < 6:
				return false
			_step = 2
			_report()
			quit(0 if _bad == 0 else 1)
			return true
	return false

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_bad += 1
	print("%-46s : %s %s" % [label, "OK" if ok else "LOI", detail])

## Đúng công thức trong `options_menu.gd` để kiểm tra thanh trượt hiển thị đúng.
func _slider_from_sensitivity(value: float) -> float:
	var span: float = _live.TILT_SENSITIVITY_MAX - _live.TILT_SENSITIVITY_MIN
	return clampf((value - _live.TILT_SENSITIVITY_MIN) / span * 100.0, 0.0, 100.0)

func _report() -> void:
	print("=== Kiem chung cam bien con quay ===")

	# --- Cai dat sensors phai bat trong project settings ---
	_check("project bat cam bien gia toc do",
		ProjectSettings.get_setting("input_devices/sensors/enable_gyroscope", false) == true,
		"(enable_gyroscope = %s)" % ProjectSettings.get_setting("input_devices/sensors/enable_gyroscope", "<chua dat>"))
	_check("project bat cam bien gia toc",
		ProjectSettings.get_setting("input_devices/sensors/enable_gravity", false) == true)

	# --- Luu / nap lai co giu lua chon ---
	_gm.set_tilt_camera_enabled(true)
	var reloaded: Node = load(GM_SCRIPT).new()
	reloaded.save_path = TMP_SAVE
	reloaded._load_progress()
	_check("lua chon con giu qua file", reloaded.tilt_camera_enabled == true)
	reloaded.free()
	# Save rong hoac save cu chua tung ghi khoa nay -> phai mac dinh tat.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))
	var fresh: Node = load(GM_SCRIPT).new()
	fresh.save_path = TMP_SAVE
	fresh._load_progress()
	_check("mac dinh la tat khi save rong", fresh.tilt_camera_enabled == false)
	fresh.free()
	var legacy := ConfigFile.new()
	legacy.set_value("settings", "camera_mode", 0)
	legacy.save(TMP_SAVE)
	var old: Node = load(GM_SCRIPT).new()
	old.save_path = TMP_SAVE
	old._load_progress()
	_check("save cu chua co khoa -> van tat", old.tilt_camera_enabled == false)
	old.free()
	_gm.reset_progress()
	_gm.set_tilt_camera_enabled(true)
	_gm.reset_progress()
	_check("xoa tien do khong lam mat lua chon", _gm.tilt_camera_enabled == true)

	# --- Vung chet chong tay rung ---
	var idle: Vector2 = _sensor.feed_gyro(Vector3(0.05, 0.0, 0.05), 0.016)
	_check("trong vung chet ra 0", idle == Vector2.ZERO, "(nhan %s)" % str(idle))

	# --- Doc gyro ra goc xoay: truc Y la ngieng trai/phai, truc X la gat/cui ---
	var yaw: float = _sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016).x
	var pitch: float = _sensor.feed_gyro(Vector3(1.0, 0.0, 0.0), 0.016).y
	_check("nghiêng trái/phải (trục Y) -> yaw", yaw != 0.0, "(yaw = %+.5f rad)" % yaw)
	_check("gật/cúi đầu (trục X) -> pitch", pitch != 0.0, "(pitch = %+.5f rad)" % pitch)
	_check("nghiêng ngang không lẫn sang pitch",
		is_zero_approx(_sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016).y))
	_check("xoay trong mặt phẳng màn hình bị bỏ qua",
		_sensor.feed_gyro(Vector3(0.0, 0.0, 1.0), 0.016) == Vector2.ZERO)

	# --- Vung chet phai don, khong phai cat ---
	var half: float = _sensor.feed_gyro(Vector3(0.0, 0.5, 0.0), 0.016).x
	var full: float = _sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016).x
	_check("ngoai vung chet van phai xoay", half != 0.0, "(yaw = %+.5f)" % half)
	_check("cang nhanh thi xoay cang nhieu", absf(full) > absf(half))

	# --- Sai so (drift) duoc hieu chinh ---
	# Gia tri phai nằm giua `deadzone` va `still_threshold`: lon hon deadzone de
	# con tao goc xoay, nho hon nguong "dung yen" de duoc phep hieu chinh.
	var bias := Vector3(0.0, _sensor.deadzone + (_sensor.still_threshold - _sensor.deadzone) * 0.5, 0.0)
	_check("mau sai so nam trong khoang hieu chinh",
		_sensor.still_threshold > _sensor.deadzone,
		"(deadzone = %.2f, still_threshold = %.2f)" % [_sensor.deadzone, _sensor.still_threshold])
	var drift_first: float = _sensor.feed_gyro(bias, 0.016).x
	var drift_last := 0.0
	for _i in range(400):
		drift_last = _sensor.feed_gyro(bias, 0.016).x
	_check("dung yen -> het tro cua con quay",
		absf(drift_last) < absf(drift_first),
		"(truoc %+.5f -> sau %+.5f rad/khung)" % [drift_first, drift_last])
	_check("hieu chinh xong gan 0", absf(drift_last) < 0.0001,
		"(con %+.6f rad)" % drift_last)

	# --- Dang nghieng thi khong duoc sua ---
	_sensor.reset_bias()
	var moving := Vector3(0.0, 1.2, 0.0)
	var m1: float = _sensor.feed_gyro(moving, 0.016).x
	var m2: float = _sensor.feed_gyro(moving, 0.016).x
	_check("dang nghieng giu nguyen do lon", is_equal_approx(m1, m2),
		"(%.6f vs %.6f)" % [m1, m2])

	# --- Chi dung mot lan moi khung ---
	_sensor.reset_bias()
	_sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016)
	var consumed: Vector2 = _sensor.consume_look_delta()
	var again: Vector2 = _sensor.consume_look_delta()
	_check("doc lan dau co gia tri", consumed != Vector2.ZERO)
	_check("doc lan hai ra 0", again == Vector2.ZERO)

	# --- Camera that xoay theo ---
	# `player._apply_tilt_camera()` doc `TiltSensor` AUTOLOAD, nen phai day mau
	# vao chinh no chu khong phai ban sao `_sensor` o tren.
	_sensor.reset_bias()
	_live.set_tilt_camera_enabled(true)
	var live_sensor: Node = root.get_node("TiltSensor")
	live_sensor.reset_bias()
	var arm: SpringArm3D = _player.get_node("SpringArm3D")
	arm.rotation = Vector3.ZERO
	live_sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016)
	_player._apply_tilt_camera()
	_check("camera that xoay theo cam bien", absf(arm.rotation.y) > 0.0001,
		"(yaw = %+.5f rad)" % arm.rotation.y)

	# --- Pitch bi kẹp trong gioi han o ca hai dau ---
	arm.rotation = Vector3.ZERO
	live_sensor._look_delta = Vector2(0.0, -99.0)
	_player._apply_tilt_camera()
	_check("pitch kẹp đúng đỉnh khi ngẩng lên",
		rad_to_deg(arm.rotation.x) <= _player.camera_pitch_max + 0.01,
		"(pitch = %.2f deg, can <= %.2f)" % [rad_to_deg(arm.rotation.x), _player.camera_pitch_max])
	arm.rotation = Vector3.ZERO
	live_sensor._look_delta = Vector2(0.0, 99.0)
	_player._apply_tilt_camera()
	_check("pitch kẹp đúng đáy khi cúi xuống",
		rad_to_deg(arm.rotation.x) >= _player.camera_pitch_min - 0.01,
		"(pitch = %.2f deg, can >= %.2f)" % [rad_to_deg(arm.rotation.x), _player.camera_pitch_min])

	# --- Tat thi camera dung yen ---
	_live.set_tilt_camera_enabled(false)
	arm.rotation = Vector3.ZERO
	live_sensor._look_delta = Vector2(0.2, 0.0)
	_player._apply_tilt_camera()
	_check("tat thi camera khong doi", is_zero_approx(arm.rotation.y))

	# --- Sensor that: may tinh khong co ---
	_check("may tinh bao khong co cam bien", _sensor.is_sensor_available() == false)

	# --- Man tuy chon co nut bat/tat ---
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	var toggle := hud.get_node_or_null("OptionsOverlay/OptionsPanel/TiltRow/ToggleTilt") as Button
	_check("man tuy chon co nut cam bien", toggle != null)
	if toggle != null:
		_check("nut noi signal pressed", toggle.pressed.get_connections().size() > 0)
		_check("nut khoa tren may tinh", toggle.disabled == true)
	_check("hang nhac nen con nguyen",
		hud.get_node_or_null("OptionsOverlay/OptionsPanel/MusicRow/ToggleMusic") != null)

	# --- Thanh truot do nhay: chi chay that, nen phai kiem o runtime ---
	var sens_row := hud.get_node_or_null("OptionsOverlay/OptionsPanel/TiltSensRow")
	_check("man tuy chon co hang do nhay", sens_row != null)
	if sens_row != null:
		var slider := sens_row.get_node_or_null("SliderTiltSens") as HSlider
		_check("co thanh truot do nhay", slider != null)
		if slider != null:
			_check("thanh truot chay tu 0 den 100",
				slider.min_value == 0.0 and slider.max_value == 100.0,
				"(%.0f..%.0f)" % [slider.min_value, slider.max_value])
			# Thanh phải phản ánh đúng độ nhạy đang lưu khi mở màn tuỳ chọn.
			_live.tilt_sensitivity = 0.55
			slider.value = _slider_from_sensitivity(0.55)
			_check("thanh phai hien dung do nhay da luu",
				is_equal_approx(_live.tilt_sensitivity, 0.55),
				"(=%s)" % _live.tilt_sensitivity)
			# Kéo hết cỡ hai đầu thì độ nhạy phải bị kẹp trong khoảng hợp lệ.
			slider.value = slider.max_value
			_check("kéo hết cỡ không vượt quá mức tối đa",
				is_equal_approx(_live.tilt_sensitivity, _live.TILT_SENSITIVITY_MAX),
				"(=%s)" % _live.tilt_sensitivity)
			slider.value = slider.min_value
			_check("kéo hết cỡ không nhỏ hơn mức tối thiểu",
				is_equal_approx(_live.tilt_sensitivity, _live.TILT_SENSITIVITY_MIN),
				"(=%s)" % _live.tilt_sensitivity)

	# --- Do nhay that su co hieu luc len goc xoay ---
	_sensor.reset_bias()
	_sensor.manager = _live
	_live.tilt_sensitivity = 0.4
	var slow_look: float = absf(_sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016).x)
	_live.tilt_sensitivity = 0.8
	var fast_look: float = absf(_sensor.feed_gyro(Vector3(0.0, 1.0, 0.0), 0.016).x)
	_check("độ nhạy gấp đôi thì camera xoay gấp đôi",
		is_equal_approx(fast_look, slow_look * 2.0),
		"(0.40 -> %+.5f, 0.80 -> %+.5f)" % [slow_look, fast_look])

	# --- HUD chrome: mo overlay giau thanh inventory nhung KHONG duoc dung
	#     vao can dieu khien ao (truoc day no bi an ma khong khoi phuc, lam
	#     joystick mat vinh vien sau lan dau mo Tuyn chon). ---
	var joystick := hud.get_node_or_null("VirtualJoystick") as Control
	var inv_bar := hud.get_node_or_null("InventoryBar") as Control
	_check("HUD co can dieu khien ao", joystick != null)
	if joystick != null and inv_bar != null:
		_check("can dieu khien ao hien khi vao man", joystick.visible)
		hud.get_node("OptionsOverlay").visible = true
		_check("mo Tuyn chon: can dieu khien ao van hien", joystick.visible)
		_check("mo Tuyn chon: thanh inventory bi giau", not inv_bar.visible)
		hud.get_node("OptionsOverlay").visible = false
		_check("dong Tuyn chon: can dieu khien ao van hien", joystick.visible)
		_check("dong Tuyn chon: thanh inventory hien lai", inv_bar.visible)

		var pause := hud.get_node_or_null("PauseOverlay") as Control
		if pause != null:
			pause.visible = true
			_check("mo menu tam dung: can dieu khien ao van hien", joystick.visible)
			_check("mo menu tam dung: thanh inventory bi giau", not inv_bar.visible)
			pause.visible = false
			_check("dong menu tam dung: can dieu khien ao van hien", joystick.visible)
			_check("dong menu tam dung: thanh inventory hien lai", inv_bar.visible)

	# Chup anh o cuoi, de man tuy chon quay ve trang thai tai nguyen.
	hud.get_node("OptionsOverlay").visible = true

	print("")
	print("=== TAT CA DUNG ===" if _bad == 0 else "=== %d LOI ===" % _bad)

	# Dọn dẹp: gỡ cờ TRƯỚC khi trả `save_path` về file thật, nếu không lần ghi
	# của `set_tilt_camera_enabled()` sẽ rơi vào save thật của người chơi.
	_live.set_tilt_camera_enabled(false)
	_live.save_path = _gm_saved_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))
