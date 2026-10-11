extends CharacterBody3D

class_name Player

@export var speed: float = 6.0
@export var acceleration: float = 14.0
@export var friction: float = 14.0
@export var jump_velocity: float = 5.0
@export var gravity: float = 9.8
@export_range(2, 5, 1) var max_jumps: int = 2
@export_range(0.0, 1.0, 0.05) var max_step_height: float = 0.8
@export var respawn_y: float = 0.0
@export var mouse_sensitivity: float = 0.003
@export var touch_camera_sensitivity: float = 0.004
@export var camera_pitch_min: float = -75.0
@export var camera_pitch_max: float = 45.0
@export var third_person_distance: float = 3.5
@export var third_person_pivot_height: float = 1.4
@export var first_person_distance: float = 0.05
@export var first_person_pivot_height: float = 1.55
@export var third_person_fov: float = 75.0
@export var first_person_fov: float = 82.0
@export var bow_draw_time: float = 1.0
@export var bow_min_speed: float = 8.0
@export var bow_max_speed: float = 24.0
@export var bow_gravity: float = 9.8
@export var bow_preview_time: float = 2.4
@export var bow_preview_distance: float = 18.0
@export var bow_mount_position := Vector3(0.02, 0.12, 0.02)
@export var bow_mount_rotation := Vector3(0.0, 90.0, 90.0)
@export var bow_mount_scale: float = 0.32
@export var bow_muzzle_position := Vector3(0.0, 0.0, -1.45)
@export var first_person_arrow_origin_offset := Vector3(0.45, -0.32, -0.75)
@export var skin_name: String = "gobot":
	set(value):
		skin_name = value
		if is_node_ready():
			_load_skin(skin_name)

const BOW_SCENE_PATH = "res://scenes/Entity/Item/Bow_1.tscn"
const ARROW_SCENE_PATH = "res://scenes/Entity/Item/Arrow.tscn"

@onready var skin_slot: Node3D = $SkinSlot
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var current_skin_node: Node3D
var input_vector = Vector2.ZERO
var _jumps_remaining = 0
var _spawn_position = Vector3.ZERO
var _celebrating = false
## Đã chiến thắng: cấm dịch chuyển và nhảy. Phím di chuyển vẫn xoay được
## nhân vật. `level_controller` bật cờ này khi người chơi bước vào finish.
var _movement_locked := false
var _bow: Node3D
var _bow_mount: BoneAttachment3D
var _bow_muzzle: Marker3D
var _nocked_arrow: Node3D
var _trajectory_root: Node3D
var _trajectory_dots: Array[MeshInstance3D] = []
var _is_drawing = false
var _draw_elapsed = 0.0
var _locked_draw_horizontal_direction := Vector3.ZERO
var _has_locked_draw_direction := false
var _camera_touch_index := -1
var _active_touch_indices: Dictionary = {}
var _selected_slot = 1

## Mang theo vật thể đang di chuyển.
## Godot chỉ tự tính platform velocity cho AnimatableBody3D bật sync_to_physics;
## vật thể kéo bằng script (xoay, đổi chỗ, trượt…) không báo gì nên nhân vật đứng
## trên đó sẽ bị trượt khỏi. Ta tự lấy chênh lệch transform của vật thể đang ở
## dưới chân rồi áp thẳng lên mình — kể cả phần xoay, để nhân vật quay theo sàn xoay.
var _platform_body: Node3D = null
var _platform_transform := Transform3D.IDENTITY
var _platform_velocity := Vector3.ZERO

func play_victory() -> void:
	_celebrating = true
	if current_skin_node and current_skin_node.has_method("victory_sign"):
		current_skin_node.victory_sign()

func is_celebrating() -> bool:
	return _celebrating

## Khoá di chuyển + nhảy sau khi chiến thắng. Nhân vật vẫn đứng yên trên
## sàn và vẫn xoay được khi bấm phím di chuyển.
func lock_movement() -> void:
	_movement_locked = true

## Mở khoá lại (dùng khi bấm chơi lại cùng màn mà không reload scene).
func unlock_movement() -> void:
	_movement_locked = false

