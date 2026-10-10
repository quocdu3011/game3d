extends Node3D

@export_range(-720.0, 720.0, 1.0, "suffix:deg/s")
var rotation_speed_degrees: float = 120.0

@onready var hitbox: Area3D = $Hitbox

func _ready() -> void:
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
	rotate_y(deg_to_rad(rotation_speed_degrees) * delta)

func _on_hitbox_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("respawn_to_checkpoint"):
		body.respawn_to_checkpoint()
