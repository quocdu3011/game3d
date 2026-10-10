extends Area3D

class_name Checkpoint

signal activated(player: CharacterBody3D, spawn_position: Vector3)

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var inactive_flag: Node3D = $flag_teamBlue2
@onready var active_flag: Node3D = $ActivatedFlag
@onready var particles: GPUParticles3D = $CheckpointParticles
@onready var activation_light: OmniLight3D = $ActivationLight

var _is_activated := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	animation_player.animation_finished.connect(_on_animation_finished)
	var active_flag_mesh := active_flag.get_node("flag_teamRed") as MeshInstance3D
	var active_flag_material := load("res://scenes/Entity/Item/checkpoint_active_glow.tres") as Material
	if active_flag_mesh and active_flag_material:
		active_flag_mesh.material_override = active_flag_material
	inactive_flag.show()
	active_flag.hide()
	particles.emitting = false
	activation_light.hide()
	if animation_player.has_animation("idle"):
		animation_player.play("idle")

func _on_body_entered(body: Node3D) -> void:
	if _is_activated:
		return
	if not body is CharacterBody3D or not body.has_method("set_respawn_position"):
		return

	_is_activated = true
	set_deferred("monitoring", false)
	collision_shape.set_deferred("disabled", true)

	var player := body as CharacterBody3D
	player.set_respawn_position(spawn_point.global_position)
	activated.emit(player, spawn_point.global_position)

	inactive_flag.hide()
	active_flag.show()
	activation_light.show()
	particles.emitting = true
	particles.restart()

	if audio_player.stream:
		audio_player.play()
	if animation_player.has_animation("activate"):
		animation_player.play("activate")

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"activate" and animation_player.has_animation("active_idle"):
		animation_player.play("active_idle")
