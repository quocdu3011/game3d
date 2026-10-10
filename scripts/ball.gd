extends RigidBody3D

class_name RollingBall

@export var knockback_force: float = 12.0
@export var knockback_upward_force: float = 4.0
@export var maximum_lifetime: float = 15.0

var _is_disappearing := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(maximum_lifetime).timeout.connect(_despawn)

func _on_body_entered(body: Node) -> void:
	if _is_disappearing:
		return

	if body is CharacterBody3D and body.has_method("apply_knockback"):
		var player := body as CharacterBody3D
		var direction: Vector3 = player.global_position - global_position
		direction.y = 0.0
		if direction.is_zero_approx():
			direction = -linear_velocity
			direction.y = 0.0
		if direction.is_zero_approx():
			direction = Vector3.LEFT
		var impulse: Vector3 = direction.normalized() * knockback_force
		impulse.y = knockback_upward_force
		player.apply_knockback(impulse)
		return

	if body is StaticBody3D and _is_ground_body(body):
		_despawn()

func _is_ground_body(body: Node) -> bool:
	var owner_node := body.get_parent()
	if owner_node == null:
		return true
	var owner_name := owner_node.name.to_lower()
	return not owner_name.begins_with("tileslope") and not owner_name.begins_with("barier")

func _despawn() -> void:
	if _is_disappearing:
		return
	_is_disappearing = true
	queue_free()
