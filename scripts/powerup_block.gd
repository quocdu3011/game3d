extends Node3D

class_name PowerupBlock

## Block bay: khi nguoi choi buoc len, ho duoc day thang len cao `launch_height`
## don vi. Mot don vi bang chieu cao cua mot TileLow — cung la mot "block".
##
## Khong sua `player.gd`: dung san hook `apply_knockback()` ma `RollingBall`
## da dung. Ham do gan `velocity.x = 0`, `velocity.z = 0` nen nguoi choi
## bị hất ngang — dung y cua mot block day len.
##
## Script nay khong dung `@tool`: chi chay khi game chay, dung 1 scene cho ca 3
## block, khac nhau o gia tri `launch_height` trong tung scene.

## Do cao day len (don vi). 4 / 7 / 10 cho Powerup_block_1 / _2 / _3.
@export_range(1.0, 20.0, 0.5) var launch_height: float = 4.0

## Toc do day len (don vi/s). De 0 = tu tinh tu `gravity` va `launch_height`
## de bay dung do cao da dinh. Dat tay khi can vuot qua trong ly cua Player.
@export_range(0.0, 40.0, 0.5) var launch_speed: float = 0.0

## Trong ly dung khi tinh `launch_speed`. Mac dinh khop voi `player.gd` (gravity 9.8).
@export var gravity: float = 9.8

## Cho phep buoc lai xuong roi day them sau khoang nay (ms). Cham de mot lan
## dat khong bi ban ra nhieu lan do Area3D phat sinh body_entered lap lai.
@export_range(0.0, 2000.0, 50.0) var cooldown_ms: float = 400.0

@onready var launch_area: Area3D = $LaunchArea

var _last_launch_ms := -1000000

func _ready() -> void:
	launch_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D or not body.has_method("apply_knockback"):
		return
	var now := Time.get_ticks_msec()
	if now - _last_launch_ms < cooldown_ms:
		return
	_last_launch_ms = now
	# `apply_knockback` giu nguyen toc do dung neu nguoi choi dang bay nhanh hon.
	body.apply_knockback(Vector3.UP * _effective_speed())

## Toc do toi thieu de bay cao `launch_height` tren trong ly `gravity`:
## h = v^2 / (2g)  =>  v = sqrt(2gh).
func _effective_speed() -> float:
	if launch_speed > 0.0:
		return launch_speed
	return sqrt(2.0 * gravity * launch_height)