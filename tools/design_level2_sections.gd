extends SceneTree

## Dựng 3 đoạn màn mới cho level 2 bằng đúng asset sẵn có, rồi render ảnh.
## Chạy ngoài editor, không cần mở Godot:
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" \
##     godot --rendering-driver vulkan --path . -s res://tools/design_level2_sections.gd
##
## Mọi khoảng cách bố trí đều bám ngân sách nhảy của player.gd:
##   nhay 1: cao 1.28, xa 6.12      nhay 2: cao 2.55, xa 9.18
##   leo bac: 0.80

const OUT_DIR := "res://.render/moi"
const TILE := "res://scenes/Entity/Tile/"

var _cam: Camera3D
var _shots: Array[Dictionary] = []
var _index := 0
var _settle := 0
var _current: Node3D
var _bounds := AABB()
var _need_bounds := true

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var sections := [
		{"ten": "A_cuon_da", "build": "build_a"},
		{"ten": "B_canh_quay", "build": "build_b"},
		{"ten": "C_bac_thang_ban_ten", "build": "build_c"},
		{"ten": "D_thu_thach_tru_gai", "build": "build_d"},
	]
	var built: Array = []
	for s in sections:
		var node: Node3D = call(s["build"])
		node.name = s["ten"]
		_setup_lighting(node)
		root.add_child(node)
		built.append({"ten": s["ten"], "node": node})

	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 50.0
	_cam.far = 3000.0
	root.add_child(_cam)

	for b in built:
		_add_shots(b["ten"])
	print("Da dung %d doan, %d goc chup. Ten node: %s" % [
		built.size(), _shots.size(), _names_of(root)])

func _names_of(n: Node) -> String:
	var out: Array[String] = []
	for c in n.get_children():
		if c is Node3D:
			out.append(str(c.name))
	return ", ".join(out)

func _add_shots(node_name: String) -> void:
	_shots.append({"node": node_name, "ten": node_name + "_01_toan_canh", "dir": Vector3(-0.72, -0.62, -0.30), "khu": 1.0, "look": 0.4})
	_shots.append({"node": node_name, "ten": node_name + "_02_nhin_thang_tieu", "dir": Vector3(0, -1, -0.001), "khu": 1.1, "look": 0.0})
	_shots.append({"node": node_name, "ten": node_name + "_03_doc_cheo_thap", "dir": Vector3(-0.28, -0.20, -0.94), "khu": 0.70, "look": 0.5})

func _process(_d: float) -> bool:
	if _current == null:
		if _index >= _shots.size():
			quit(0)
			return true
		var shot: Dictionary = _shots[_index]
		# Chi bat mot doan tai mot thoi: neu de ca ba cung trong cay, ball cua
		# doan A se lot vao khung chup cua doan B.
		for n in root.get_children():
			if n is Node3D and n != _cam and not String(n.name).begins_with("@"):
				(n as Node3D).visible = (String(n.name) == shot["node"])
		_current = root.get_node_or_null(shot["node"])
		if _current == null:
			printerr("Khong tim thay node ", shot["node"])
			_index += 1
			return false
		_need_bounds = true
		_settle = 0
		return false

	if _need_bounds:
		_bounds = _world_bounds(_current)
		_need_bounds = false
		print("%s: AABB %s  kich thuoc %s" % [_current.name, _bounds.position, _bounds.size])
		_settle = 0
		return false

	var shot2: Dictionary = _shots[_index]
	if _settle == 0:
		var centre := _bounds.get_center()
		var target: Vector3 = centre + Vector3.UP * (_bounds.size.y * (shot2["look"] as float) * 0.3)
		var dir: Vector3 = (shot2["dir"] as Vector3).normalized()
		var radius := _bounds.size.length() * 0.5
		var dist: float = radius * (shot2["khu"] as float) / tan(deg_to_rad(_cam.fov) * 0.5) * 0.85
		_cam.global_position = target - dir * dist
		_cam.look_at(target, Vector3.UP)
		_cam.current = true
		_settle = 1
		return false

	_settle += 1
	if _settle < 4:
		return false

	var img := root.get_texture().get_image()
	if img:
		var p := "%s/%s.png" % [OUT_DIR, shot2["ten"]]
		if img.save_png(p) == OK:
			print("  -> ", p)
	_current = null
	_index += 1
	_settle = 0
	return false

