extends SceneTree

## Kiem chung man shop: gia, khoa, tru coin, chon nhan vat, luu/nap lai,
## va chan chon nhan vat chua mo khoa.

const SAVE := "user://__verify_shop.cfg"
const SHOP := "res://scenes/ui/shop.tscn"

var _gm: Node
var _shop: Control
var _step := 0
var _next_phys := 0
var _bad := 0
var _log: Array[String] = []

func _initialize() -> void:
	pass

func _process(_d: float) -> bool:
	match _step:
		0:
			_step = 1
			_gm = root.get_node("GameManager")
			_gm.save_path = SAVE
			_gm.reset_progress()
			_gm.coins = 200
			_shop = (load(SHOP) as PackedScene).instantiate()
			root.add_child(_shop)
			_next_phys = int(Engine.get_physics_frames()) + 4
		1:
			if int(Engine.get_physics_frames()) < _next_phys:
				return false
			_step = 2
			_check_setup()
			_check_initial_state()
		2:
			_step = 3
			# MUA sophia (gia 120) -> tien con 80
			_gm.coins = 200
			_refresh_cards()
			var got: bool = _gm.unlock_skin("sophia")
			_check("mua sophia thanh cong", got)
			_check("tru dung 120 coin", _gm.coins == 80, "(con %d)" % _gm.coins)
			_check("sophia da mo khoa", _gm.is_skin_unlocked("sophia"))
			_check("gobot van mo khoa", _gm.is_skin_unlocked("gobot"))
			_check("gdbot van khoa", not _gm.is_skin_unlocked("gdbot"))
		3:
			_step = 4
			# Mua gia du la `unlock_skin` tra ve true nhung khong tru them.
			_gm.coins = 200
			var got2: bool = _gm.unlock_skin("sophia")
			_check("mua lai khong ton coin", got2 and _gm.coins == 200, "(con %d)" % _gm.coins)
			# Khong du coin -> fail
			_gm.coins = 10
			var got3: bool = _gm.unlock_skin("gdbot")
			_check("khong du coin -> mua that bai", not got3)
			_check("khong tru coin khi thieu", _gm.coins == 10, "(con %d)" % _gm.coins)
			_check("gdbot van khoa", not _gm.is_skin_unlocked("gdbot"))
			# Ten khong ton tai
			_check("skin ao -> tra false", not _gm.unlock_skin("khong_co_that"))
		4:
			_step = 5
			# `select_skin` phai chan nhan vat chua mo khoa.
			_check("select skin chua mo khoa bi chan", not _gm.select_skin("gdbot"))
			_check("select skin da mo khoa ok", _gm.select_skin("sophia") and _gm.selected_skin == "sophia")
		5:
			_step = 6
			_check_persistence()
		6:
			_step = 7
			_refresh_cards()
			_check("card cua sophia da doi thanh DUNG", _btn_text("sophia") in ["DÙNG NHÂN VẬT", "ĐANG DÙNG"],
				"(\"%s\")" % _btn_text("sophia"))
			_check("card cua gdbot van la MUA", _btn_text("gdbot") == "MUA",
				"(\"%s\")" % _btn_text("gdbot"))
			_check("nhan vat dang chon da doi o card", _status_text("sophia") == "ĐANG DÙNG",
				"(\"%s\")" % _status_text("sophia"))
			# Reset phai chay SAU cac assert UI o tren, vi no xoa sach
			# trang thai ma cac assert do phu thuoc.
			_check_reset()
			_report()
			quit(0 if _bad == 0 else 1)
			return true
	return false

func _refresh_cards() -> void:
	for c in _cards():
		c.refresh()

func _cards() -> Array:
	var row := _shop.get_node("%CardRow")
	return row.get_children() if row else []

func _card(skin: String) -> Node:
	for c in _cards():
		if c.skin_name == skin:
			return c
	return null

func _btn_text(skin: String) -> String:
	var c := _card(skin)
	var b := c.get_node("%BtnAction") as Button if c else null
	return b.text if b else "<khong co card>"

func _status_text(skin: String) -> String:
	var c := _card(skin)
	var l := c.get_node("%StatusLbl") as Label if c else null
	return l.text if l else "<khong co card>"

