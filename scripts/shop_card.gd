extends PanelContainer

## Một thẻ nhân vật trong shop: xem trước 3D, trạng thái mở khoá, giá và
## nút hành động. Màn `shop.gd` gắn card và điều khiển qua `setup()` và
## `refresh()` — card tự bắn tín hiệu khi người chơi bấm nút.

signal action_requested(skin_name: String)

const TEX_COIN := "res://assets/UI/Icons/Icon_Small_Coin.png"
const TEX_CHECK := "res://assets/UI/Icons/Icon_Small_Blank_Check.png"

@onready var preview_slot: Node3D = get_node("%PreviewSlot")
@onready var lock_overlay: Control = get_node("%LockOverlay")
@onready var lbl_name: Label = get_node("%Name")
@onready var status_icon: TextureRect = get_node("%StatusIcon")
@onready var lbl_status: Label = get_node("%StatusLbl")
@onready var btn_action: Button = get_node("%BtnAction")

var skin_name: String = ""

var _current_node: Node = null

## Đường dẫn tương đối từ gốc card. Không dùng `%Camera3D` vì tiền tố `%`
## chỉ dùng cho tên duy nhất của một node, không dùng với đường dẫn con.
const CAM_PATH := "VBox/PanelPreview/PreviewWrap/SubViewportContainer/SubViewport/Camera3D"

@onready var preview_cam: Camera3D = get_node_or_null(CAM_PATH)

func _ready() -> void:
	if btn_action:
		btn_action.pressed.connect(_on_action_pressed)

## Nạp nhân vật vào khung xem trước và đặt tên hiển thị.
func setup(skin: String, display_name: String) -> void:
	skin_name = skin
	if lbl_name:
		lbl_name.text = display_name.to_upper()
	_build_preview()
	refresh()

func _build_preview() -> void:
	if preview_slot == null:
		return
	for child in preview_slot.get_children():
		child.queue_free()
	_current_node = null
	if skin_name == "":
		return
	var path := GameManager.get_skin_path(skin_name)
	var scn := load(path) as PackedScene
	if scn == null:
		return
	_current_node = scn.instantiate()
	preview_slot.add_child(_current_node)
	if _current_node.has_method("idle"):
		_current_node.idle()
	_frame_model()

## Tự đặt camera để mỗi nhân vật vừa khít ô của nó. Các model khác nhau
## về kích thước khá xa (cao 1.42 -> 1.82), nếu để camera cố định thì nhân vật
## to nhỏ lệch nhau và chừa nhiều khoảng trống. Đo AABB rồi lùi camera
## đúng bằng khoảng cách cần thiết để lấp đầy khung.
func _frame_model() -> void:
	if preview_cam == null or _current_node == null:
		return
	var bounds := _visual_bounds(_current_node)
	if bounds.size.length() <= 0.0:
		return

	# Khoảng cách camera -> vật thể để vừa chiều cao theo fov dọc.
	var tan_v := tan(deg_to_rad(preview_cam.fov) * 0.5)
	var vp := preview_cam.get_viewport()
	var aspect := 1.0
	if vp:
		var vs := vp.get_visible_rect().size
		if vs.y > 0.0:
			aspect = vs.x / vs.y
	var tan_h := tan_v * maxf(aspect, 0.01)

	# +0.28 chừa cho phần chân đặt sát đáy, tay giơ lên khi `idle()` chạy
	# và viền khung, để model không bị cắt cụt ở đỉnh.
	var half := Vector2(bounds.size.x * 0.5 + 0.28, bounds.size.y * 0.5 + 0.28)
	var dist := maxf(half.y / maxf(tan_v, 0.01), half.x / maxf(tan_h, 0.01))

	# Nhìn thẳng vào chính giữa khung nhân vật.
	var center := bounds.get_center()
	preview_cam.position = center + Vector3(0.0, 0.0, dist)
	preview_cam.rotation = Vector3.ZERO
	preview_cam.look_at(center, Vector3.UP)

## Hợp AABB của mọi VisualInstance3D bên trong node, tính theo toạ độ thế giới.
func _visual_bounds(node: Node) -> AABB:
	var acc := AABB()
	var has_any := false
	for child in node.get_children():
		if child is VisualInstance3D:
			var vi := child as VisualInstance3D
			var local := vi.get_aabb()
			var xform := vi.global_transform
			# AABB của phép biến đổi affine chỉ hợp lệ khi transform
			# không có xoay/skew, nên lấy đủ 8 đỉnh rồi bọc lại.
			var points: Array[Vector3] = []
			for i in range(8):
				points.append(xform * local.get_endpoint(i))
			var world := AABB(points[0], Vector3.ZERO)
			for p in points:
				world = world.expand(p)
			acc = world if not has_any else acc.merge(world)
			has_any = true
		else:
			var sub := _visual_bounds(child)
			if sub.size.length() > 0.0:
				acc = sub if not has_any else acc.merge(sub)
				has_any = true
	return acc

## Cập nhật ảnh, giá và nút theo trạng thái hiện tại của GameManager.
func refresh() -> void:
	if skin_name == "":
		return
	var unlocked := GameManager.is_skin_unlocked(skin_name)
	var price := GameManager.skin_price(skin_name)
	var in_use := GameManager.selected_skin == skin_name
	var affordable := GameManager.coins >= price

	if lock_overlay:
		lock_overlay.visible = not unlocked

	if status_icon:
		status_icon.texture = load(TEX_CHECK if unlocked else TEX_COIN)

	if lbl_status:
		if in_use:
			lbl_status.text = "ĐANG DÙNG"
		elif unlocked:
			lbl_status.text = "ĐÃ MỞ KHOÁ"
		else:
			lbl_status.text = str(price)

	if btn_action == null:
		return
	if in_use:
		btn_action.text = "ĐANG DÙNG"
		btn_action.disabled = true
	elif unlocked:
		btn_action.text = "DÙNG NHÂN VẬT"
		btn_action.disabled = false
	else:
		btn_action.text = "MUA"
		btn_action.disabled = not affordable
		if not affordable:
			btn_action.tooltip_text = "Cần thêm %d coin" % (price - GameManager.coins)
		else:
			btn_action.tooltip_text = ""

func _on_action_pressed() -> void:
	action_requested.emit(skin_name)