# ---------------------------------------------------------------- builders

## Đoạn A — hành lang đá cuộn. Sàn liền mạch, BallSpawner theo nhịp lệch,
## trang trí hai bên. Dùng hết các asset chưa từng xuất hiện ở level 2.
func build_a() -> Node3D:
	var n := Node3D.new()

	# San 10 don vi rong, 52 don vi dai, canh giua truc X.
	_slab(n, "SanChinh", TILE + "TileLowDesert.tscn", Vector3(0, 0, 26), Vector3i(5, 1, 27))
	# Be lon o dau va cuoi de co noi bat dau / ket thuc.
	_slab(n, "BeDau", TILE + "TileLargeDesert.tscn", Vector3(0, -1, 1), Vector3i(2, 1, 2))
	_slab(n, "BeCuoi", TILE + "TileLargeDesert.tscn", Vector3(0, -1, 51), Vector3i(2, 1, 2))

	# Tuong hai ben cao 2 don vi -> phai bo qua hoac nhay len.
	for i in range(6):
		var side := -1.0 if i % 2 == 0 else 1.0
		var wall := _inst(n, TILE + "TileHightDesert.tscn", Vector3(side * 6.0, 1, 5 + i * 9))
		wall.scale = Vector3(1.0, 2.0, 2.0)

	# Ba BallSpawner, nhip lech nhau (2.5 / 3.5 / 4.5 giay).
	_balls(n, Vector3(0, 6, 12), 2.5)
	_balls(n, Vector3(0, 6, 26), 3.5)
	_balls(n, Vector3(0, 6, 40), 4.5)

	# Vai bat buoc phai nhay len bo qua.
	var ledge := _inst(n, TILE + "TileLargeDesert.tscn", Vector3(-4, 1, 19))
	ledge.scale = Vector3(1.0, 2.0, 1.0)
	var ledge2 := _inst(n, TILE + "TileLargeDesert.tscn", Vector3(4, 1, 34))
	ledge2.scale = Vector3(1.0, 2.0, 1.0)

	# Kich thuoc that cua model: tree_desert 2.0x2.8, rocksA 1.6x0.35,
	# plantA 0.67x0.26, detail_desert 1.7x0.33 — nen ty le ~1.0 moi vua.
	_decor(n, "tree_desert", Vector3(-8.0, 0, 4), 1.25)
	_decor(n, "tree_desert", Vector3(8.0, 0, 15), 1.05)
	_decor(n, "rocksA_desert", Vector3(-8.4, 0, 27), 0.95)
	_decor(n, "rocksB_desert", Vector3(8.4, 0, 36), 1.15)
	_decor(n, "plantA_desert", Vector3(-7.8, 0, 44), 1.30)
	_decor(n, "detail_desert", Vector3(8.0, 0, 8), 1.00)
	_decor(n, "detail_desert", Vector3(-8.0, 0, 48), 1.00)
	return n