func _check_setup() -> void:
	print("=== cau truc man shop ===")
	var cards := _cards()
	_check("co 3 the nhan vat", cards.size() == 3, "(thuc te %d)" % cards.size())
	var names := []
	for c in cards:
		names.append(c.skin_name)
		_check("card %s co khung xem truoc 3D" % c.skin_name, c.get_node("%PreviewSlot") != null)
		_check("card %s co lop khoa" % c.skin_name, c.get_node("%LockOverlay") != null)
	for want in ["gobot", "gdbot", "sophia"]:
		_check("co the %s" % want, want in names)
	_check("nut quay lai co", _shop.get_node("%BtnBack") != null)
	_check("nhan vi tien co", _shop.get_node("%LblCoins") != null)

func _check_initial_state() -> void:
	print("")
	print("=== trang thai ban dau (reset, 200 coin) ===")
	_gm.coins = 200
	_refresh_cards()
	var lock_gobot: bool = (_card("gobot").get_node("%LockOverlay") as Control).visible
	_check("gobot khong bi khoa", not lock_gobot)
	var lock_gdbot: bool = (_card("gdbot").get_node("%LockOverlay") as Control).visible
	_check("gdbot bi khoa", lock_gdbot)
	_check("gobot dang dung", _status_text("gobot") == "ĐANG DÙNG", "(\"%s\")" % _status_text("gobot"))
	_check("gia hien tren card gdbot", _status_text("gdbot") == "50", "(\"%s\")" % _status_text("gdbot"))
	var wallet := _shop.get_node("%LblCoins") as Label
	_check("vi hien 200 coin", wallet.text == "200", "(\"%s\")" % wallet.text)
	# Nap xuong 10 coin -> nut MUA cua gdbot phai khoa vi khong du tien.
	_gm.coins = 10
	_refresh_cards()
	_check("khong du coin -> nut MUA bi khoa",
		(_card("gdbot").get_node("%BtnAction") as Button).disabled)
	_gm.coins = 200
	_refresh_cards()
	_check("du coin -> nut MUA bat lai",
		not (_card("gdbot").get_node("%BtnAction") as Button).disabled)

func _check_persistence() -> void:
	print("")
	print("=== luu / nap lai ===")
	_gm.coins = 77
	_gm.select_skin("sophia")
	_gm._save_progress()

	var reloaded: Node = load("res://scripts/game_manager.gd").new()
	reloaded.save_path = SAVE
	reloaded._load_progress()
	_check("nap lai: sophia van mo khoa", reloaded.is_skin_unlocked("sophia"))
	_check("nap lai: gdbot van khoa", not reloaded.is_skin_unlocked("gdbot"))
	_check("nap lai: gobot van mo khoa", reloaded.is_skin_unlocked("gobot"))
	_check("nap lai: coin dung", reloaded.coins == 77, "(%d)" % reloaded.coins)
	_check("nap lai: nhan vat da chon", reloaded.selected_skin == "sophia",
		"(\"%s\")" % reloaded.selected_skin)
	reloaded.free()

	# Skin da xoa khoi SKINS trong save phai bi bo qua, khong lam hong.
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("unlock", "skin_da_xoa", true)
	cfg.set_value("settings", "selected_skin", "skin_da_xoa")
	cfg.save(SAVE)
	var reloaded2: Node = load("res://scripts/game_manager.gd").new()
	reloaded2.save_path = SAVE
	reloaded2._load_progress()
	_check("bo qua skin da xoa", not reloaded2.is_skin_unlocked("skin_da_xoa"))
	_check("skin chua mua -> ve mac dinh", reloaded2.selected_skin == "gobot",
		"(\"%s\")" % reloaded2.selected_skin)
	reloaded2.free()

func _check_reset() -> void:
	print("")
	print("=== xoa tien do -> reset shop ===")
	_gm.reset_progress()
	_check("reset: khong con skin nao mo", _gm.unlocked_skins.is_empty())
	_check("reset: coin ve 0", _gm.coins == 0)
	_check("reset: ve nhan vat mac dinh", _gm.selected_skin == "gobot")
	_refresh_cards()
	_check("reset: card sophia khoa lai", _btn_text("sophia") == "MUA",
		"(\"%s\")" % _btn_text("sophia"))
	_check("reset: card sophia hien gia 120", _status_text("sophia") == "120",
		"(\"%s\")" % _status_text("sophia"))

func _check(label: String, ok: bool, detail: String = "") -> void:
	if not ok:
		_bad += 1
	print("%-38s : %s %s" % [label, "OK" if ok else "LOI", detail])

func _report() -> void:
	print("")
	print("=== TAT CA DUNG ===" if _bad == 0 else "=== %d LOI ===" % _bad)