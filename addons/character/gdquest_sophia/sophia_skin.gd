extends Node3D

## Emitted when Gobot's feet hit the ground will running.
@warning_ignore("unused_signal")
signal stepped

## Represents the blending between the walking and running animations.
@export_range(0.0, 1.0, 0.01) var walk_run_blending = 0.0:
	set = set_walk_run_blending

## Use it to make the move animation lean left (-1.0), right (1.0) or straight (0.0).
@export_range(-1.0, 1.0, 0.01) var run_tilt = 0.0:
	set = set_run_tilt

## Determines whether blinking is enabled or disabled.
@export var is_blinking = true:
	set = set_is_blinking

@onready var _animation_tree = %AnimationTree
@onready var _state_machine: AnimationNodeStateMachinePlayback = _animation_tree.get("parameters/playback") if _animation_tree else null
@onready var _move_tilt_path: String = "parameters/Move/tilt/add_amount"
@onready var _blink_timer = %BlinkTimer
@onready var _closed_eyes_timer = %ClosedEyesTimer
@onready var _eye_mat = $sophia/rig/Skeleton3D/Sophia.get("surface_material_override/1") if has_node("sophia/rig/Skeleton3D/Sophia") else null


func _ready() -> void:
	walk_run_blending = walk_run_blending
	run_tilt = run_tilt
	is_blinking = is_blinking

	if _blink_timer and _closed_eyes_timer:
		_blink_timer.timeout.connect(
			func() -> void:
				if _eye_mat:
					_eye_mat.set("uv1_offset", Vector3(0.0, 0.5, 0.0))
				_closed_eyes_timer.start(0.2)
		)

		_closed_eyes_timer.timeout.connect(
			func() -> void:
				if _eye_mat:
					_eye_mat.set("uv1_offset", Vector3.ZERO)
				_blink_timer.start(randf_range(1.0, 4.0))
		)


func set_is_blinking(new_is_blinking: bool) -> void:
	is_blinking = new_is_blinking
	if not is_node_ready():
		return

	if is_blinking:
		if _blink_timer:
			_blink_timer.start(0.2)
	else:
		if _blink_timer:
			_blink_timer.stop()
		if _closed_eyes_timer:
			_closed_eyes_timer.stop()


func set_walk_run_blending(value: float) -> void:
	walk_run_blending = clampf(value, 0.0, 1.0)
	if not is_node_ready():
		return
	if _animation_tree and _animation_tree.get("parameters/Move/WalkRunBlending/blend_amount") != null:
		_animation_tree.set("parameters/Move/WalkRunBlending/blend_amount", walk_run_blending)


func set_run_tilt(value: float) -> void:
	run_tilt = clamp(value, -1.0, 1.0)
	if not is_node_ready():
		return
	if _animation_tree:
		_animation_tree.set(_move_tilt_path, run_tilt)


func idle() -> void:
	if _state_machine:
		_state_machine.travel("Idle")


func move() -> void:
	if _state_machine:
		_state_machine.travel("Move")


func fall() -> void:
	if _state_machine:
		_state_machine.travel("Fall")


func jump() -> void:
	if _state_machine:
		_state_machine.travel("Jump")


func edge_grab() -> void:
	if _state_machine:
		_state_machine.travel("EdgeGrab")


func wall_slide() -> void:
	if _state_machine:
		_state_machine.travel("WallSlide")


func flip() -> void:
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees:x", 360.0, 0.4).from(0.0)


func victory_sign() -> void:
	if _state_machine:
		_state_machine.travel("VictorySign")


func hurt() -> void:
	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3(1.2, 0.8, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.2)