## Đoạn B — rào quay. San vo thanh khe nho, Swiper canh khe, SpikeRoller o giua.
func build_b() -> Node3D:
	var n := Node3D.new()

	# 5 doan san 12 don vi, each nhau 3.5 don vi — nhay 1 (xa toi da 6.12).
	var centres := [6.0, 21.5, 37.0, 52.5, 68.0]
	for i in range(centres.size()):
		var zc: float = centres[i]
		_slab(n, "Doan%d" % i, TILE + "TileLowDesert.tscn", Vector3(0, 0, zc), Vector3i(5, 1, 6))
		# Tuong chan hai ben doan san, cao 2 don vi.
		for s in [-1.0, 1.0]:
			var w := _inst(n, TILE + "TileHightDesert.tscn", Vector3(s * 6.0, 1, zc))
			w.scale = Vector3(1.0, 2.0, 3.0)
	_slab(n, "SanCuoi", TILE + "TileLargeDesert.tscn", Vector3(0, -1, 77), Vector3i(2, 1, 2))

	# Swiper_Long giua doan — phai tim nhip quay truoc khi lao qua.
	_swiper(n, "Swiper_Long_1.tscn", Vector3(0, 1, 6), 70.0)
	_swiper(n, "Swiper_Long_2.tscn", Vector3(0, 1, 37), 95.0)
	# Swiper nho dat sat canh san: phai canh phia doi dien ma chay.
	_swiper(n, "Swiper_1.tscn", Vector3(-3, 1, 13), 120.0)
	_swiper(n, "Swiper_3.tscn", Vector3(3, 1, 18), -120.0)
	_swiper(n, "Swiper_2.tscn", Vector3(-3, 1, 30), 140.0)
	_swiper(n, "Swiper_3.tscn", Vector3(3, 1, 46), -140.0)
	# Swiper_Double: hai canh quay, khe hep hon phai canh chinh xac.
	_swiper(n, "Swiper_Double_1.tscn", Vector3(0, 1, 52), 100.0)
	_swiper(n, "Swiper_Double_2.tscn", Vector3(0, 1, 60), -85.0)
	_swiper(n, "Swiper_Double_3.tscn", Vector3(0, 1, 68), 130.0)

	# SpikeRoller giua doan cuoi — cham vao se bi ve checkpoint.
	_spike(n, Vector3(0, 0, 62), 120.0)

	_decor(n, "rocksA_desert", Vector3(-8.4, 0, 4), 0.95)
	_decor(n, "rocksB_desert", Vector3(8.4, 0, 26), 1.10)
	_decor(n, "plantB_desert", Vector3(-8.4, 0, 48), 1.40)
	_decor(n, "tree_desert", Vector3(8.6, 0, 58), 1.15)
	_decor(n, "detail_desert", Vector3(-8.4, 0, 72), 1.00)
	return n

