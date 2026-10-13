extends Node

## Cảm biến con quay: đổi góc nghiêng máy thành góc xoay camera.
##
## Autoload nên góc xoay được tính đúng một lần mỗi khung và dùng chung cho mọi
## scene — `player.gd` chỉ việc lấy `consume_look_delta()` rồi cộng vào
## `SpringArm3D`.
##
## Vì sao dùng con quay (gyro) chứ không dùng trọng lực (gravity):
## gyro đo TỐC ĐỘ xoay, nên nghiêng máy rồi giữ yên thì camera dừng luôn —
## đúng như cách nghiêng đầu để nhìn. Còn trọng lực là góc TƯỚNG TÍNH, dùng nó
## thì phải hiệu chỉnh điểm giữa liên tục và giữ máy nghiêng cả buổi rất mỏi.
##
## Điểm yếu của gyro là trôi (drift): cầm máy yên, con quay vẫn báo một tốc độ
## xoay rất nhỏ, tích luỹ thành hàng chục độ sau vài chục giây. Ở đây ta tự ước
## lượng sai số đó: mỗi khi máy đang đứng yên đủ lâu, ta dần dịch vector sai số
## về đúng giá trị gyro đang báo, và trừ nó ra khỏi mọi lần đọc sau.
##
## Bản đồ trục — đọc kỹ trước khi sửa:
## `Input.get_gyroscope()` trả về tốc độ xoay quanh trục X/Y/Z CỦA THIẾT BỊ theo
## tư thế DỌC (portrait), KHÔNG phải theo hướng màn hình đang xoay. Game này
## chơi ngang, nên khi xoay máy 90° để nằm ngang:
##   - trục X (ngang khi dọc) -> chạm dọc màn hình -> gật/cúi đầu -> PITCH
##   - trục Y (dọc khi dọc)   -> chạm ngang màn hình -> nghiêng trái/phải -> YAW
##   - trục Z                  -> xoay trong mặt phẳng màn hình -> ít khi dùng
## Nên YAW đọc trục Y và PITCH đọc trục X. Trước đây YAW đọc trục Z nên
## người chơi nghiêng máy mà camera không quay ngang.
##
## Vì cách cầm máy khác nhau sẽ cho cảm giác khác, nên trục và dấu để chọn được
## trong Inspector (`yaw_axis`, `pitch_axis`, `invert_*`) thay vì phải sửa code.

## Dùng khi không đọc được GameManager (ví dụ khi test gọi trực tiếp). Giá trị
## thật luôn do người chơi chỉnh trong màn tuỳ chọn và lưu ở GameManager.
const DEFAULT_SENSITIVITY := 0.55

## Trục nào của gyro là tốc độ quay ngang (yaw) của camera.
@export var yaw_axis: Vector3i = Vector3i(0, 1, 0)
## Trục nào là tốc độ quay dọc (pitch).
@export var pitch_axis: Vector3i = Vector3i(1, 0, 0)
## Lật chiều quay ngang khi thấy nghiêng phải nhưng camera quay sang trái.
@export var invert_yaw: bool = false
## Lật chiều quay dọc khi thấy cúi đầu nhưng camera ngước lên.
@export var invert_pitch: bool = false

## Ngưỡng coi như "không nghiêng" (rad/s), áp lên tốc độ xoay trước khi nhân.
## Tay luôn rung nhẹ nên không có vùng chết thì camera trôi dù người chơi giữ
## máy yên. Trừ ngưỡng (thay vì so sánh rồi cắt) để lực tăng liên tục.
@export_range(0.0, 1.0, 0.01) var deadzone: float = 0.12
## Tốc độ ước lượng sai số (0 = tắt hiệu chỉnh).
@export_range(0.0, 8.0, 0.1) var bias_trim_rate: float = 2.0
## Máy phải đứng yên liên tục bao lâu thì mới bắt đầu hiệu chỉnh (giây), để
## tránh "dính" sai số vào lúc người chơi đang cầm máy chuyển động chậm.
@export_range(0.0, 3.0, 0.05) var still_time_to_trim: float = 0.5
## Dưới ngưỡng này (rad/s) coi như máy đang đứng yên.
@export_range(0.0, 1.0, 0.01) var still_threshold: float = 0.15

## Sai số con quay đang ước lượng.
var _bias := Vector3.ZERO
## Máy đã đứng yên liên tục được bao lâu.
var _still_for := 0.0
## Góc xoay của khung này (radian): x = yaw, y = pitch.
var _look_delta := Vector2.ZERO
## Đã từng đọc được con quay thật chưa. Máy tính và editor luôn trả Vector3.ZERO.
var _sensor_available := false

## Lấy góc xoay của khung vừa rồi rồi xoá, để mỗi khung chỉ áp dụng đúng một
## lần kể cả khi nhiều chỗ gọi.
func consume_look_delta() -> Vector2:
	var value := _look_delta
	_look_delta = Vector2.ZERO
	return value

## `true` khi nền tảng thực sự đọc được con quay. Màn tuỳ chọn dùng
## `OS.has_feature("mobile")` để quyết định khoá nút ngay từ đầu, nên hàm này
## chủ yếu phục vụ test và chẩn đoán trên thiết bị thật.
func is_sensor_available() -> bool:
	return _sensor_available

