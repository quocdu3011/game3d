extends Node3D

@export var gravity: float = 9.8
@export var lifetime: float = 8.0
@export var collision_mask: int = 1
@export var model_forward_correction_degrees: float = -90.0

var velocity: Vector3 = Vector3.ZERO
var _age := 0.0
var _previous_position := Vector3.ZERO

func launch(start_position: Vector3, initial_velocity: Vector3) -> void:
	global_position = start_position
	velocity = initial_velocity
	_previous_position = global_position
	_align_to_velocity()

func _ready() -> void:
	_previous_position = global_position
	_align_to_velocity()

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	_previous_position = global_position
	velocity.y -= gravity * delta
	var next_position := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(_previous_position, next_position, collision_mask)
	query.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		queue_free()
		return

	global_position = next_position
	_align_to_velocity()

func _align_to_velocity() -> void:
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity.normalized(), Vector3.UP)
		rotate_object_local(Vector3.RIGHT, deg_to_rad(model_forward_correction_degrees))