## Đoạn C — bậc thang bắn tên. Leo cao danh, giua duong co khe 11.5
## (vuot tầm nhay 9.18) — phai dung TargetStand keo tile qua.
func build_c() -> Node3D:
	var n := Node3D.new()

	# 7 bo duong nho (2x2 o = 4x4 don vi), moi bo lech 1.2 cao -> nhay 1,
	# xen mot buoc lech 2.4 (y 3.6 -> 6.0) -> nhay 2. Zigzag hai ben cho
	# buoc phai nhin va canh, khong phai chay thang.
	var tiers := [
		Vector3(0, 0.0, 0), Vector3(4.0, 1.2, 4), Vector3(0.5, 2.4, 8),
		Vector3(4.5, 3.6, 12), Vector3(2.0, 6.0, 17), Vector3(5.0, 7.2, 21),
		Vector3(1.5, 8.4, 25),
	]
	for ti in range(tiers.size()):
		var pad := (load(TILE + "TileLargeDesert.tscn") as PackedScene).instantiate() as Node3D
		pad.name = "Bo%d" % ti
		n.add_child(pad)
		pad.position = tiers[ti]
		pad.scale = Vector3(0.62, 1.0, 0.62)

	# Be khoi chay nho, thap hon bo 0 mot don vi de la duyet xuong.
	_slab(n, "BeChay", TILE + "TileLowDesert.tscn", Vector3(0, -1, -6), Vector3i(4, 1, 6))

	# --- Cau doi: khe giua Bo4 va Bo6 ---
	# Bo4 (2.0, 6.0, 17) va Bo6 (1.5, 8.4, 25) cach doc 8.0 nhung phai vay
	# qua khe 11.5 quanh z=21 — vuot tầm nhay 9.18. Phai dung TargetStand
	# keo CauCauTenh sang cho dap vao khe.
	var bridge := (load(TILE + "TileLargeDesert.tscn") as PackedScene).instantiate() as Node3D
	bridge.name = "CauCauTenh"
	n.add_child(bridge)
	bridge.position = Vector3(-5.5, 6.0, 21.0)
	bridge.scale = Vector3(0.62, 1.0, 0.62)

	var stand := (load("res://scenes/Entity/Item/TargetStand.tscn") as PackedScene).instantiate() as Node3D
	stand.name = "BiaTenh"
	# `n` chua nam trong cay nen _ready() chua chay — gan truoc khi vao root.
	stand.set("moving_tile", NodePath("../CauCauTenh"))
	stand.set("destination", NodePath("../Bo6"))
	stand.set("destination_offset", Vector3(0, 0, -1.6))
	n.add_child(stand)
	stand.position = Vector3(1.5, 8.4, 25.0)

	# Bai dap dung tren cung cao nhat: 4x4 don vi.
	_slab(n, "BaiDap", TILE + "TileLowDesert.tscn", Vector3(1.5, 8.4, 30), Vector3i(2, 1, 2))

	# Canh gac: Swiper_Long canh bo 4 va bo 6; SpikeRoller canh bo 3.
	_swiper(n, "Swiper_Long_1.tscn", Vector3(4.5, 3.6, 13), 80.0)
	_swiper(n, "Swiper_Long_2.tscn", Vector3(5.0, 7.2, 22), 110.0)
	_spike(n, Vector3(2.0, 2.4, 9), 120.0)

	_decor(n, "tree_desert", Vector3(-8.6, 0, -8), 1.30)
	_decor(n, "rocksA_desert", Vector3(8.4, 0, 2), 1.00)
	_decor(n, "plantA_desert", Vector3(-8.2, 8.4, 28), 1.30)
	_decor(n, "detail_desert", Vector3(8.0, 1.2, 12), 1.00)
	_decor(n, "rocksB_desert", Vector3(-8.6, 3.6, 16), 1.10)
	return n

