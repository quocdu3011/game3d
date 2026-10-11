extends Node3D

class_name Bomb

## Bom an: dat vao map thi khong thay gi. Chi khi nguoi choi di qua `Trigger`
## thi bom moi hien len, den do nhap nhay + tia lua trong `fuse_time` giay de
## canh bao, roi no. Sau do nguoi choi bi day ve checkpoint va bom tu xoa.
##
## Khong co `StaticBody3D`: neu co, nguoi choi se dam vao tuong vo hinh o
## chinh noi bom vua hien len.

## Thoi gian cham nguoi chay truoc khi no (giay).
@export_range(0.1, 10.0, 0.05) var fuse_time: float = 1.0

## Luc day nguoi choi khi bom no. Dat 0 de tat day, chi hieu ung hinh anh.
@export_range(0.0, 50.0, 0.5) var blast_force: float = 12.0
## Doi luon giong am thanh no.
@export_range(-3.0, 3.0, 0.05) var pitch_scale: float = 1.0
## Cho bao lau truoc khi nguoi choi bi day ve checkpoint (giay).
@export_range(0.0, 3.0, 0.05) var respawn_delay: float = 0.4

@onready var trigger: Area3D = get_node_or_null("Trigger")
@onready var fuse_light: OmniLight3D = get_node_or_null("FuseLight")
@onready var sparks: GPUParticles3D = get_node_or_null("Sparks")
@onready var explosion: GPUParticles3D = get_node_or_null("Explosion")
@onready var smoke: GPUParticles3D = get_node_or_null("Smoke")
@onready var flash: OmniLight3D = get_node_or_null("Flash")
@onready var boom: AudioStreamPlayer3D = get_node_or_null("Boom")

## Node chua model bom. Scene dat ten la "Model", nhung fallback tim node 3D
## dau tien de khong phu thuoc ten.
@onready var model: Node3D = _find_model()

var _spent := false
var _fusing := false
var _fuse_elapsed := 0.0
var _player: CharacterBody3D

func _ready() -> void:
	# An bom ngay tu frame dau: scene duoc load o menu hay editor cung an.
	if model:
		model.visible = false
	for fx in [explosion, smoke, sparks]:
		if fx:
			fx.emitting = false
	for light in [fuse_light, flash]:
		if light:
			light.visible = false
	if trigger:
		trigger.body_entered.connect(_on_trigger_body_entered)

func _find_model() -> Node3D:
	var named := get_node_or_null("Model")
	if named is Node3D:
		return named
	for child in get_children():
		if child is Node3D:
			return child
	return null

func _process(delta: float) -> void:
	if not _fusing:
		return
	_fuse_elapsed += delta
	if _fuse_elapsed >= fuse_time:
		_fusing = false
		_explode()
		return
	_telegraph()

func _on_trigger_body_entered(body: Node3D) -> void:
	if _spent or _fusing or not body is CharacterBody3D:
		return
	# Player la doi tuong duy nhat co the cham no bomb.
	if not body.has_method("respawn_to_checkpoint"):
		return
	_ignite(body)

func _ignite(body: CharacterBody3D) -> void:
	_spent = true
	_fusing = true
	_fuse_elapsed = 0.0
	_player = body
	if trigger:
		# Khong gan `monitoring` truc tiep: dang chay trong `body_entered`
		# thi Godot chan ("Function blocked during in/out signal").
		trigger.set_deferred("monitoring", false)
	if model:
		model.visible = true
	if fuse_light:
		fuse_light.visible = true
	if sparks:
		sparks.emitting = true

## Hieu canh bao: nhap nhay dan theo phan tram cua thoi gian con lai (cham o
## dau, nhanh o sat giay cuoi), bom phong nhe theo cung nhip do.
func _telegraph() -> void:
	var t := clampf(_fuse_elapsed / maxf(fuse_time, 0.01), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_fuse_elapsed * lerpf(6.0, 30.0, t))
	if fuse_light:
		fuse_light.light_energy = lerpf(0.6, 4.5, pulse * t)
	if model:
		model.scale = Vector3.ONE * (1.0 + 0.14 * pulse * t)

func _explode() -> void:
	# Tat phan hieu canh bao truoc, giu lai phan no.
	if fuse_light:
		fuse_light.visible = false
	if sparks:
		sparks.emitting = false
	if model:
		model.scale = Vector3.ONE
		model.visible = false

	# Particler `one_shot` phai `restart()` moi bat lai.
	if explosion:
		explosion.restart()
		explosion.emitting = true
	if smoke:
		smoke.restart()
		smoke.emitting = true
	if flash:
		flash.visible = true
	if boom:
		boom.pitch_scale = pitch_scale
		boom.play()

	_knock_back(_player)

	if respawn_delay > 0.0:
		await get_tree().create_timer(respawn_delay).timeout
	_send_to_checkpoint()

	# Cho hat no no het roi moi xoa bom.
	var fx_life := 0.0
	if explosion:
		fx_life = maxf(fx_life, explosion.lifetime)
	if smoke:
		fx_life = maxf(fx_life, smoke.lifetime)
	if fx_life > 0.0:
		await get_tree().create_timer(fx_life).timeout
	if explosion:
		explosion.emitting = false
	if smoke:
		smoke.emitting = false
	if flash:
		flash.visible = false
	queue_free()

## Day nguoi choi ra xa. Chi client so huu player moi bi day — peer khac chi
## chay hieu ung hinh anh.
func _knock_back(body: CharacterBody3D) -> void:
	if body == null or blast_force <= 0.0:
		return
	if body.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	var offset := body.global_position - global_position
	offset.y = 0.0
	if offset.is_zero_approx():
		offset = Vector3.FORWARD
	var impulse := offset.normalized() * blast_force
	impulse.y = blast_force * 0.45
	if body.has_method("apply_knockback"):
		body.apply_knockback(impulse)

## Dua nguoi choi ve diem checkpoint da qua gan nhat. `player.gd` tu kiem tra
## quyen so huu multiplayer nen khong can lam gi them o day.
func _send_to_checkpoint() -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("respawn_to_checkpoint"):
		_player.respawn_to_checkpoint()
