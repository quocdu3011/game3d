extends Node3D

## Method mà node bị mũi tên trúng phải implement để nhận thông báo.
## Xem `scripts/target_stand.gd` làm ví dụ.
const ARROW_HIT_METHOD := &"on_arrow_hit"

@export var gravity: float = 9.8
@export var lifetime: float = 8.0
## Thời gian mũi tên cắm trên vật thể sau khi chạm (giây), rồi mới biến mất.
@export var stuck_lifetime: float = 10.0
## Độ sâu đầu mũi tên cắm vào vật thể (đơn vị world) sau khi chạm.
@export var stuck_depth: float = 0.4
@export var collision_mask: int = 1
@export var model_forward_correction_degrees: float = -90.0

var velocity: Vector3 = Vector3.ZERO
var _age := 0.0
var _stuck_age := 0.0
var _previous_position := Vector3.ZERO
var _is_stuck := false

func launch(start_position: Vector3, initial_velocity: Vector3) -> void:
	global_position = start_position
	velocity = initial_velocity
	_previous_position = global_position
	_align_to_velocity()

func _ready() -> void:
	_previous_position = global_position
	_align_to_velocity()

func _physics_process(delta: float) -> void:
	if _is_stuck:
		_stuck_age += delta
		if _stuck_age >= stuck_lifetime:
			queue_free()
		return

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
		_stick(hit)
		return

	global_position = next_position
	_align_to_velocity()

## Mũi tên vừa chạm vật thể: dừng bay, cắm vào vật thể và báo cho nó biết.
func _stick(hit: Dictionary) -> void:
	var travel_direction := Vector3.ZERO
	if velocity.length_squared() > 0.01:
		travel_direction = velocity.normalized()
		_align_to_velocity()
		global_position -= travel_direction * stuck_depth
	velocity = Vector3.ZERO
	_is_stuck = true
	_stuck_age = 0.0
	_notify_hit(hit.get("collider") as Object)

## Gọi `ARROW_HIT_METHOD` trên chính vật thể bị trúng, hoặc trên node cha gần nhất
## có method đó.
func _notify_hit(collider: Object) -> void:
	var node := collider as Node
	while node != null:
		if node.has_method(ARROW_HIT_METHOD):
			node.call(ARROW_HIT_METHOD, self)
			return
		node = node.get_parent()

func _align_to_velocity() -> void:
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity.normalized(), Vector3.UP)
		rotate_object_local(Vector3.RIGHT, deg_to_rad(model_forward_correction_degrees))