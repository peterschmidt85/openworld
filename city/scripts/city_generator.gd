extends Node

## SF-inspired procedural city with context-aware roads and rich props.

# Original structure indices (0-14)
const ROAD_STRAIGHT := 0
const ROAD_LIGHTS := 1
const ROAD_CORNER := 2
const ROAD_SPLIT := 3
const ROAD_INTERSECTION := 4
const PAVEMENT := 5
const FOUNTAIN := 6
const BLDG_A := 7
const BLDG_B := 8
const BLDG_C := 9
const BLDG_D := 10
const GARAGE := 11
const GRASS := 12
const TREES := 13
const TREES_TALL := 14

# Extended model indices (set by builder)
var commercial_ids: Array[int] = []
var skyscraper_ids: Array[int] = []
var commercial_detail_ids: Array[int] = []
var industrial_ids: Array[int] = []
var industrial_detail_ids: Array[int] = []
var suburban_ids: Array[int] = []
var suburban_fence_ids: Array[int] = []
var suburban_path_ids: Array[int] = []
var suburban_prop_ids: Array[int] = []
var suburban_tree_ids: Array[int] = []

@export var grid_size := 60
@export var road_spacing := 6

enum Cell { EMPTY, ROAD, BUILDING, SIDEWALK, PARK, PLAZA, WATER, GRASS_CELL }
var plan: Dictionary = {}

enum District { WATER, DOWNTOWN, COMMERCIAL, RESIDENTIAL, INDUSTRIAL, PARK, PLAZA, WATERFRONT }
var district_map: Dictionary = {}


var road_solver: RoadSolver = null
const STRUCTURE_NAMES := {
	0: "road-straight", 1: "road-lights", 2: "road-corner",
	3: "road-split", 4: "road-intersection", 5: "pavement",
	6: "fountain", 7: "building-a", 8: "building-b",
	9: "building-c", 10: "building-d", 11: "garage",
	12: "grass", 13: "trees", 14: "trees-tall"
}


func generate(gridmap: GridMap) -> void:
	gridmap.clear()
	seed(42)

	# Initialize road solver with blacklist
	road_solver = RoadSolver.new()
	road_solver.load_blacklist()

	_generate_districts()
	_plan_roads()
	_trim_dead_end_roads()
	_plan_sidewalks()
	_plan_blocks()
	_resolve_tiles(gridmap)

	# Let the solver fix any blacklisted road tiles
	var fixed := road_solver.solve_all(gridmap)
	print("City generated: %dx%d (%d road tiles re-solved)" % [grid_size, grid_size, fixed])


# =========================================================
# Districts
# =========================================================

func _generate_districts() -> void:
	district_map.clear()
	var bay_start := int(grid_size * 0.82)

	for x in range(grid_size):
		for z in range(grid_size):
			var pos := Vector2i(x, z)
			if x >= bay_start:
				district_map[pos] = District.WATER
			elif x >= int(grid_size * 0.02) and x < int(grid_size * 0.35) and z >= int(grid_size * 0.4) and z < int(grid_size * 0.5):
				district_map[pos] = District.PARK
			elif _is_plaza(x, z):
				district_map[pos] = District.PLAZA
			elif x >= bay_start - 6:
				district_map[pos] = District.WATERFRONT
			else:
				var dt_dist := sqrt((x - bay_start * 0.7) ** 2 + (z - grid_size * 0.35) ** 2)
				if dt_dist < grid_size * 0.18:
					district_map[pos] = District.DOWNTOWN
				elif dt_dist < grid_size * 0.3:
					district_map[pos] = District.COMMERCIAL
				elif z > grid_size * 0.78:
					district_map[pos] = District.INDUSTRIAL
				else:
					district_map[pos] = District.RESIDENTIAL


func _is_plaza(x: int, z: int) -> bool:
	if x % road_spacing == 0 or z % road_spacing == 0:
		return false
	for p in [Rect2i(int(grid_size*0.55), int(grid_size*0.3), 3, 3),
			  Rect2i(int(grid_size*0.35), int(grid_size*0.55), 2, 2),
			  Rect2i(int(grid_size*0.65), int(grid_size*0.6), 2, 3)]:
		if x >= p.position.x and x < p.position.x + p.size.x and z >= p.position.y and z < p.position.y + p.size.y:
			return true
	return false


# =========================================================
# Plan roads
# =========================================================

