extends Node3D

@export_range(-720.0, 720.0, 1.0, "suffix:deg/s")
var rotation_speed_degrees: float = 90.0

func _physics_process(delta: float) -> void:
	rotate_y(deg_to_rad(rotation_speed_degrees) * delta)
