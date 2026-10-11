extends SceneTree

## Sinh `scenes/Entity/Tile/tile_mesh_library.tres` từ 43 scene tile sẵn có.
##
## Chạy:  godot --headless --path . -s res://tools/build_tile_mesh_library.gd
##
## Mỗi item trong thư viện lấy nguyên mesh + collision shape của scene gốc, chỉ
## dịch gốc toạ độ về đúng tâm ô của GridMap nên đặt vào ô (0,0,0) sẽ cho hình
## học trùng với scene gốc đặt ở gốc trục.
##
## LƯU Ý về lưới: level 1 và level 2 hiện tại được đặt tay ở toạ độ liên tục
## (lệch trung bình ~0.7 so với ô 2x1x2) và có per-instance scale (vd
## TileHightDesert scale 4,2,1) — GridMap không lưu được scale theo ô. Vì vậy
## thư viện này dùng để DỰNG MỚI level 3/4, không dùng để chuyển level cũ.

const TILE_DIR := "res://scenes/Entity/Tile/"
const LIBRARY_PATH := "res://scenes/Entity/Tile/tile_mesh_library.tres"

## Ô chuẩn. 2x1x2 khớp với TileLow (tile chiếm nhiều nhất trong level 2: 464/576).
const CELL_SIZE := Vector3(2.0, 1.0, 2.0)
## GridMap mặc định cell_center = true cho cả 3 trục, nên tâm ô (0,0,0) nằm ở
## nửa ô. Bù lại để hình học trùng scene gốc.
const CELL_ORIGIN_OFFSET := Vector3(-1.0, -0.5, -1.0)

func _initialize() -> void:
	var library := MeshLibrary.new()
	var dir := DirAccess.open(TILE_DIR)
	var file_names: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".tscn") and f.begins_with("Tile"):
			file_names.append(f)
		elif f.ends_with(".tscn") and f.begins_with("Barier"):
			file_names.append(f)
	file_names.sort()

	var item_id := 0
	var report: Array[String] = []
	for file_name in file_names:
		var scene_path := TILE_DIR + file_name
		var entry := _build_item(library, item_id, scene_path)
		if entry.is_empty():
			report.append("BO QUA  %s (khong tim thay mesh hoac shape)" % file_name)
			item_id += 1
			continue
		report.append("%3d  %-30s mesh=%-28s shape=%-20s aabb=%s" % [
			item_id, entry["name"], entry["mesh_aabb"], entry["shape_info"], entry["aabb"]])
		item_id += 1

	print("=== Tao %s ===" % LIBRARY_PATH)
	print("cell_size = %s   cell_center = true/true/true" % CELL_SIZE)
	for line in report:
		print(line)
	print("Tong so item: ", library.get_item_list().size())

	var err := ResourceSaver.save(library, LIBRARY_PATH)
	if err != OK:
		printerr("LUU THAT BAI: ", err)
	else:
		print("Da luu ", LIBRARY_PATH)
	quit(0 if err == OK else 1)

func _build_item(library: MeshLibrary, item_id: int, scene_path: String) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return {}
	var root := packed.instantiate() as Node3D
	if root == null:
		return {}

	var mesh_node := _find_first(root, "MeshInstance3D") as MeshInstance3D
	var shape_node := _find_first(root, "CollisionShape3D") as CollisionShape3D
	if mesh_node == null or mesh_node.mesh == null or shape_node == null or shape_node.shape == null:
		root.free()
		return {}

	var item_name := scene_path.get_file().get_basename()
	var mesh_xform := _relative_transform(root, mesh_node)
	var shape_xform := _relative_transform(root, shape_node)

	# Dịch gốc từ (tile root) về tâm ô.
	var origin_fix := Transform3D(Basis.IDENTITY, CELL_ORIGIN_OFFSET)
	var final_mesh_xform := origin_fix * mesh_xform
	var final_shape_xform := origin_fix * shape_xform

	library.create_item(item_id)
	library.set_item_name(item_id, item_name)
	library.set_item_mesh(item_id, mesh_node.mesh)
	library.set_item_mesh_transform(item_id, final_mesh_xform)
	# Mang hinh 4.7: mang luon phiên Shape3D, Transform3D.
	library.set_item_shapes(item_id, [shape_node.shape, final_shape_xform])

	# Gom so lieu report TRUOC khi giai phong scene.
	var result := {
		"name": item_name,
		"mesh_aabb": str(mesh_node.mesh.get_aabb()),
		"shape_info": shape_node.shape.get_class(),
		"aabb": str(final_mesh_xform * mesh_node.mesh.get_aabb()),
	}
	root.free()
	return result

## Transform của `node` so với `root`, gom bằng local transform từ dưới lên.
## Không dùng global_transform vì node chưa nằm trong SceneTree.
func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node3D = node
	while current != null and current != root:
		xform = current.transform * xform
		current = current.get_parent() as Node3D
	return xform

func _find_first(node: Node, cls: String) -> Node:
	if node.is_class(cls):
		return node
	for child in node.get_children():
		var found := _find_first(child, cls)
		if found != null:
			return found
	return null
