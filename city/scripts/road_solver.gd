class_name RoadSolver
extends RefCounted

## Constraint-based road tile solver.
## For each road cell, picks from all tile×rotation options, excluding blacklisted combos.
## Works at generation time AND in real-time when player reports a bad tile.
##
## Architecture:
##   1. Meta map defines WHERE roads go (done by city_generator)
##   2. This solver decides WHICH tile+rotation goes in each road cell
##   3. Blacklist eliminates bad combos — over time, only correct ones survive
##   4. New assets just add more options to the candidate pool

# All road tile IDs (indices in the MeshLibrary)
var road_tile_ids: Array[int] = [0, 1, 2, 3, 4]  # straight, lights, corner, split, intersection

# All valid orientations (Godot orthogonal indices)
const ORIENTATIONS := [0, 16, 10, 22]  # 0°, 90°, 180°, 270°

# Blacklist: set of key strings — "tile:orient:N:S:W:E"
var blacklist: Dictionary = {}  # using dict for O(1) lookup

const DB_PATH := "res://reports/tile_database.json"


func load_blacklist() -> void:
	blacklist.clear()
	var abs_path: String = ProjectSettings.globalize_path(DB_PATH)
	var path := abs_path if FileAccess.file_exists(abs_path) else DB_PATH
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var data: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if data is Array:
				for key in data:
					blacklist[key] = true
	if blacklist.size() > 0:
		print("Road solver: %d blacklisted combos" % blacklist.size())


func save_blacklist() -> void:
	var keys: Array = blacklist.keys()
	var abs_path: String = ProjectSettings.globalize_path(DB_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(keys, "  "))
		file.close()


## Add a combo to the blacklist. Returns true if it was new.
func blacklist_cell(gridmap: GridMap, cell: Vector3i) -> bool:
	var key := make_key(gridmap, cell)
	if key == "" or blacklist.has(key):
		return false
	blacklist[key] = true
	save_blacklist()
	return true


## Remove a combo from the blacklist. Returns true if it existed.
func unblacklist_cell(gridmap: GridMap, cell: Vector3i) -> bool:
	var key := make_key(gridmap, cell)
	if key == "" or not blacklist.has(key):
		return false
	blacklist.erase(key)
	save_blacklist()
	return true


## Check if a cell's current state is blacklisted.
func is_blacklisted(gridmap: GridMap, cell: Vector3i) -> bool:
	var key := make_key(gridmap, cell)
	return key != "" and blacklist.has(key)


# =========================================================
# Solve: pick best tile+rotation for a road cell
# =========================================================

## Solve a single cell using connectivity rules.
## Picks the correct tile type and rotation based on neighbor connections.
## Blacklist further refines by eliminating known-bad combos.
func solve_cell(gridmap: GridMap, cell: Vector3i) -> void:
	var n := _is_road(gridmap, cell + Vector3i(0, 0, -1))
	var s := _is_road(gridmap, cell + Vector3i(0, 0, 1))
	var w := _is_road(gridmap, cell + Vector3i(-1, 0, 0))
	var e := _is_road(gridmap, cell + Vector3i(1, 0, 0))
	var count := int(n) + int(s) + int(w) + int(e)

	if count >= 4:
		gridmap.set_cell_item(cell, 4, 0)
		return

	if count == 3:
		# T-junction: 0°=missing N, 90°=missing W, 180°=missing S, 270°=missing E
		var rot := 0
		if not n: rot = 0
		elif not w: rot = 1
		elif not s: rot = 2
		elif not e: rot = 3
		var basis := Basis(Vector3.UP, deg_to_rad(90.0 * rot))
		gridmap.set_cell_item(cell, 3, gridmap.get_orthogonal_index_from_basis(basis))
		if not blacklist.has(make_key(gridmap, cell)):
			return

	elif count == 2:
		if n and s:
			var tile := 0 if randi() % 4 != 0 else 1
			gridmap.set_cell_item(cell, tile, 0)
			if not blacklist.has(make_key(gridmap, cell)):
				return
		elif w and e:
			var tile := 0 if randi() % 4 != 0 else 1
			gridmap.set_cell_item(cell, tile, 16)
			if not blacklist.has(make_key(gridmap, cell)):
				return
		else:
			# Corner: 0°=S+W, 90°=S+E, 180°=N+E, 270°=N+W
			var rot := 0
			if s and w: rot = 0
			elif s and e: rot = 1
			elif n and e: rot = 2
			elif n and w: rot = 3
			var basis := Basis(Vector3.UP, deg_to_rad(90.0 * rot))
			gridmap.set_cell_item(cell, 2, gridmap.get_orthogonal_index_from_basis(basis))
			if not blacklist.has(make_key(gridmap, cell)):
				return

	elif count <= 1:
		gridmap.set_cell_item(cell, 5, 0)
		return

	# Fallback: intersection
	gridmap.set_cell_item(cell, 4, 0)


func _is_road(gridmap: GridMap, cell: Vector3i) -> bool:
	var id: int = gridmap.get_cell_item(cell)
	return id >= 0 and id <= 4


## Solve a cell AND its immediate road neighbors (for real-time fixing).
func solve_cell_and_neighbors(gridmap: GridMap, cell: Vector3i) -> void:
	solve_cell(gridmap, cell)
	for offset in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
		var neighbor: Vector3i = cell + offset
		var nid: int = gridmap.get_cell_item(neighbor)
		if nid >= 0 and nid <= 4:  # is a road tile
			if is_blacklisted(gridmap, neighbor):
				solve_cell(gridmap, neighbor)


## Solve ALL road cells in the gridmap.
func solve_all(gridmap: GridMap) -> int:
	var solved := 0
	# Multiple passes to handle cascades
	for pass_num in range(3):
		var fixed_this_pass := 0
		for cell in gridmap.get_used_cells():
			var tid: int = gridmap.get_cell_item(cell)
			if tid < 0 or tid > 4:
				continue
			if is_blacklisted(gridmap, cell):
				solve_cell(gridmap, cell)
				fixed_this_pass += 1
		solved += fixed_this_pass
		if fixed_this_pass == 0:
			break  # converged
	return solved


# =========================================================
# Key generation
# =========================================================

func make_key(gridmap: GridMap, cell: Vector3i) -> String:
	var tid: int = gridmap.get_cell_item(cell)
	if tid == -1:
		return ""
	var to: int = gridmap.get_cell_item_orientation(cell)
	var n := _nb(gridmap, cell + Vector3i(0, 0, -1))
	var s := _nb(gridmap, cell + Vector3i(0, 0, 1))
	var w := _nb(gridmap, cell + Vector3i(-1, 0, 0))
	var e := _nb(gridmap, cell + Vector3i(1, 0, 0))
	return "%d:%d:%s:%s:%s:%s" % [tid, to, n, s, w, e]


func _nb(gridmap: GridMap, cell: Vector3i) -> String:
	var nid: int = gridmap.get_cell_item(cell)
	if nid == -1:
		return "-"
	return "%d.%d" % [nid, gridmap.get_cell_item_orientation(cell)]


func _count_road_neighbors(gridmap: GridMap, cell: Vector3i) -> int:
	var count := 0
	for offset in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
		var nid: int = gridmap.get_cell_item(cell + offset)
		if nid >= 0 and nid <= 4:
			count += 1
	return count
