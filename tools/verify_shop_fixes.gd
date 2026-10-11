extends SceneTree

## Kiem chung 2 loi da bao:
##  1. BtnBack phai nhan chuot duoc (mouse_filter khong phai IGNORE).
##  2. Moi nhan vat phai co MOT o rieng va model lap day khoang do
##     nhu nhau, khong bi de/chum vao khung.

const SAVE := "user://__verify_shopfix.cfg"
const SHOP := "res://scenes/ui/shop.tscn"

var _gm: Node
var _shop: Control
var _step := 0
var _f := 0
var _bad := 0

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	if _step == 0:
		_step = 1
		_gm = root.get_node("GameManager")
		_gm.save_path = SAVE
		_gm.reset_progress()
		_gm.coins = 30
		_shop = (load(SHOP) as PackedScene).instantiate()
		root.add_child(_shop)
		return false
	_f += 1
	if _f < 30:
		return false

	_check_back_button()
	_check_one_cell_per_character()
	_check_isolated_world()
	_check_auto_framing()

	print("")
	print("=== TAT CA DUNG ===" if _bad == 0 else "=== %d LOI ===" % _bad)
	quit(0 if _bad == 0 else 1)
	return true

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_bad += 1
	print("%-40s : %s %s" % [label, "OK" if ok else "LOI", detail])

func _check_back_button() -> void:
	print("=== nut quay lai ===")
	var btn := _shop.get_node_or_null("%BtnBack") as TextureButton
	_check("BtnBack ton tai", btn != null)
	if btn == null:
		return
	# MOUSE_FILTER_STOP = 0. Neu la IGNORE (2) thi click xuyen qua
	# ma khong bao gi gan den nut -> bam khong co gi xay ra.
	_check("khong phai IGNORE (bam duoc)",
		btn.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"(mouse_filter=%d)" % btn.mouse_filter)
	_check("nhay phim duoc", btn.focus_mode != Control.FOCUS_NONE
		or btn.mouse_filter == Control.MOUSE_FILTER_STOP)
	var con: Array = btn.pressed.get_connections()
	_check("da noi signal pressed", con.size() > 0, "(%d ket noi)" % con.size())
	_check("co texture nut", btn.texture_normal != null)
	_check("co tooltip", btn.tooltip_text != "")

func _check_one_cell_per_character() -> void:
	print("")
	print("=== moi nhan vat mot o rieng ===")
	var cards := _shop.get_node("%CardRow").get_children()
	_check("co 3 the", cards.size() == 3, "(%d)" % cards.size())
	var slots := {}
	var names := []
	for c in cards:
		names.append(c.skin_name)
		var slot := c.get_node("%PreviewSlot")
		slots[slot.get_instance_id()] = true
		var kids := slot.get_children()
		_check("o %s chi chua 1 model" % c.skin_name, kids.size() == 1,
			"(co %d)" % kids.size())
		_check("o %s co khung chon mau rieng" % c.skin_name, c.get_node("%LockOverlay") != null)
	_check("khong card nao dung chung o", slots.size() == 3,
		"(so o = %d)" % slots.size())
	for want in ["gobot", "gdbot", "sophia"]:
		_check("co the %s" % want, want in names)

	# O xem truoc phai tach bien ro voi nen the cua card, nguoi dung
	# phai phan biet duoc dau la "o chua nhan vat".
	for c in cards:
		var pp := c.get_node("VBox/PanelPreview")
		var sb: StyleBoxFlat = pp.get_theme_stylebox("panel") as StyleBoxFlat
		var frame_bg: Color = sb.bg_color
		_check("nen o %s khac nen the" % c.skin_name,
			frame_bg.get_luminance() < 0.1,
			"(do sang nen o=%.2f)" % frame_bg.get_luminance())
		_check("o %s co vien" % c.skin_name, sb.border_width_top >= 2)

func _check_isolated_world() -> void:
	print("")
	print("=== moi o co World3D rieng (khong de model chong nhau) ===")
	# SubViewport.own_world_3d mac dinh false => TAT CA cung dung World3D cua
	# viewport cha. Khi do model cua moi the deu nam o goc (0,0,0) cua mot
	# world chung, va camera cua the nao cung nhin vao world do -> cac model
	# chong len nhau trong cung mot khung hinh.
	var worlds := {}
	for c in _shop.get_node("%CardRow").get_children():
		var vp := c.get_node("VBox/PanelPreview/PreviewWrap/SubViewportContainer/SubViewport") as SubViewport
		_check("o %s co own_world_3d" % c.skin_name, vp.own_world_3d)
		if vp.world_3d != null:
			worlds[vp.world_3d.get_instance_id()] = str(c.skin_name)
	# Headless khong render SubViewport nen World3D co the chua duoc tao;
	# khi do bo qua phep so sanh, cac check `own_world_3d` o tren la du.
	if worlds.size() > 0:
		_check("khong the nao dung chung World3D", worlds.size() == 3,
			"(so World3D = %d)" % worlds.size())
	else:
		print("%-40s : BO QUA (headless chua tao World3D)" % "khong the nao dung chung World3D")

	# Kiem tra truc tiep: moi o chi duoc render dung mot model.
	for c in _shop.get_node("%CardRow").get_children():
		var vp := c.get_node("VBox/PanelPreview/PreviewWrap/SubViewportContainer/SubViewport") as SubViewport
		var names := []
		for n in _walk(vp):
			if n is Node3D and (n as Node3D).name.ends_with("Skin"):
				names.append(str(n.name))
		_check("o %s chi render 1 model" % c.skin_name, names.size() == 1,
			"(%s)" % str(names))

func _walk(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out += _walk(c)
	return out

func _check_auto_framing() -> void:
	print("")
	print("=== can khung tu dong cho tung model ===")
	# Do ti le model chiem trong khung: camera phai lui dung nho de
	# moi nhan vat lap day o nhu nhau, khong to nho lech nhau.
	var fills := {}
	for c in _shop.get_node("%CardRow").get_children():
		var cam := c.get_node(c.CAM_PATH) as Camera3D
		_check("card %s co camera" % c.skin_name, cam != null)
		if cam == null:
			continue
		var bounds: AABB = c._visual_bounds(c.get_node("%PreviewSlot").get_child(0))
		var h: float = bounds.size.y
		var tan_v := tan(deg_to_rad(cam.fov) * 0.5)
		# Chieu cao khung nhin thay tai mat phang cua model.
		var frame_h := 2.0 * tan_v * cam.position.z if cam.rotation == Vector3.ZERO else 0.0
		if frame_h > 0.0:
			var ratio: float = h / frame_h
			fills[c.skin_name] = ratio
			_check("model %s nap khong qua tran" % c.skin_name, ratio <= 1.0,
				"(%.0f%% khung)" % (ratio * 100.0))
			_check("model %s lap day khung" % c.skin_name, ratio >= 0.68,
				"(%.0f%% khung)" % (ratio * 100.0))
	if fills.size() == 3:
		var vals := fills.values()
		var lo: float = vals[0]
		var hi: float = vals[0]
		for v in vals:
			lo = minf(lo, v); hi = maxf(hi, v)
		_check("3 model cung kich thuoc tren khung", (hi - lo) / hi <= 0.15,
			"(lech %.0f%%)" % ((hi - lo) / hi * 100.0))