## Đoạn D — THỬ THÁCH: đi qua vùng trụ gai.
##
## Cơ chế quan trọng: spike_roller.gd chi `rotate_y()` ca node, con Hitbox la
## CylinderShape3D — doi xung truc Y nen xoay khong doi the tich. Vung nguy hiem
## la HINH TRU TINH, toc do quay chi de trang tri. Thach thac phai den tu HINH
## HOC BO TRI, khong phai canh nhip quay.
##
## `spikeRoller.gltf` doi dung 2x2x2: cot dac cao 2. Khong buoc len duoc
## (max_step_height = 0.8) nhung nhay 2 (cao 2.55) thi do duoc len dinh cot.
func build_d() -> Node3D:
	var n := Node3D.new()

	# San 10 don vi rong — CHIA HAI KHUC de chan z 50..70 khong co san.
	# Neu phu san lien mach, nguoi choi di vong qua duoc hang gai ben cau.
	_slab(n, "SanDau", TILE + "TileLowDesert.tscn", Vector3(0, 0, 24), Vector3i(5, 1, 25))
	_slab(n, "SanCuoi", TILE + "TileLowDesert.tscn", Vector3(0, 0, 74), Vector3i(5, 1, 7))

	# Be vao / be ra, rong de dua nguoi choi vao va dua ra.
	_slab(n, "BeVao", TILE + "TileLargeDesert.tscn", Vector3(0, -1, 2), Vector3i(2, 1, 2))
	_slab(n, "BeRa", TILE + "TileLargeDesert.tscn", Vector3(0, -1, 76), Vector3i(2, 1, 2))

	# --- Vung canh bao: san do chuyen sang mau do de canh bao ---
	# Lop san do dat nhung trai tren san cat (y +0.06) — nhin la biet ngay.
	_danger_floor(n, Vector3(0, 0.06, 10), Vector3i(5, 1, 8))
	_danger_floor(n, Vector3(0, 0.06, 26), Vector3i(5, 1, 12))
	_danger_floor(n, Vector3(0, 0.06, 42), Vector3i(5, 1, 14))
	# Cau hep khong can san do — hai ben la vuc.

	# --- Pha 1: CANH GAI — hai tru mo khe giua 4 don vi ---
	# x=-3 va x=+3, moi tru rong 2 → khe con 4 don vi o chinh giua.
	_spike(n, Vector3(-3, 0, 10), 110.0)
	_spike(n, Vector3(3, 0, 10), 110.0)
	_spike(n, Vector3(-3, 0, 14), -90.0)
	_spike(n, Vector3(3, 0, 14), -90.0)

	# --- Pha 2: RAO GAI ZIGZAG — luon doi ben ---
	# Pha nay chi con 1 khe 3 don vi, nguoi choi phai chay lui qua lai.
	_spike(n, Vector3(-3, 0, 22), 120.0)
	_spike(n, Vector3(1, 0, 22), 120.0)
	_spike(n, Vector3(-1, 0, 28), -130.0)
	_spike(n, Vector3(3, 0, 28), -130.0)
	# Mot tru canh duong de khong co duong lui an toan.
	_spike(n, Vector3(-1, 0, 33), 100.0)

	# --- Pha 3: TRUC QUAY ---
	# Tru gan chinh + Swiper_Long quay that: day la vung nguy hiem DONG duy nhat
	# trong man, vi Swiper co canh quay co va cham that (khac SpikeRoller).
	_spike(n, Vector3(0, 0, 38), 120.0)
	_spike(n, Vector3(-3, 0, 42), 120.0)
	_spike(n, Vector3(3, 0, 42), 120.0)
	_spike(n, Vector3(0, 0, 46), -140.0)
	_swiper(n, "Swiper_Long_1.tscn", Vector3(-3.5, 1, 41), 75.0)
	_swiper(n, "Swiper_Long_2.tscn", Vector3(3.5, 1, 45), 95.0)

	# --- Pha 4: CAU HEP tren vuc ---
	# Cau rong 4 don va giua vuc (hai ben khong co san — roi se rơi ve
	# checkpoint). Hai ben la hang tru gai cach nhau 2 don: khong lọt qua,
	# nhung dinh tru cao 2 nen NHAY 2 (cao 2.55) van leo len duoc — duong
	# cho nguoi choi gioi nhanh hon duong cau.
	_slab(n, "Cau", TILE + "TileLowDesert.tscn", Vector3(0, 0, 60), Vector3i(2, 1, 20))
	for z in range(51, 70, 2):
		_spike(n, Vector3(-4, 0, float(z)), 100.0 + float(z % 40))
		_spike(n, Vector3(4, 0, float(z)), -100.0 - float(z % 40))
	# Tru chan dau cau + Swiper giua cau: phai chay don thoi.
	_spike(n, Vector3(0, 0, 49), 120.0)
	_swiper(n, "Swiper_1.tscn", Vector3(0, 1, 60), 150.0)

	# Bo dem cho nguoi choi thua bai quay ve be vao.
	_slab(n, "BeCuu", TILE + "TileLargeDesert.tscn", Vector3(0, -1, 8), Vector3i(2, 1, 2))

	_decor(n, "tree_desert", Vector3(-8.6, 0, 4), 1.20)
	_decor(n, "rocksA_desert", Vector3(8.6, 0, 20), 1.00)
	_decor(n, "rocksB_desert", Vector3(-8.8, 0, 36), 1.15)
	_decor(n, "plantA_desert", Vector3(8.4, 0, 50), 1.30)
	_decor(n, "detail_desert", Vector3(-8.4, 0, 66), 1.00)
	_decor(n, "rocksA_desert", Vector3(8.8, 0, 74), 0.95)
	return n

## Lop san mau do (TileLowRed) de canh bao vung nguy hiem.
func _danger_floor(parent: Node, origin: Vector3, dims: Vector3i) -> void:
	_slab(parent, "SanDo%d" % int(origin.z), TILE + "TileLowRed.tscn", origin, dims)

