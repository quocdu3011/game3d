extends SceneTree

## Kiem chung con quay tren MOT MAN THAT: bật cờ -> di chuyen nhan vat -> xoay
## camera bang gia tri goc day vao -> phaii thay doi goc nhin that su.
##
## Bo phan doc gyro (`feed_gyro`) vi may tinh khong co cam bien, nhung phan
## "cam bien -> `SpringArm3D`" van chay y het tren scene that.

const TMP_SAVE := "user://__verify_tilt_level.cfg"

var _step := 0
var _live: Node
var _sensor: Node
var _player: CharacterBody3D
var _arm: SpringArm3D
var _gm_save_path := ""
var _bad := 0

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	match _step:
		0:
			_step = 1
			_live = root.get_node("GameManager")
			_gm_save_path = _live.save_path
			_live.save_path = TMP_SAVE
			_live.set_tilt_camera_enabled(true)
			_sensor = root.get_node("TiltSensor")
			return false
		1:
			if int(Engine.get_physics_frames()) < 4:
				return false
			_step = 2
			_player = root.find_child("1", true, false)
			if _player == null:
				_check("co nhan vat trong man", false)
				_finish()
				return true
			_arm = _player.get_node("SpringArm3D")
			return false
		2:
			# Xoay qua xoay lai bang gia tri gyro gia lap: moi lan dao huong
			# phai dua `spring_arm` ve dung gia do.
			var seen := []
			for gyro in [Vector3(0, 1.0, 0), Vector3(0, -1.0, 0), Vector3(0, 0.6, 0)]:
				_arm.rotation = Vector3.ZERO
				_sensor.feed_gyro(gyro, 0.016)
				_player._process(0.016)
				seen.append(_arm.rotation.y)
			_check("xoay phai doi goc nhin that su", seen[0] != 0.0)
			_check("nghieng nguoc phai ra dau doi chieu",
				signf(seen[0]) != signf(seen[1]) and seen[0] != seen[1],
				"(tram %.5f, phai %.5f)" % [seen[0], seen[1]])
			_check("cang manh thi xoay cang xa", absf(seen[0]) > absf(seen[2]),
				"(manh %.5f, yeu %.5f)" % [seen[0], seen[2]])
			_finish()
			quit(0 if _bad == 0 else 1)
			return true
	return false

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_bad += 1
	print("%-46s : %s %s" % [label, "OK" if ok else "LOI", detail])

func _finish() -> void:
	print("")
	print("=== TAT CA DUNG ===" if _bad == 0 else "=== %d LOI ===" % _bad)
	# Gỡ cờ TRƯỚC khi trả `save_path` về file thật, nếu không lần ghi của
	# `set_tilt_camera_enabled()` sẽ rơi vào save thật của người chơi.
	_live.set_tilt_camera_enabled(false)
	_live.save_path = _gm_save_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_SAVE))