func is_movement_locked() -> bool:
	return _movement_locked

func set_respawn_position(new_position: Vector3) -> void:
	_spawn_position = new_position

func apply_knockback(impulse: Vector3) -> void:
	velocity.x = impulse.x
	velocity.z = impulse.z
	velocity.y = max(velocity.y, impulse.y)

func respawn_to_checkpoint() -> void:
	_respawn_at_start()

func _ready() -> void:
	_spawn_position = global_position
	_jumps_remaining = max_jumps
	floor_snap_length = 0.2
	apply_floor_snap()
	camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	skin_name = GameManager.selected_skin
	_load_skin(skin_name)
	_setup_bow()
	if not GameManager.camera_mode_changed.is_connected(_on_camera_mode_changed):
		GameManager.camera_mode_changed.connect(_on_camera_mode_changed)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		if hud.has_signal("bow_draw_started") and not hud.is_connected("bow_draw_started", _start_drawing):
			hud.connect("bow_draw_started", _start_drawing)
		if hud.has_signal("bow_draw_released") and not hud.is_connected("bow_draw_released", _release_drawing):
			hud.connect("bow_draw_released", _release_drawing)
	_apply_camera_mode(GameManager.camera_mode)

func _on_camera_mode_changed(mode: int) -> void:
	_apply_camera_mode(mode)

func _apply_camera_mode(mode: int) -> void:
	var first_person: bool = mode == GameManager.CameraMode.FIRST_PERSON
	spring_arm.spring_length = first_person_distance if first_person else third_person_distance
	spring_arm.position.y = first_person_pivot_height if first_person else third_person_pivot_height
	camera.fov = first_person_fov if first_person else third_person_fov
	_set_character_meshes_visible(current_skin_node, not first_person)

func _set_character_meshes_visible(root: Node, visible: bool) -> void:
	if root == null:
		return
	for child in root.get_children():
		if child == _bow_mount:
			continue
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = visible
		_set_character_meshes_visible(child, visible)

func _load_skin(s_name: String) -> void:
	if not skin_slot:
		return
	for child in skin_slot.get_children():
		child.queue_free()
	var skin_scene = load(GameManager.get_skin_path(s_name))
	if skin_scene:
		current_skin_node = skin_scene.instantiate()
		skin_slot.add_child(current_skin_node)
		if "walk_run_blending" in current_skin_node:
			current_skin_node.walk_run_blending = 1.0

func _setup_bow() -> void:
	if current_skin_node == null:
		return
	var scene: PackedScene = load(BOW_SCENE_PATH) as PackedScene
	var skeleton: Skeleton3D = _find_skeleton(current_skin_node)
	if scene == null or skeleton == null:
		return
	_bow_mount = BoneAttachment3D.new()
	_bow_mount.name = "BowHandAttachment"
	_bow_mount.bone_name = _find_right_hand_bone(skeleton)
	skeleton.add_child(_bow_mount)
	_bow = scene.instantiate()
	_bow.name = "EquippedBow"
	_bow_mount.add_child(_bow)
	_bow.position = bow_mount_position
	_bow.rotation_degrees = bow_mount_rotation
	_bow.scale = Vector3.ONE * bow_mount_scale
	_nocked_arrow = _bow.get_node_or_null("arrow_teamBlue2") as Node3D
	if _nocked_arrow:
		_nocked_arrow.visible = false
	_bow_muzzle = Marker3D.new()
	_bow_muzzle.name = "ArrowMuzzle"
	_bow_muzzle.position = bow_muzzle_position
	_bow.add_child(_bow_muzzle)
	_create_trajectory_dots()

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _find_right_hand_bone(skeleton: Skeleton3D) -> StringName:
	var candidates := [&"Hand.R", &"hand.R", &"RightHand", &"mixamorig_RightHand", &"LowerArm.R", &"forearm.R"]
	for candidate in candidates:
		if skeleton.find_bone(candidate) >= 0:
			return candidate
	return skeleton.get_bone_name(maxi(0, skeleton.get_bone_count() - 1))

