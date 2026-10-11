extends Node3D

class_name BallSpawner

@export var ball_scene: PackedScene = preload("res://scenes/Entity/Item/Ball.tscn")
@export_range(0.1, 60.0, 0.1) var spawn_interval: float = 3.0
@export var spawn_immediately: bool = true

@onready var timer: Timer = $Timer
@onready var spawn_points: Array[Node] = $SpawnPoints.get_children()

var _random := RandomNumberGenerator.new()
var _spawn_count := 0

func _ready() -> void:
	_random.randomize()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_spawn_ball)
	if spawn_immediately:
		_spawn_ball.call_deferred()
	timer.start()

func _spawn_ball() -> void:
	if ball_scene == null or spawn_points.is_empty():
		return
	var marker := spawn_points[_random.randi_range(0, spawn_points.size() - 1)] as Marker3D
	if marker == null:
		return
	var ball := ball_scene.instantiate() as RigidBody3D
	if ball == null:
		return
	_spawn_count += 1
	ball.name = "RollingBall%d" % _spawn_count
	get_parent().add_child(ball)
	ball.global_transform = marker.global_transform
