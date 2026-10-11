extends Node3D

## Tên gọi mũi tên dùng để báo trúng. Xem `scripts/arrow_projectile.gd`.
const ARROW_HIT_METHOD := &"on_arrow_hit"

## Tile sẽ được di chuyển khi bắn trúng bia.
@export_node_path("Node3D") var moving_tile: NodePath
## Tile đích — `moving_tile` sẽ tới gần vị trí của nó.
@export_node_path("Node3D") var destination: NodePath
## Lệch vị trí so với `destination` (đơn vị world). Cao độ luôn giữ nguyên của
## `moving_tile` nên tile không bị nhảy lên rồi rơi xuống.
@export var destination_offset: Vector3 = Vector3(4.0, 0.0, 0.0)
## Thời gian (giây) tile trượt hết một đoạn đường.
@export var move_duration: float = 5.0

var _tile: Node3D
var _home_position := Vector3.ZERO
var _destination_position := Vector3.ZERO
var _is_at_destination := false
var _tween: Tween

func _ready() -> void:
	_tile = get_node_or_null(moving_tile) as Node3D
	var target := get_node_or_null(destination) as Node3D
	if _tile == null or target == null:
		push_warning("TargetStand cần cả moving_tile và destination trỏ tới node có sẵn.")
		return
	_home_position = _tile.global_position
	_destination_position = Vector3(
		target.global_position.x + destination_offset.x,
		_home_position.y,
		target.global_position.z + destination_offset.z)

## Mũi tên trúng bia: lần đầu đưa tile tới `destination`, lần sau đưa về chỗ cũ.
func on_arrow_hit(_arrow: Node3D) -> void:
	if _tile == null:
		return
	_is_at_destination = not _is_at_destination
	_move_tile(_destination_position if _is_at_destination else _home_position)

func _move_tile(target_position: Vector3) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_tile, "global_position", target_position, move_duration)
