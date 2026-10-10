extends Area3D

class_name FinishCheckpoint

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var particles: GPUParticles3D = $VictoryParticles
@onready var victory_light: OmniLight3D = $VictoryLight

var _is_activated := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	animation_player.animation_finished.connect(_on_animation_finished)
	particles.emitting = false
	victory_light.hide()
	if animation_player.has_animation("idle"):
		animation_player.play("idle")

func _on_body_entered(body: Node3D) -> void:
	if _is_activated or not body is CharacterBody3D:
		return

	_is_activated = true
	set_deferred("monitoring", false)
	collision_shape.set_deferred("disabled", true)
	particles.restart()
	particles.emitting = true
	victory_light.show()
	if animation_player.has_animation("activate"):
		animation_player.play("activate")

	var level := _find_level_controller()
	if level:
		level.call("_on_finish_body_entered", body)

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"activate" and animation_player.has_animation("idle"):
		animation_player.play("idle")

func _find_level_controller() -> Node:
	var current := get_parent()
	while current:
		if current.has_method("_on_finish_body_entered"):
			return current
		current = current.get_parent()
	return null