func _create_trajectory_dots() -> void:
	_trajectory_root = Node3D.new()
	_trajectory_root.name = "ArrowTrajectory"
	add_child(_trajectory_root)
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.075
	dot_mesh.height = 0.15
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.82, 0.15, 1.0)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.04, 1.0)
	material.emission_energy_multiplier = 2.5
	dot_mesh.material = material
	for index in range(28):
		var dot := MeshInstance3D.new()
		dot.name = "TrajectoryDot%02d" % index
		dot.mesh = dot_mesh
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dot.visible = false
		_trajectory_root.add_child(dot)
		_trajectory_dots.append(dot)

func _hide_trajectory() -> void:
	for dot in _trajectory_dots:
		dot.visible = false

func _physics_process(delta: float) -> void:
	if global_position.y < respawn_y:
		_respawn_at_start()
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		_jumps_remaining = max_jumps
		if velocity.y < 0.0:
			velocity.y = -0.1
	var is_jumping = false
	var hud = get_tree().get_first_node_in_group("hud")
	var jump_pressed = Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept")
	if hud and hud.has_method("consume_virtual_jump"):
		jump_pressed = hud.consume_virtual_jump() or jump_pressed
	## Đã chiến thắng thì bỏ qua nhảy. Phải bỏ SAU khi gọi
	## `consume_virtual_jump()` o tren, neu khong nut ao tren man hinh se
	## giu nguyen trang thai "bam" va khong bao gio chay lai duoc.
	if _movement_locked:
		jump_pressed = false
	if jump_pressed and _jumps_remaining > 0:
		## Nhảy khỏi sàn đang chạy: giữ cả quán tính của vật thể để nhân vật
		## không bị tụt lại khi sàn trượt khỏi chân.
		velocity += _platform_velocity
		_platform_velocity = Vector3.ZERO
		velocity.y = jump_velocity
		_jumps_remaining -= 1
		is_jumping = true
		if current_skin_node and current_skin_node.has_method("jump"):
			current_skin_node.jump()
		SfxPlayer.play("jump")
	input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_vector == Vector2.ZERO:
		input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_vector == Vector2.ZERO:
		if hud and hud.has_method("get_virtual_move_input"):
			input_vector = hud.get_virtual_move_input()
	var direction = Vector3.ZERO
	if input_vector != Vector2.ZERO:
		var forward = -spring_arm.global_transform.basis.z
		var right = spring_arm.global_transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		direction = (forward.normalized() * -input_vector.y + right.normalized() * input_vector.x).normalized()
	if direction != Vector3.ZERO:
		if _movement_locked:
			## Đã thắng: giữ nguyên chỗ, chỉ chạy ma sát cho tốc độ cuộn
			## về 0. Nhân vật vẫn xoay theo hướng bấm ở dưới.
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		else:
			velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
		# Xoay nhân vật: có thực hiện cả khi đã khoá.
		if current_skin_node:
			current_skin_node.rotation.y = lerp_angle(current_skin_node.rotation.y, atan2(direction.x, direction.z), 15.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
	if not _movement_locked:
		_try_step_up(delta)
	move_and_slide()
	_carry_with_platform(delta)
	_update_animation_local(is_jumping)

## Dịch chuyển nhân vật theo đúng chênh lệch transform của vật thể đang đứng
## dưới chân. Vật thể xoay thì nhân vật xoay theo quanh chính vật thể đó.
func _carry_with_platform(delta: float) -> void:
	var collider := _platform_under_feet()
	if collider == null:
		_platform_body = null
		_platform_velocity = Vector3.ZERO
		return
	var current := collider.global_transform
	if _platform_body != collider:
		## Vừa bước lên vật thể mới: lấy transform hiện tại làm gốc, khung này
		## chưa có chênh lệch nào để bù.
		_platform_body = collider
		_platform_transform = current
		_platform_velocity = Vector3.ZERO
		return
	if _engine_carries_player(collider):
		## AnimatableBody3D đồng bộ vật lý: move_and_slide đã tự đưa nhân vật đi,
		## tự bù thêm sẽ nhân đôi độ dời.
		_platform_transform = current
		return
	var motion := current * _platform_transform.affine_inverse()
	_platform_transform = current
	_platform_velocity = motion.origin / maxf(delta, 0.0001)
	global_transform = motion * global_transform

## Vật thể đang đỡ dưới chân.
## Ưu tiên collider của slide collision, nhưng KHI ĐỨNG YÊN move_and_slide
## không sinh va chạm nào (slide list rỗng) — lúc đó phải dò bằng ray từ
## dưới chân lên. Godot 4.7 cũng không có get_platform_collider().
func _platform_under_feet() -> Node3D:
	if not is_on_floor():
		return null
	var floor_normal := get_floor_normal()
	if not floor_normal.is_zero_approx():
		for index in get_slide_collision_count():
			var collision := get_slide_collision(index)
			if collision.get_normal().dot(floor_normal) > 0.7:
				return collision.get_collider() as Node3D
	## Capsule người chơi đặt từ y=0 trở lên nên ray bắt đầu hơi cao hơn gốc.
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.2, global_position - Vector3.UP * 0.6)
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit["normal"] as Vector3).dot(get_up_direction()) < 0.7:
		return null
	return hit["collider"] as Node3D

