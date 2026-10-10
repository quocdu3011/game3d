extends Node

## Nhạc nền cho toàn bộ game — autoload nên đổi scene không bị ngắt nhạc.
##
## Ba bản được phát NGẪU NHIÊN theo từng lượt: mỗi lượt sinh một thứ tự
## riêng gồm đủ cả 3 bản, phát hết rồi mới trộn lượt mới. Nhờ vậy không
## có chuyện một bản bị bỏ sót, cũng không có chuyện hai bản giống nhau
## nối tiếp nhau ở ranh giới giữa hai lượt.
##
## Nhạc dùng AudioStreamPlayer (không phải 3D) nên không bị ảnh hưởng bởi
## vị trí người chơi, và tiếp tục phát khi mở menu tạm dừng.

const TRACKS: Array[String] = [
	"res://assets/audio/game-music-1.mp3",
	"res://assets/audio/game-music-2.mp3",
	"res://assets/audio/game-music-3.mp3",
]

## Nhạc nền thường để nhỏ hơn SFX một chút. Chỉnh ở đây hoặc gọi set_volume_db.
@export var volume_db: float = -6.0

var _player: AudioStreamPlayer
var _order: Array[int] = []
var _index: int = 0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	_player.volume_db = volume_db
	add_child(_player)
	_player.finished.connect(_on_track_finished)
	_begin_round()

## Người chơi có bật nhạc nền không (xem màn Tuỳ chọn).
var music_enabled: bool = true

## Bật/tắt nhạc nền mà không mất vị trí bản đang phát.
func set_music_enabled(on: bool) -> void:
	music_enabled = on
	if on:
		start()
	else:
		_player.stream_paused = true

func is_music_enabled() -> bool:
	return music_enabled

## Bắt đầu phát nếu đang im lặng. Gọi lại nhiều lần cũng vô hại.
func start() -> void:
	if not music_enabled or _player.playing:
		return
	if _order.is_empty():
		_begin_round()
	_play_current()

func stop() -> void:
	_player.stop()

## Đổi âm lượng nhạc nền (dB). Giá trị đang phát áp dụng ngay.
func set_volume_db(db: float) -> void:
	volume_db = db
	_player.volume_db = db

## Bản đang phát, để hiển thị/debug. Rỗng nếu chưa phát.
func current_track() -> String:
	if _order.is_empty():
		return ""
	return TRACKS[_order[_index]]

## Thứ tự phát của một lượt: đủ `count` chỉ số, mỗi chỉ số đúng một lần,
## thứ tự ngẫu nhiên. Tách riêng để test được.
static func build_order(count: int) -> Array[int]:
	var order: Array[int] = []
	for i in count:
		order.append(i)
	order.shuffle()
	return order

func _begin_round() -> void:
	_order = build_order(TRACKS.size())
	_index = 0

func _play_current() -> void:
	var stream := load(TRACKS[_order[_index]]) as AudioStream
	if stream == null:
		push_error("Khong nap duoc ban nhac: %s" % TRACKS[_order[_index]])
		_advance()
		return
	_player.stream = stream
	_player.play()

func _on_track_finished() -> void:
	_advance()

func _advance() -> void:
	_index += 1
	if _index >= _order.size():
		_begin_round()
	_play_current()