func _plan_roads() -> void:
	for x in range(grid_size):
		for z in range(grid_size):
			var pos := Vector2i(x, z)
			var district: District = district_map.get(pos, District.RESIDENTIAL)
			var on_grid := x % road_spacing == 0 or z % road_spacing == 0
			if district == District.WATER:
				plan[pos] = Cell.WATER
			elif district == District.PLAZA:
				plan[pos] = Cell.PLAZA
			elif on_grid:
				plan[pos] = Cell.ROAD
			elif district == District.PARK:
				plan[pos] = Cell.PARK
			else:
				plan[pos] = Cell.EMPTY


func _trim_dead_end_roads() -> void:
	var changed := true
	while changed:
		changed = false
		for pos in plan.keys():
			if plan[pos] != Cell.ROAD:
				continue
			var count := 0
			for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				if plan.get(pos + off, Cell.WATER) == Cell.ROAD:
					count += 1
			if count <= 1:
				plan[pos] = Cell.SIDEWALK
				changed = true


# =========================================================
# Plan sidewalks
# =========================================================

func _plan_sidewalks() -> void:
	var road_cells: Array[Vector2i] = []
	for pos in plan:
		if plan[pos] == Cell.ROAD:
			road_cells.append(pos)

	for pos in road_cells:
		for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var neighbor: Vector2i = pos + offset
			if plan.get(neighbor, Cell.WATER) == Cell.EMPTY:
				plan[neighbor] = Cell.SIDEWALK


# =========================================================
# Plan blocks
# =========================================================

func _plan_blocks() -> void:
	for pos in plan:
		if plan[pos] == Cell.EMPTY:
			var district: District = district_map.get(pos, District.RESIDENTIAL)
			match district:
				District.DOWNTOWN:
					plan[pos] = Cell.BUILDING if randf() < 0.75 else Cell.GRASS_CELL
				District.COMMERCIAL:
					plan[pos] = Cell.BUILDING if randf() < 0.55 else Cell.GRASS_CELL
				District.RESIDENTIAL:
					plan[pos] = Cell.BUILDING if randf() < 0.35 else Cell.GRASS_CELL
				District.INDUSTRIAL:
					plan[pos] = Cell.BUILDING if randf() < 0.40 else Cell.GRASS_CELL
				District.WATERFRONT:
					plan[pos] = Cell.BUILDING if randf() < 0.15 else Cell.GRASS_CELL
				_:
					plan[pos] = Cell.GRASS_CELL


# =========================================================
# Resolve tiles
# =========================================================

func _resolve_tiles(gridmap: GridMap) -> void:
	for x in range(grid_size):
		for z in range(grid_size):
			var pos := Vector2i(x, z)
			var cell: Cell = plan.get(pos, Cell.WATER)
			match cell:
				Cell.WATER:
					pass
				Cell.ROAD:
					_resolve_road(gridmap, x, z)
				Cell.SIDEWALK:
					_resolve_sidewalk(gridmap, x, z)
				Cell.BUILDING:
					_resolve_building(gridmap, x, z)
				Cell.PARK:
					_resolve_park(gridmap, x, z)
				Cell.PLAZA:
					_resolve_plaza(gridmap, x, z)
				Cell.GRASS_CELL:
					_resolve_grass(gridmap, x, z)


# =========================================================
# Roads — context-aware with proper corners and T-splits
# =========================================================

func _is_road(x: int, z: int) -> bool:
	return plan.get(Vector2i(x, z), Cell.WATER) == Cell.ROAD


