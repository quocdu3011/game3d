extends SceneTree

## Kiểm chứng MeshLibrary: đặt item vào ô (0,0,0) của GridMap rồi raycast THẬT,
## so với raycast vào chính scene tile gốc đặt ở gốc trục.
##
## Mỗi lượt chỉ tồn tại MỘT nguồn va chạm (hoặc GridMap, hoặc scene gốc) nên
## raycast không bị lẫn. Raycast tại nhiều điểm để bắt cả sai lệch biên.

const LIBRARY_PATH := "res://scenes/Entity/Tile/tile_mesh_library.tres"
const TILE_DIR := "res://scenes/Entity/Tile/"

const PROBE_NAMES: Array[String] = [
	"TileLowBlue", "TileLargeBlue", "TileHightDesert", "TileMediumForest",
	"TileSmallRed", "TileSlopeLowHighDesert", "TileSlopeLowMediumYellow",
	"Barier_Large", "Barier_Small",
]

## Các điểm raycast theo (x, z), đặt cao hơn mọi tile.
const PROBE_XZ: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.9, 0.0), Vector2(-0.9, 0.0),
	Vector2(0.0, 0.9), Vector2(0.0, -0.9), Vector2(0.8, 0.8),
]

const RAY_FROM := Vector3(0.0, 60.0, 0.0)
const RAY_TO := Vector3(0.0, -60.0, 0.0)

var _library: MeshLibrary
var _gridmap: GridMap
var _ref: Node3D
var _index := 0
var _settle := 0
var _phase := 0
var _grid_hits: Array[Vector3] = []
var _failures := 0
var _lines: Array[String] = []

func _initialize() -> void:
	_library = load(LIBRARY_PATH) as MeshLibrary
	if _library == null:
		printerr("Khong load duoc ", LIBRARY_PATH)
		quit(1)
		return
	_gridmap = GridMap.new()
	_gridmap.name = "TestGridMap"
	_gridmap.cell_size = Vector3(2.0, 1.0, 2.0)
	_gridmap.mesh_library = _library
	root.add_child(_gridmap)

	print("=== Kiem chung MeshLibrary (%d item) ===" % _library.get_item_count())
	print("GridMap: cell_size=%s cell_center=true/true/true, item dat o (0,0,0)" % _gridmap.cell_size)
	print("So sanh raycast doc 6 diem, doi chieu voi scene goc dat o (0,0,0)")
	print("")

func _process(_delta: float) -> bool:
	if _index >= PROBE_NAMES.size():
		_report()
		quit(0 if _failures == 0 else 1)
		return true

	var item_name := PROBE_NAMES[_index]

	if _phase == 0:
		# ---- Buoc A: chi GridMap ----
		var item_id := _find_item(item_name)
		if item_id < 0:
			_lines.append("%-24s KHONG TIM THAY ITEM TRONG LIBRARY" % item_name)
			_failures += 1
			_index += 1
			return false
		_gridmap.set_cell_item(Vector3i(0, 0, 0), item_id, 0)
		_settle = 0
		_phase = 1
		return false

	if _phase == 1:
		_settle += 1
		if _settle < 2:
			return false
		_grid_hits = _raycast()
		# Tat GridMap, bat scene goc
		_gridmap.set_cell_item(Vector3i(0, 0, 0), -1, 0)
		_ref = (load(TILE_DIR + item_name + ".tscn") as PackedScene).instantiate()
		_ref.name = "Ref"
		_ref.position = Vector3.ZERO
		root.add_child(_ref)
		_settle = 0
		_phase = 2
		return false

	if _phase == 2:
		_settle += 1
		if _settle < 2:
			return false
		var ref_hits := _raycast()
		_compare(item_name, _grid_hits, ref_hits)
		if _ref:
			root.remove_child(_ref)
			_ref.free()
			_ref = null
		_index += 1
		_phase = 0
		return false

	return false

func _raycast() -> Array[Vector3]:
	var space := _gridmap.get_world_3d().direct_space_state
	var out: Array[Vector3] = []
	for xz in PROBE_XZ:
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(xz.x, RAY_FROM.y, xz.y), Vector3(xz.x, RAY_TO.y, xz.y))
		var hit := space.intersect_ray(query)
		out.append((hit["position"] as Vector3) if not hit.is_empty() else Vector3(0, -999, 0))
	return out

func _compare(item_name: String, grid_hits: Array[Vector3], ref_hits: Array[Vector3]) -> void:
	var mismatch := 0
	var first_bad := -1
	for i in range(mini(grid_hits.size(), ref_hits.size())):
		if not grid_hits[i].is_equal_approx(ref_hits[i]):
			mismatch += 1
			if first_bad < 0:
				first_bad = i
	if mismatch == 0:
		_lines.append("%-24s KHOP  (%s)" % [item_name, _fmt(ref_hits)])
	else:
		_failures += 1
		_lines.append("%-24s LECH %d/%d  grid=%s  goc=%s" % [
			item_name, mismatch, ref_hits.size(),
			_fmt(grid_hits), _fmt(ref_hits)])

func _fmt(hits: Array[Vector3]) -> String:
	var parts: Array[String] = []
	for h in hits:
		parts.append("%.2f" % h.y)
	return "[" + ", ".join(parts) + "]"

func _report() -> void:
	for line in _lines:
		print(line)
	print("")
	if _failures == 0:
		print("=== TAT CA %d ITEM KHOP VOI SCENE GOC ===" % PROBE_NAMES.size())
	else:
		print("=== %d/%d ITEM KHONG KHOP ===" % [_failures, PROBE_NAMES.size()])

func _find_item(item_name: String) -> int:
	for id in _library.get_item_list():
		if _library.get_item_name(id) == item_name:
			return id
	return -1
