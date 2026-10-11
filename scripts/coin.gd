extends Node3D

class_name Coin

## Đồng tiền nhặt được. Người chơi chạm vào `Area3D` là nhặt: cộng vào
## `GameManager.coins`, lưu ngay, báo số qua `coin_collected`, rồi biến mất.
##
## Không dùng `AnimationPlayer` như CheckPoint: đồng tiền chỉ tự xoay quanh
## trục Y và bay lên, làm bằng code gọn hơn nhiều.

signal coin_collected(amount: int)

## Số tiền một đồng mang lại.
@export var value: int = 1
## Tốc độ xoay (độ/giây).
@export_range(0.0, 360.0, 1.0) var spin_speed: float = 110.0
## Bán kính vùng nhặt (đơn vị). Rộng hơn hình thể một chút cho dễ trúng.
@export_range(0.2, 5.0, 0.05) var pickup_radius: float = 1.2
## Độ cao bay lên khi nhặt (đơn vị).
@export_range(0.0, 5.0, 0.1) var pop_height: float = 0.9
## Thời gian bay + mờ dần trước khi xoá (giây).
@export_range(0.1, 2.0, 0.05) var collect_time: float = 0.35

@onready var mesh: Node3D = get_node_or_null("Mesh")
@onready var pickup: Area3D = get_node_or_null("Pickup")

var _taken := false
var _collect_t := 0.0
var _collecting := false
var _base_y := 0.0

func _ready() -> void:
	_base_y = position.y
	if mesh:
		# Xoay ngẫu nhiên theo trục Y để hàng coin trông tự nhiên.
		mesh.rotation.y = randf() * TAU
	if pickup:
		pickup.body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _collecting:
		_collect_t += delta
		var t := clampf(_collect_t / maxf(collect_time, 0.01), 0.0, 1.0)
		# Bay lên rồi mờ dần; xoá khi hết.
		position.y = _base_y + pop_height * sin(t * PI * 0.5)
		if mesh:
			mesh.scale = Vector3.ONE * (1.0 - t * 0.6)
			mesh.visible = t < 0.98
		if t >= 1.0:
			queue_free()
		return
	if mesh:
		mesh.rotation.y += deg_to_rad(spin_speed) * delta

func _on_body_entered(body: Node3D) -> void:
	if _taken or not body is CharacterBody3D:
		return
	_taken = true
	_collecting = true
	if pickup:
		# Tắt ngay để không nhặt trùng trong các frame còn chồng va chạm.
		pickup.set_deferred("monitoring", false)
	GameManager.add_coins(value)
	coin_collected.emit(value)

## Cho phép đặt coin nhưng bắt đầu ẩn (dùng cho phần thưởng ẩn trong map).
func set_active(active: bool) -> void:
	_taken = not active
	_collecting = false
	_collect_t = 0.0
	visible = active
	if pickup:
		pickup.monitoring = active