func _resolve_road(gridmap: GridMap, x: int, z: int) -> void:
	# Orientation mapping: 0=0°, 16=90°, 10=180°, 22=270°
	#   road-straight: 0° = N-S, 90° = E-W
	#   road-corner:   0° = S+W, 90° = S+E, 180° = N+E, 270° = N+W
	#   road-split:    0° = missing N (S,W,E), 90° = missing W (N,S,E), 180° = missing S (N,W,E), 270° = missing E (N,S,W)

	var n := _is_road(x, z - 1)
	var s := _is_road(x, z + 1)
	var w := _is_road(x - 1, z)
	var e := _is_road(x + 1, z)
	var count := int(n) + int(s) + int(w) + int(e)

	if count >= 4:
		gridmap.set_cell_item(Vector3i(x, 0, z), ROAD_INTERSECTION)

	elif count == 3:
		var rot := 0
		if not n: rot = 0      # 0°: has S, W, E
		elif not w: rot = 1    # 90°: has N, S, E
		elif not s: rot = 2    # 180°: has N, W, E
		elif not e: rot = 3    # 270°: has N, S, W
		var basis := Basis(Vector3.UP, deg_to_rad(90.0 * rot))
		gridmap.set_cell_item(Vector3i(x, 0, z), ROAD_SPLIT, gridmap.get_orthogonal_index_from_basis(basis))

	elif count == 2:
		if n and s:
			var item := ROAD_STRAIGHT if randi() % 5 != 0 else ROAD_LIGHTS
			gridmap.set_cell_item(Vector3i(x, 0, z), item)
		elif w and e:
			var item := ROAD_STRAIGHT if randi() % 5 != 0 else ROAD_LIGHTS
			var basis := Basis(Vector3.UP, deg_to_rad(90))
			gridmap.set_cell_item(Vector3i(x, 0, z), item, gridmap.get_orthogonal_index_from_basis(basis))
		else:
			var rot := 0
			if s and w: rot = 0      # 0°: S+W
			elif s and e: rot = 1    # 90°: S+E
			elif n and e: rot = 2    # 180°: N+E
			elif n and w: rot = 3    # 270°: N+W
			var basis := Basis(Vector3.UP, deg_to_rad(90.0 * rot))
			gridmap.set_cell_item(Vector3i(x, 0, z), ROAD_CORNER, gridmap.get_orthogonal_index_from_basis(basis))

	elif count <= 1:
		gridmap.set_cell_item(Vector3i(x, 0, z), PAVEMENT)


# =========================================================
# Sidewalks — with props (awnings on commercial, fences on residential)
# =========================================================

func _resolve_sidewalk(gridmap: GridMap, x: int, z: int) -> void:
	var district: District = district_map.get(Vector2i(x, z), District.RESIDENTIAL)

	# Occasional props on sidewalks
	if district == District.COMMERCIAL or district == District.DOWNTOWN:
		if commercial_detail_ids.size() > 0 and randf() < 0.12:
			var rot := _facing_road_rotation(x, z)
			var basis := Basis(Vector3.UP, deg_to_rad(90.0 * rot))
			gridmap.set_cell_item(Vector3i(x, 0, z), commercial_detail_ids[randi() % commercial_detail_ids.size()],
				gridmap.get_orthogonal_index_from_basis(basis))
			return

	if district == District.RESIDENTIAL:
		if suburban_fence_ids.size() > 0 and randf() < 0.15:
			var rot := _facing_road_rotation(x, z)
			var basis := Basis(Vector3.UP, deg_to_rad(90.0 * rot))
			gridmap.set_cell_item(Vector3i(x, 0, z), suburban_fence_ids[randi() % suburban_fence_ids.size()],
				gridmap.get_orthogonal_index_from_basis(basis))
			return

	gridmap.set_cell_item(Vector3i(x, 0, z), PAVEMENT)


# =========================================================
# Buildings — face nearest road, district-appropriate
# =========================================================

func _resolve_building(gridmap: GridMap, x: int, z: int) -> void:
	var district: District = district_map.get(Vector2i(x, z), District.RESIDENTIAL)
	var rot := _facing_road_rotation(x, z)
	var basis := Basis(Vector3.UP, deg_to_rad(90.0 * rot))
	var orth := gridmap.get_orthogonal_index_from_basis(basis)

	match district:
		District.DOWNTOWN:
			if skyscraper_ids.size() > 0 and randf() < 0.5:
				gridmap.set_cell_item(Vector3i(x, 0, z), skyscraper_ids[randi() % skyscraper_ids.size()], orth)
			elif commercial_ids.size() > 0:
				gridmap.set_cell_item(Vector3i(x, 0, z), commercial_ids[randi() % commercial_ids.size()], orth)
			else:
				gridmap.set_cell_item(Vector3i(x, 0, z), BLDG_A + randi() % 4, orth)

		District.COMMERCIAL, District.WATERFRONT:
			if commercial_ids.size() > 0:
				gridmap.set_cell_item(Vector3i(x, 0, z), commercial_ids[randi() % commercial_ids.size()], orth)
			else:
				gridmap.set_cell_item(Vector3i(x, 0, z), BLDG_A + randi() % 4, orth)

		District.RESIDENTIAL:
			if suburban_ids.size() > 0:
				gridmap.set_cell_item(Vector3i(x, 0, z), suburban_ids[randi() % suburban_ids.size()], orth)
			else:
				gridmap.set_cell_item(Vector3i(x, 0, z), BLDG_A + randi() % 4, orth)

		District.INDUSTRIAL:
			if industrial_ids.size() > 0:
				gridmap.set_cell_item(Vector3i(x, 0, z), industrial_ids[randi() % industrial_ids.size()], orth)
			else:
				gridmap.set_cell_item(Vector3i(x, 0, z), GARAGE, orth)

		_:
			gridmap.set_cell_item(Vector3i(x, 0, z), BLDG_A + randi() % 4, orth)