## Engine chỉ tự mang nhân vật theo AnimatableBody3D bật sync_to_physics.
func _engine_carries_player(collider: Node3D) -> bool:
	return collider is AnimatableBody3D and (collider as AnimatableBody3D).sync_to_physics

func _process(_delta: float) -> void:
	if _is_drawing:
		_draw_elapsed = min(_draw_elapsed + _delta, bow_draw_time)
		_update_trajectory()

func _try_step_up(delta: float) -> void:
	if max_step_height <= 0.0 or not is_on_floor():
		return
	var horizontal_velocity = Vector3(velocity.x, 0.0, velocity.z)
	if horizontal_velocity.length_squared() < 0.01:
		return
	var horizontal_motion = horizontal_velocity * delta
	var start_transform = global_transform
	if not test_move(start_transform, horizontal_motion) or test_move(start_transform, Vector3.UP * max_step_height):
		return
	var raised_transform = start_transform.translated(Vector3.UP * max_step_height)
	if test_move(raised_transform, horizontal_motion):
		return
	var floor_collision = KinematicCollision3D.new()
	if not test_move(raised_transform.translated(horizontal_motion), Vector3.DOWN * (max_step_height + floor_snap_length), floor_collision):
		return
	var landing_height = max_step_height + floor_collision.get_travel().y
	if landing_height > 0.01 and landing_height <= max_step_height:
		global_position.y += landing_height + 0.01

func _respawn_at_start() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_jumps_remaining = max_jumps
	_platform_body = null
	_platform_transform = Transform3D.IDENTITY
	_platform_velocity = Vector3.ZERO

func _update_animation_local(is_jumping_this_frame: bool) -> void:
	if not current_skin_node or _celebrating:
		return
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if "walk_run_blending" in current_skin_node:
		current_skin_node.walk_run_blending = clamp(horizontal_speed / speed, 0.0, 1.0)
	if is_on_floor() and not is_jumping_this_frame:
		if horizontal_speed > 0.2 and current_skin_node.has_method("move"):
			current_skin_node.move()
		elif current_skin_node.has_method("idle"):
			current_skin_node.idle()
	elif not is_on_floor() and velocity.y < -1.0 and current_skin_node.has_method("fall"):
		current_skin_node.fall()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_active_touch_indices[event.index] = true
			if _camera_touch_index == -1:
				var touch_hud = get_tree().get_first_node_in_group("hud")
				if touch_hud == null or not touch_hud.has_method("can_use_camera_touch_at") or touch_hud.can_use_camera_touch_at(event.position):
					_camera_touch_index = event.index
		else:
			_active_touch_indices.erase(event.index)
			if event.index == _camera_touch_index:
				_camera_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _camera_touch_index:
		spring_arm.rotation.y -= event.relative.x * touch_camera_sensitivity
		spring_arm.rotation.x = clamp(spring_arm.rotation.x - event.relative.y * touch_camera_sensitivity, deg_to_rad(camera_pitch_min), deg_to_rad(camera_pitch_max))
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_start_drawing()
			else:
				_release_drawing()
	if event is InputEventMouseMotion and _active_touch_indices.is_empty() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and _camera_touch_index == -1:
		spring_arm.rotation.y -= event.relative.x * mouse_sensitivity
		spring_arm.rotation.x = clamp(spring_arm.rotation.x - event.relative.y * mouse_sensitivity, deg_to_rad(camera_pitch_min), deg_to_rad(camera_pitch_max))
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			_selected_slot = event.keycode - KEY_0
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("select_inventory_slot"):
				hud.select_inventory_slot(_selected_slot)