# ---------------------------------------------------------------- helpers

func _inst(parent: Node, path: String, pos: Vector3, ry: float = 0.0) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		return Node3D.new()
	var node := packed.instantiate() as Node3D
	parent.add_child(node)
	node.position = pos
	node.rotation.y = deg_to_rad(ry)
	return node

## Dat mot dai san canh giua tai `origin`: n x m o 2 don vi.
## `dims` la so o theo (X, _, Z).
func _slab(parent: Node, name: String, path: String, origin: Vector3, dims: Vector3i) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var holder := Node3D.new()
	holder.name = name
	parent.add_child(holder)
	var x0 := origin.x - float(dims.x - 1)
	var z0 := origin.z - float(dims.z - 1)
	for iz in range(dims.z):
		for ix in range(dims.x):
			var t := packed.instantiate() as Node3D
			holder.add_child(t)
			t.position = Vector3(x0 + ix * 2.0, origin.y, z0 + iz * 2.0)

func _balls(parent: Node, pos: Vector3, interval: float) -> void:
	var spawner := _inst(parent, "res://scenes/Entity/Item/BallSpawner.tscn", pos)
	spawner.set("spawn_interval", interval)
	# Scene ghi diem spawn o toa do the gioi cua level 1 (x ~ 90). Chuyen ve
	# cuc bo truoc, neu khong se lam phinh khung hinh va bay ball di xa.
	var lanes := spawner.get_node_or_null("SpawnPoints")
	if lanes:
		var xs := [-3.0, 0.0, 3.0]
		var i := 0
		for lane in lanes.get_children():
			if i < xs.size():
				(lane as Node3D).position = Vector3(xs[i], 1.0, 0.0)
			i += 1
	# Tam thoi tat thu muc su sinh: day la anh so do, khong phai mot lan choi.
	if spawner.has_method("set"):
		spawner.set("spawn_immediately", false)
	var timer := spawner.get_node_or_null("Timer") as Timer
	if timer:
		timer.stop()
	# Ve them vai qua bong de anh de doc. Dung `position` (khong phai global)
	# vi `n` chua nam trong cay luc dung.
	var ball_scene := load("res://scenes/Entity/Item/Ball.tscn") as PackedScene
	for offset in [Vector3(-2.5, 1.2, 0), Vector3(2.5, 1.2, 1.5)]:
		var b := ball_scene.instantiate()
		parent.add_child(b)
		b.position = pos + offset
		b.freeze = true

func _swiper(parent: Node, file: String, pos: Vector3, speed: float) -> void:
	var s := _inst(parent, "res://scenes/Entity/Trap/" + file, pos)
	if s.has_method("set"):
		s.set("rotation_speed_degrees", speed)
		s.rotation.y = deg_to_rad(35.0)   # canh goc de doc trong anh

func _spike(parent: Node, pos: Vector3, speed: float) -> void:
	var s := _inst(parent, "res://scenes/Entity/Trap/SpikeRoller.tscn", pos)
	if s.has_method("set"):
		s.set("rotation_speed_degrees", speed)
	s.rotation.y = deg_to_rad(25.0)

## Cay/da trang tri: nap truc tiep gltf, khong dat collision de khong anh huong
## gameplay (cay that trong Tree_1.tscn co goc la Node2D nen khong dung duoc).
func _decor(parent: Node, model: String, pos: Vector3, sc: float) -> void:
	var packed := load("res://models/%s.gltf" % model) as PackedScene
	if packed == null:
		return
	var mi := packed.instantiate() as Node3D
	parent.add_child(mi)
	mi.position = pos
	mi.scale = Vector3(sc, sc, sc)
	for c in mi.get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)

func _setup_lighting(node: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.light_energy = 1.15
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-48, 38, 0)
	node.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.65
	fill.light_color = Color(0.82, 0.86, 1.0)
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-30, -135, 0)
	node.add_child(fill)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.11, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.64)
	env.ambient_light_energy = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	node.add_child(we)

func _world_bounds(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out