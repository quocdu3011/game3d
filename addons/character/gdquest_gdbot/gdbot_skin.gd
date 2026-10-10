extends Node3D

## Emitted when Gobot's feet hit the ground will running.
@warning_ignore("unused_signal")
signal stepped

## Represents the blending between the walking and running animations.
## It can be set to different values (e.g. 0.0 to 1.0) to adjust the balance between
## the two animations, resulting in the model appearing to walk or run depending on the value.
@export_range(0.0, 1.0, 0.01) var walk_run_blending = 0.0:
	set = set_walk_run_blending

## Determines whether blinking is enabled or disabled.
@export var is_blinking := true:
	set = set_blinking

@onready var _animation_tree: AnimationTree = %AnimationTree
@onready var _main_state_machine: AnimationNodeStateMachinePlayback = _animation_tree.get("parameters/StateMachine/playback") if _animation_tree else null
@onready var _walk_run_blend_amount := "parameters/StateMachine/Move/WalkRunBlending/blend_amount"
@onready var _step_time_scale := "parameters/StateMachine/Move/StepTimeScale/scale"
@onready var _attack_one_shot := "parameters/AttackOneShot/request"
@onready var _face: Node2D = %GDbotFace

var _walk_run_ratio: float = 1.0


func _ready() -> void:
	if _animation_tree:
		var walk_anim = _animation_tree.get_animation("walk") if _animation_tree.has_animation("walk") else null
		var run_anim = _animation_tree.get_animation("run") if _animation_tree.has_animation("run") else null
		if walk_anim and run_anim and run_anim.length > 0:
			_walk_run_ratio = walk_anim.length / run_anim.length
	walk_run_blending = walk_run_blending
	is_blinking = is_blinking


func set_blinking(new_is_blinking: bool) -> void:
	is_blinking = new_is_blinking
	if not is_node_ready():
		return
	if is_blinking:
		set_face("default")
	else:
		set_face("sleepy")


func set_walk_run_blending(value: float) -> void:
	walk_run_blending = clampf(value, 0.0, 1.0)
	if not is_node_ready():
		return
	if _animation_tree:
		_animation_tree.set(_walk_run_blend_amount, walk_run_blending)
		_animation_tree.set(_step_time_scale, lerpf(1.0, _walk_run_ratio, walk_run_blending))


## Sets the model to a neutral, action-free state.
func idle() -> void:
	if _main_state_machine:
		_main_state_machine.travel("Idle")


## Sets the model to a walking or running animation or forward movement.
func move() -> void:
	if _main_state_machine:
		_main_state_machine.travel("Move")


## Sets the model to an upward-leaping animation, simulating a jump.
func jump() -> void:
	if _main_state_machine:
		_main_state_machine.travel("Jump")


## Sets the model to a downward animation, imitating a fall.
func fall() -> void:
	if _main_state_machine:
		_main_state_machine.travel("Fall")


## Sets the model to an edge-grabbing animation.
func edge_grab() -> void:
	if _main_state_machine:
		_main_state_machine.travel("EdgeGrab")


## Sets the model to a wall-sliding animation.
func wall_slide() -> void:
	if _main_state_machine:
		_main_state_machine.travel("WallSlide")


## Plays a one-shot flip or attack animation.
func flip() -> void:
	attack()


## Makes a victory sign.
func victory_sign() -> void:
	set_face("happy")
	if _main_state_machine:
		_main_state_machine.travel("VictorySign")


## Plays a one-shot hurt animation.
func hurt() -> void:
	set_face("dizzy")
	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3(1.2, 0.8, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.2)
	tween.finished.connect(func(): set_face("default"))


func attack() -> void:
	if _animation_tree:
		_animation_tree.set(_attack_one_shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Changes the model's facial expression based on the provided input string values.
func set_face(face_name: String) -> void:
	if _face and _face.has_method("_set_face"):
		_face._set_face(face_name)


