extends SceneTree

## Chụp HUD khi đang chơi để soi vùng joystick. Vùng chạm mới rộng cả góc dưới
## bên trái nên không nhìn thấy bằng mắt được — ta vẽ thêm khung vùng chạm để
## kiểm tra nó đúng 1/4 chiều ngang và 1/2 chiều dọc.

const OUT_DIR := "user://__shots"
const SIZE := Vector2i(1152, 648)

var _step := 0
var _hud: CanvasLayer
var _markers: Control

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	match _step:
		0:
			_step = 1
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
			root.size = SIZE
			root.content_scale_size = SIZE
			_hud = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
			root.add_child(_hud)
			return false
		1:
			if int(Engine.get_process_frames()) < 6:
				return false
			_step = 2
			_draw_touch_zone()
			return false
		2:
			if int(Engine.get_process_frames()) < 10:
				return false
			_step = 3
			_shoot("hud_joystick_zone")
			# Giữ một ngón tay ở góc dưới bên trái: nút tròn phải bấm lên đúng
			# chỗ chạm (đó là điểm khác biệt của chế độ Dynamic).
			_touch_at(Vector2(190.0, 560.0), true)
			return false
		3:
			if int(Engine.get_process_frames()) < 16:
				return false
			_step = 4
			_shoot("hud_joystick_touching")
			_touch_at(Vector2(190.0, 560.0), false)
			return false
		4:
			if int(Engine.get_process_frames()) < 20:
				return false
			_step = 5
			_shoot("hud_joystick_released")
			print("=== DONE ===")
			quit(0)
			return true
	return false

func _touch_at(pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = pos
	event.pressed = pressed
	root.push_input(event)

## Vẽ đường viền đỏ quanh vùng chạm của joystick để dễ đối chiếu.
func _draw_touch_zone() -> void:
	_markers = Control.new()
	_markers.name = "TouchZoneMarker"
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.draw.connect(_on_marker_draw)
	_hud.add_child(_markers)
	_markers.queue_redraw()

func _on_marker_draw() -> void:
	var js := _hud.get_node("VirtualJoystick") as Control
	var r := js.get_global_rect()
	_markers.draw_rect(r, Color(1, 0.25, 0.25, 0.85), false, 3.0)
	_markers.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y),
		Color(1, 1, 0.3, 0.5), 1.0)
	_markers.draw_string(ThemeDB.fallback_font, r.position + Vector2(8, 22),
		"vung cham joystick", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.35, 0.35))

func _shoot(name: String) -> void:
	_markers.queue_redraw()
	var img := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	var err := img.save_png(path)
	print("%s -> %s (%s)" % [name, ProjectSettings.globalize_path(path),
		"OK" if err == OK else "LOI %d" % err])