func _start_drawing() -> void:
	if _selected_slot != 1 or _is_drawing or _bow == null:
		return
	_is_drawing = true
	_draw_elapsed = 0.0
	_has_locked_draw_direction = GameManager.camera_mode == GameManager.CameraMode.THIRD_PERSON
	if _has_locked_draw_direction:
		var camera_forward := -camera.global_transform.basis.z.normalized()
		_locked_draw_horizontal_direction = Vector3(camera_forward.x, 0.0, camera_forward.z).normalized()
	else:
		_locked_draw_horizontal_direction = Vector3.ZERO
	if _nocked_arrow:
		_nocked_arrow.visible = true
	_update_trajectory()

func _release_drawing() -> void:
	if not _is_drawing:
		return
	_is_drawing = false
	for dot in _trajectory_dots:
		dot.visible = false
	if _nocked_arrow:
		_nocked_arrow.visible = false
	var strength: float = clampf(_draw_elapsed / maxf(bow_draw_time, 0.01), 0.0, 1.0)
	_fire_arrow(strength)
	_has_locked_draw_direction = false
	_locked_draw_horizontal_direction = Vector3.ZERO
	_draw_elapsed = 0.0

func _get_arrow_start_position() -> Vector3:
	if GameManager.camera_mode == GameManager.CameraMode.FIRST_PERSON:
		return camera.to_global(first_person_arrow_origin_offset)
	if _bow_muzzle:
		return _bow_muzzle.global_position
	return camera.global_position

func _get_arrow_launch_direction() -> Vector3:
	var camera_forward := -camera.global_transform.basis.z.normalized()
	if not _has_locked_draw_direction or GameManager.camera_mode != GameManager.CameraMode.THIRD_PERSON:
		return camera_forward
	var horizontal_amount := Vector2(camera_forward.x, camera_forward.z).length()
	return (_locked_draw_horizontal_direction * horizontal_amount + Vector3.UP * camera_forward.y).normalized()

func _fire_arrow(strength: float) -> void:
	var scene: PackedScene = load(ARROW_SCENE_PATH) as PackedScene
	if scene == null or get_tree().current_scene == null or _bow_muzzle == null:
		return
	var arrow: Node3D = scene.instantiate() as Node3D
	get_tree().current_scene.add_child(arrow)
	var direction: Vector3 = _get_arrow_launch_direction()
	var start: Vector3 = _get_arrow_start_position()
	arrow.launch(start, direction * lerpf(bow_min_speed, bow_max_speed, strength))

func _update_trajectory() -> void:
	if _bow_muzzle == null or _trajectory_dots.is_empty():
		return
	_hide_trajectory()
	var direction: Vector3 = _get_arrow_launch_direction()
	var start: Vector3 = _get_arrow_start_position()
	var strength: float = clampf(_draw_elapsed / maxf(bow_draw_time, 0.01), 0.0, 1.0)
	var launch_velocity: Vector3 = direction * lerpf(bow_min_speed, bow_max_speed, strength)
	var previous: Vector3 = start
	for index in range(_trajectory_dots.size()):
		var t: float = bow_preview_time * float(index) / float(maxi(1, _trajectory_dots.size() - 1))
		var point: Vector3 = start + launch_velocity * t + Vector3.DOWN * bow_gravity * t * t * 0.5
		if start.distance_to(point) > bow_preview_distance:
			break
		var dot: MeshInstance3D = _trajectory_dots[index]
		if index > 0:
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(previous, point, 1)
			query.exclude = [self]
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				dot.global_position = hit.position
				dot.visible = true
				break
		dot.global_position = point
		dot.visible = true
		previous = point
