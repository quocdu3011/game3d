extends Node3D

# Script điều khiển cơ bản cho các màn chơi (Level 1, 2, 3, 4...)

@export var player_scene: PackedScene = preload("res://scenes/player.tscn")

@onready var players_container: Node3D = $Players

## Thời gian đã chơi của màn (giây). Cộng dồn bằng delta nên thời gian mở
## menu tạm dừng KHÔNG bị tính — người chơi không bị mất sao vì tạm dừng.
var _elapsed := 0.0
var _finished := false

## Thời gian hoàn thành màn hiện tại (0 nếu chưa xong).
func _process(delta: float) -> void:
	if not _finished:
		_elapsed += delta


var _hud: CanvasLayer

func _ready() -> void:
	_hud = get_node_or_null("HUD") as CanvasLayer
	SfxPlayer.play("game_start")
	_spawn_player()

func _level_number() -> int:
	var parsed := name.trim_prefix("Level").to_int()
	return parsed if parsed > 0 else GameManager.current_level

func _on_finish_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return
	if body.has_method("play_victory"):
		body.play_victory()
	# Đã chiến thắng: cấm đi và nhảy, phím di chuyển chỉ còn xoay nhân vật.
	if body.has_method("lock_movement"):
		body.lock_movement()
	_finish_level()

## Chốt màn: ghi sao, tiếng thắng, rồi mở màn hoàn thành.
func _finish_level() -> void:
	if _finished:
		return
	_finished = true
	var level_num := _level_number()
	var stars := GameManager.stars_for_time(level_num, _elapsed)
	GameManager.mark_level_completed(level_num)
	GameManager.record_stars(level_num, stars)
	SfxPlayer.play("game_winner")
	if _hud and _hud.has_method("show_level_complete"):
		_hud.show_level_complete(level_num, stars, _elapsed)

func _spawn_player() -> void:
	if not player_scene or not players_container:
		return

	var player = player_scene.instantiate()
	player.name = "1"
	players_container.add_child(player)
	player.global_position = players_container.global_position