func _facing_road_rotation(x: int, z: int) -> int:
	for dist in range(1, road_spacing):
		if _is_road(x, z - dist): return 0
		if _is_road(x + dist, z): return 1
		if _is_road(x, z + dist): return 2
		if _is_road(x - dist, z): return 3
	return randi() % 4


# =========================================================
# Parks — with suburban trees and paths
# =========================================================

func _resolve_park(gridmap: GridMap, x: int, z: int) -> void:
	var roll := randf()
	if suburban_tree_ids.size() > 0 and roll < 0.25:
		gridmap.set_cell_item(Vector3i(x, 0, z), suburban_tree_ids[randi() % suburban_tree_ids.size()])
	elif roll < 0.45:
		gridmap.set_cell_item(Vector3i(x, 0, z), TREES)
	elif roll < 0.60:
		gridmap.set_cell_item(Vector3i(x, 0, z), TREES_TALL)
	elif suburban_path_ids.size() > 0 and roll < 0.70:
		gridmap.set_cell_item(Vector3i(x, 0, z), suburban_path_ids[randi() % suburban_path_ids.size()])
	elif roll < 0.75:
		gridmap.set_cell_item(Vector3i(x, 0, z), FOUNTAIN)
	else:
		gridmap.set_cell_item(Vector3i(x, 0, z), GRASS)


func _resolve_plaza(gridmap: GridMap, x: int, z: int) -> void:
	if randf() < 0.15:
		gridmap.set_cell_item(Vector3i(x, 0, z), FOUNTAIN)
	elif suburban_prop_ids.size() > 0 and randf() < 0.1:
		gridmap.set_cell_item(Vector3i(x, 0, z), suburban_prop_ids[randi() % suburban_prop_ids.size()])
	elif randf() < 0.08:
		gridmap.set_cell_item(Vector3i(x, 0, z), TREES)
	else:
		gridmap.set_cell_item(Vector3i(x, 0, z), PAVEMENT)


# =========================================================
# Grass — with varied vegetation
# =========================================================

func _resolve_grass(gridmap: GridMap, x: int, z: int) -> void:
	var district: District = district_map.get(Vector2i(x, z), District.RESIDENTIAL)
	var roll := randf()

	if district == District.RESIDENTIAL:
		# Residential grass gets suburban trees, planters, paths
		if suburban_tree_ids.size() > 0 and roll < 0.2:
			gridmap.set_cell_item(Vector3i(x, 0, z), suburban_tree_ids[randi() % suburban_tree_ids.size()])
		elif suburban_prop_ids.size() > 0 and roll < 0.28:
			gridmap.set_cell_item(Vector3i(x, 0, z), suburban_prop_ids[randi() % suburban_prop_ids.size()])
		elif roll < 0.55:
			gridmap.set_cell_item(Vector3i(x, 0, z), GRASS)
		elif roll < 0.75:
			gridmap.set_cell_item(Vector3i(x, 0, z), TREES)
		else:
			gridmap.set_cell_item(Vector3i(x, 0, z), TREES_TALL)

	elif district == District.INDUSTRIAL:
		# Industrial gets more pavement than grass
		if roll < 0.6:
			gridmap.set_cell_item(Vector3i(x, 0, z), PAVEMENT)
		elif industrial_detail_ids.size() > 0 and roll < 0.7:
			gridmap.set_cell_item(Vector3i(x, 0, z), industrial_detail_ids[randi() % industrial_detail_ids.size()])
		else:
			gridmap.set_cell_item(Vector3i(x, 0, z), GRASS)
	else:
		if roll < 0.5:
			gridmap.set_cell_item(Vector3i(x, 0, z), GRASS)
		elif roll < 0.75:
			gridmap.set_cell_item(Vector3i(x, 0, z), TREES)
		else:
			gridmap.set_cell_item(Vector3i(x, 0, z), TREES_TALL)

