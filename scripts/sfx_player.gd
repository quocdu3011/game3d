extends Node

## Hiệu ứng âm thanh một lần (nhảy, bắt đầu màn, hoàn thành).
## Autoload nên mọi scene đều phát được và không bị cắt khi đổi scene.
##
## Dùng pool cố định thay vì tạo node mỗi lần phát: người chơi có thể bấm
## nhảy liên tục, và hiệu ứng chồng tiếp là chuyện bình thường.

const SOUNDS: Dictionary = {
	"jump": "res://assets/audio/jump-effect.mp3",
	"game_start": "res://assets/audio/game-start.mp3",
	"game_winner": "res://assets/audio/game-winner.mp3",
}

## SFX thường to hơn nhạc nền một chút (MusicPlayer đang ở -6 dB).
@export var volume_db: float = 0.0

## Số tiếng được phát chồng nhau tối đa. Bấm nhảy liên tục sẽ cắt bớt nếu vượt.
const POOL_SIZE := 6

var _pool: Array[AudioStreamPlayer] = []
var _cursor: int = 0

func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		player.volume_db = volume_db
		add_child(player)
		_pool.append(player)

## Phát một hiệu ứng. Tên không có trong SOUNDS chỉ báo warning, không
## làm hỏng game — để call site không phải bọc try.
func play(sound_name: String, pitch_scale: float = 1.0) -> void:
	if _is_silent():
		return
	var path: String = SOUNDS.get(sound_name, "")
	if path == "":
		push_warning("SFX khong ton tai: %s" % sound_name)
		return
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Khong nap duoc SFX: %s" % path)
		return
	var player := _free_player()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.play()

func set_volume_db(db: float) -> void:
	volume_db = db
	for player in _pool:
		player.volume_db = db

## Dedicated server chạy headless, không có thiết bị âm thanh.
func _is_silent() -> bool:
	return DisplayServer.get_name() == "headless"

## Ưu tiên slot đang im lặng để hai tiếng cùng lúc không cắt nhau; hết chỗ
## thì cưỡng chế dùng slot kế tiếp.
func _free_player() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player
	var stolen := _pool[_cursor]
	_cursor = (_cursor + 1) % _pool.size()
	return stolen