## Delta góc của khung hiện tại mà chưa xoá — chỉ để test và debug.
func peek_look_delta() -> Vector2:
	return _look_delta

## Sai số con quay đang trừ (rad/s) — chỉ để test và debug.
func get_bias() -> Vector3:
	return _bias

## Xoá sai số đã ước lượng, quay về trạng thái sạch. Cũng được gọi mỗi lần
## bật/tắt chế độ.
func reset_bias() -> void:
	_reset_trim()
	_look_delta = Vector2.ZERO

## Nguồn cấu hình bật/tắt. Để trống thì dùng autoload `GameManager`. Test gán
## bản sao riêng vì trong ngữ cảnh editor autoload chỉ là placeholder nên
## không gọi được method của script.
var manager: Node = null

func _get_manager() -> Node:
	return manager if manager != null else GameManager

func _ready() -> void:
	var gm := _get_manager()
	if gm != null and not gm.tilt_camera_changed.is_connected(_on_tilt_camera_changed):
		gm.tilt_camera_changed.connect(_on_tilt_camera_changed)

func _process(delta: float) -> void:
	var gm := _get_manager()
	if gm == null or not gm.tilt_camera_enabled:
		# Tắt thì quên sạch trạng thái hiệu chỉnh, bật lại thì ước lượng từ đầu
		# thay vì dùng số liệu của lần trước.
		_reset_trim()
		_look_delta = Vector2.ZERO
		return
	var gyro := Input.get_gyroscope()
	if gyro.length_squared() <= 0.0:
		# Máy tính / editor: không có con quay. Cần đọc được giá trị khác 0 thật
		# mới coi là có cảm biến, không thì sẽ báo "có" ngay từ frame đầu.
		_look_delta = Vector2.ZERO
		return
	_sensor_available = true
	_look_delta = feed_gyro(gyro, delta)

## Đưa một mẫu gyro vào, lưu làm delta của khung và trả luôn góc xoay tương
## ứng (radian cho cả khung). Tách riêng khỏi `_process()` để kiểm chứng được
## trên máy tính, không cần điện thoại thật.
func feed_gyro(gyro: Vector3, delta: float) -> Vector2:
	var corrected := _apply_bias_trim(gyro, delta)
	var rates := _gyro_to_look_rates(corrected)
	var gain := _get_sensitivity() * delta
	_look_delta = Vector2(
		_apply_deadzone(rates.x) * gain,
		_apply_deadzone(rates.y) * gain)
	return _look_delta

## Độ nhạy do người chơi chỉnh trong màn tuỳ chọn và `GameManager` giữ. Đọc mỗi
## lần gọi để kéo thanh trượt là có tác dụng ngay, không cần đồng bộ lại.
func _get_sensitivity() -> float:
	var gm := _get_manager()
	if gm == null:
		return DEFAULT_SENSITIVITY
	return clampf(float(gm.tilt_sensitivity), 0.0, 10.0)

## Máy đứng yên đủ lâu thì dịch dần vector sai số về giá trị gyro đang báo;
## đang cầm chuyển động thì giữ nguyên sai số đã ước lượng.
##
## `still_threshold` phải chỉ lớn hơn `deadzone` một chút. Lớn hơn thì hiệu
## chỉnh có tác dụng (nới rộng vùng chết hiệu dụng, camera đỡ trôi); mà lớn quá
## thì lúc người chơi cố tình xoay chậm cũng bị coi là đứng yên và bị "xoá",
## camera dính. Giá trị mặc định 0.15 rad/s (~8.6°/s) nằm ngay dưới mức xoay
## chậm có chủ đích nên không gây dính.
func _apply_bias_trim(gyro: Vector3, delta: float) -> Vector3:
	if gyro.length() > still_threshold:
		_still_for = 0.0
		return gyro - _bias
	_still_for += delta
	if _still_for < still_time_to_trim or bias_trim_rate <= 0.0:
		return gyro - _bias
	var weight := clampf(bias_trim_rate * delta, 0.0, 1.0)
	_bias = _bias.lerp(gyro, weight)
	return gyro - _bias

## Đổi tốc độ xoay của thiết bị (rad/s) sang (yaw, pitch) của camera theo đúng
## trục người chơi đang nghiêng. Xem khối chú thích đầu file để hiểu vì sao mặc
## định lấy Y = yaw, X = pitch.
func _gyro_to_look_rates(gyro: Vector3) -> Vector2:
	var yaw := gyro.dot(Vector3(yaw_axis))
	var pitch := gyro.dot(Vector3(pitch_axis))
	return Vector2(-yaw if not invert_yaw else yaw, -pitch if not invert_pitch else pitch)

func _apply_deadzone(rate: float) -> float:
	var magnitude := absf(rate)
	if magnitude <= deadzone:
		return 0.0
	return signf(rate) * (magnitude - deadzone)

func _on_tilt_camera_changed(_enabled: bool) -> void:
	# Bật lại thì ước lượng lại từ đầu, tránh kế thừa sai số của lần trước và
	# tránh camera giật lúc vừa bật.
	reset_bias()

func _reset_trim() -> void:
	_bias = Vector3.ZERO
	_still_for = 0.0
