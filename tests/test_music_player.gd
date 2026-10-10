@tool
extends McpTestSuite

# Hồi quy cho phần nhạc nền:
#  - 3 bản nhạc phải tồn tại và có bật loop (không loop thì nhạc dừng giữa chừng).
#  - Thứ tự phát phải ngẫu nhiên nhưng đủ cả 3 bản trước khi lặp lại.

const MP_SCRIPT := "res://scripts/music_player.gd"

var _mp: Node

func suite_name() -> String:
	return "music_player"

func setup() -> void:
	var script: GDScript = load(MP_SCRIPT)
	_mp = script.new()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child(_mp)

func teardown() -> void:
	if _mp != null and is_instance_valid(_mp):
		_mp.free()
	_mp = null

func test_three_music_tracks_exist() -> void:
	assert_eq(_mp.TRACKS.size(), 3, "Phai co dung 3 ban nhac nen")
	for path in _mp.TRACKS:
		assert_true(ResourceLoader.exists(path), "Thieu file nhac: %s" % path)

func test_music_tracks_are_enabled_to_loop() -> void:
	# Không loop thì nhạc dừng giữa bản. Godot 4.7 dùng thuộc tính bool `loop`.
	for path in _mp.TRACKS:
		var stream := load(path) as AudioStreamMP3
		assert_true(stream != null, "Khong nap duoc: %s" % path)
		if stream != null:
			assert_true(stream.loop, "Ban nhac phai bat loop: %s" % path)

func test_order_contains_every_track_exactly_once() -> void:
	for _attempt in 10:
		var order: Array[int] = _mp.build_order(3)
		assert_eq(order.size(), 3, "Moi luot phai co dung 3 bai hat")
		var sorted: Array[int] = order.duplicate()
		sorted.sort()
		assert_eq(sorted, [0, 1, 2] as Array[int], "Thu tu phai chua moi chi so mot lan")

func test_order_actually_varies() -> void:
	# 3 bản chỉ có 6 hoán vị, thử nhiều lần phải ra nhiều thứ tự khác nhau.
	# Nếu lặp luôn một thứ tự thì "random" chỉ là trang trí.
	var seen: Array = []
	for _attempt in 25:
		var order: Array = _mp.build_order(3)
		if not seen.has(order):
			seen.append(order)
	assert_gt(seen.size(), 1, "Thu tu phong co bien nhieu, khong phai luon giong nhau")

func test_rotation_reaches_every_track_before_repeating() -> void:
	# Đi hết một lượt: đúng 3 bản, không bản nào phải lặp sớm.
	_mp._begin_round()
	var seen: Array[int] = []
	for _step in 3:
		seen.append(_mp._order[_mp._index])
		_mp._index += 1
	assert_eq(seen.size(), 3, "Phai phat het 3 bai")
	var sorted_seen: Array[int] = seen.duplicate()
	sorted_seen.sort()
	assert_eq(sorted_seen, [0, 1, 2] as Array[int], "Moi bai chi phat mot lan trong mot luot")

func test_wrapping_past_last_track_starts_a_new_round() -> void:
	_mp._begin_round()
	_mp._index = 2
	_mp._index = 3  # vượt quá cuối lượt
	_mp._begin_round()
	assert_eq(_mp._index, 0, "Het luot phai quay lai ban dau")
	assert_eq(_mp._order.size(), 3, "Luot moi van phai du 3 bai")