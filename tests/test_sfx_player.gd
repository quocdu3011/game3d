@tool
extends McpTestSuite

# Hồi quy cho phần hiệu ứng âm thanh:
#  - Tên gọi trong code phải khớp với registry, không có lỗi gõ.
#  - File âm thanh phải tồn tại và KHÔNG loop (SFX là tiếng một lần).

const SFX_SCRIPT := "res://scripts/sfx_player.gd"

## Những tên mà game thực sự gọi. Nếu đổi registry mà quên sửa call site,
## test này đỏ.
const CALLED_NAMES: Array[String] = ["jump", "game_start", "game_winner"]

var _sfx: Node

func suite_name() -> String:
	return "sfx_player"

func setup() -> void:
	var script: GDScript = load(SFX_SCRIPT)
	_sfx = script.new()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child(_sfx)

func teardown() -> void:
	if _sfx != null and is_instance_valid(_sfx):
		_sfx.free()
	_sfx = null

func test_all_called_sounds_are_registered() -> void:
	for name in CALLED_NAMES:
		assert_true(_sfx.SOUNDS.has(name), "Chua dang ky SFX: %s" % name)

func test_sound_files_exist() -> void:
	for name in _sfx.SOUNDS:
		var path: String = _sfx.SOUNDS[name]
		assert_true(ResourceLoader.exists(path), "Thieu file SFX: %s (%s)" % [name, path])

func test_sfx_do_not_loop() -> void:
	# SFX là tiếng một lần; bật loop sẽ kéo dài tiếng vô hạn.
	for name in _sfx.SOUNDS:
		var stream := load(_sfx.SOUNDS[name]) as AudioStreamMP3
		if stream != null:
			assert_false(stream.loop, "SFX khong duoc loop: %s" % name)

func test_unknown_sound_name_starts_nothing() -> void:
	# Gõ sai tên ở call site không được làm hỏng game, cũng không được âm thầm
	# chiếm một slot trong pool.
	for player in _sfx._pool:
		player.stop()
	_sfx.play("khong_ton_tai")
	for i in _sfx._pool.size():
		assert_false(_sfx._pool[i].playing, "Ten sai khong duoc phat gi ca slot %d" % i)

func test_pool_is_prefilled_for_overlapping_sounds() -> void:
	var expected: int = _sfx.POOL_SIZE
	assert_eq(_sfx._pool.size(), expected, "Pool phai du so slot de chong tieng")
	for player in _sfx._pool:
		assert_true(player is AudioStreamPlayer, "Moi slot phai la AudioStreamPlayer")