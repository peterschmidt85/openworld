extends Node3D

## Auto-generates city using all available Kenney model packs.

@export var structures: Array[Structure] = []
@export var view_camera: Camera3D
@export var gridmap: GridMap

var player: CharacterBody3D


func _ready():
	var mesh_library = MeshLibrary.new()

	# Register original structures (indices 0-14)
	for i in range(structures.size()):
		var structure: Structure = structures[i]
		var id = mesh_library.get_last_unused_item_id()
		mesh_library.create_item(id)
		mesh_library.set_item_mesh(id, get_mesh(structure.model))
		mesh_library.set_item_mesh_transform(id, Transform3D())

	# Load ALL models from each pack (not just buildings)
	var commercial_building_ids := _load_models(mesh_library, "res://models/commercial/", "building-")
	var commercial_detail_ids := _load_models(mesh_library, "res://models/commercial/", "detail-")
	var industrial_building_ids := _load_models(mesh_library, "res://models/industrial/", "building-")
	var industrial_detail_ids := _load_models(mesh_library, "res://models/industrial/", "chimney-")
	var industrial_detail2 := _load_models(mesh_library, "res://models/industrial/", "detail-")
	industrial_detail_ids.append_array(industrial_detail2)
	var suburban_building_ids := _load_models(mesh_library, "res://models/suburban/", "building-")
	var suburban_fence_ids := _load_models(mesh_library, "res://models/suburban/", "fence")
	var suburban_path_ids := _load_models(mesh_library, "res://models/suburban/", "path-")
	var suburban_prop_ids := _load_models(mesh_library, "res://models/suburban/", "driveway-")
	var suburban_planter := _load_models(mesh_library, "res://models/suburban/", "planter")
	suburban_prop_ids.append_array(suburban_planter)
	var suburban_tree_ids := _load_models(mesh_library, "res://models/suburban/", "tree-")
	# Low-detail commercial for distant LOD
	var commercial_lod_ids := _load_models(mesh_library, "res://models/commercial/", "low-detail-")

	# Separate skyscrapers from regular commercial
	var skyscraper_ids: Array[int] = []
	var commercial_ids: Array[int] = []
	for id in commercial_building_ids:
		var mesh: Mesh = mesh_library.get_item_mesh(id)
		if mesh:
			var aabb: AABB = mesh.get_aabb()
			if aabb.size.y > 2.0:  # tall = skyscraper
				skyscraper_ids.append(id)
			else:
				commercial_ids.append(id)

	gridmap.mesh_library = mesh_library

	print("MeshLibrary: %d total items" % mesh_library.get_last_unused_item_id())
	print("  Commercial: %d, Skyscrapers: %d, Details: %d" % [commercial_ids.size(), skyscraper_ids.size(), commercial_detail_ids.size()])
	print("  Industrial: %d, Details: %d" % [industrial_building_ids.size(), industrial_detail_ids.size()])
	print("  Suburban buildings: %d, Fences: %d, Paths: %d, Props: %d, Trees: %d" % [
		suburban_building_ids.size(), suburban_fence_ids.size(), suburban_path_ids.size(),
		suburban_prop_ids.size(), suburban_tree_ids.size()])

	# Generate city
	var city_gen = preload("res://scripts/city_generator.gd").new()
	city_gen.commercial_ids = commercial_ids
	city_gen.skyscraper_ids = skyscraper_ids
	city_gen.commercial_detail_ids = commercial_detail_ids
	city_gen.industrial_ids = industrial_building_ids
	city_gen.industrial_detail_ids = industrial_detail_ids
	city_gen.suburban_ids = suburban_building_ids
	city_gen.suburban_fence_ids = suburban_fence_ids
	city_gen.suburban_path_ids = suburban_path_ids
	city_gen.suburban_prop_ids = suburban_prop_ids
	city_gen.suburban_tree_ids = suburban_tree_ids
	city_gen.generate(gridmap)

	# Collision
	_create_collisions(gridmap)

	# Ground + water
	_create_ground(city_gen.grid_size)
	_create_water(city_gen.grid_size)

	# Navigation mesh for pathfinding
	_create_navigation(city_gen)

	# Spawn player
	var spawn_x: float = city_gen.road_spacing / 2.0 + 1
	var spawn_z: float = city_gen.grid_size / 2.0
	player = PlayerSpawner.spawn(get_parent(), Vector3(spawn_x, 1.0, spawn_z))
	player.set("pathfinder", pathfinder)

	# Spawn NPCs
	_spawn_npcs(city_gen)

	# Feedback journal
	var reporter_script := load("res://scripts/tile_reporter.gd")
	var reporter := Node3D.new()
	reporter.name = "TileReporter"
	reporter.set_script(reporter_script)
	get_parent().add_child.call_deferred(reporter)
	reporter.setup.call_deferred(gridmap, view_camera)

	# Minimap
	var minimap_script := load("res://scripts/minimap.gd")
	var minimap := Control.new()
	minimap.name = "Minimap"
	minimap.set_script(minimap_script)
	minimap.set_anchors_preset(Control.PRESET_FULL_RECT)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child.call_deferred(minimap)
	minimap.setup.call_deferred(city_gen.plan, city_gen.grid_size, city_gen.Cell)

	# Atmosphere (day/night + fog)
	var atmo_script := load("res://scripts/atmosphere.gd")
	var atmo := Node.new()
	atmo.name = "Atmosphere"
	atmo.set_script(atmo_script)
	get_parent().add_child.call_deferred(atmo)
	var sun_node: DirectionalLight3D = get_parent().get_node("Sun")
	atmo.setup.call_deferred(sun_node, view_camera, gridmap)


func _load_models(mesh_library: MeshLibrary, dir_path: String, prefix: String) -> Array[int]:
	var ids: Array[int] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ids

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".glb") and file_name.begins_with(prefix):
			var scene: PackedScene = load(dir_path + file_name)
			if scene:
				var mesh: Mesh = get_mesh(scene)
				if mesh:
					var id := mesh_library.get_last_unused_item_id()
					mesh_library.create_item(id)
					mesh_library.set_item_mesh(id, mesh)
					mesh_library.set_item_mesh_transform(id, Transform3D())
					ids.append(id)
		file_name = dir.get_next()
	dir.list_dir_end()
	return ids


func _create_collisions(gridmap: GridMap) -> void:
	# Everything index >= 15 is from new packs (buildings). Also original 7-11.
	var shape_cache: Dictionary = {}
	var collision_root := StaticBody3D.new()
	collision_root.name = "CityCollision"
	var col_count := 0

	for cell in gridmap.get_used_cells():
		var item_id: int = gridmap.get_cell_item(cell)
		# Skip roads (0-4), pavement (5), fountain (6), grass/trees (12-14)
		if item_id <= 6 or (item_id >= 12 and item_id <= 14):
			continue

		if not shape_cache.has(item_id):
			var mesh: Mesh = gridmap.mesh_library.get_item_mesh(item_id)
			if mesh:
				shape_cache[item_id] = mesh.create_trimesh_shape()
			else:
				shape_cache[item_id] = null

		var shape: Shape3D = shape_cache.get(item_id)
		if shape == null:
			continue

		var col_shape := CollisionShape3D.new()
		col_shape.shape = shape
		var orientation: int = gridmap.get_cell_item_orientation(cell)
		var basis: Basis = gridmap.get_basis_with_orthogonal_index(orientation)
		col_shape.transform = Transform3D(basis, Vector3(cell.x, 0, cell.z))
		collision_root.add_child(col_shape)
		col_count += 1

	get_parent().add_child.call_deferred(collision_root)
	print("Building collisions: ", col_count)


func _create_ground(city_size: int) -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(city_size + 10, 0.2, city_size + 10)
	col.shape = shape
	col.position = Vector3(city_size / 2.0, -0.1, city_size / 2.0)
	ground.add_child(col)
	get_parent().add_child.call_deferred(ground)


func _create_water(city_size: int) -> void:
	var bay_start: float = city_size * 0.82
	var water := MeshInstance3D.new()
	water.name = "Water"
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(city_size * 0.5, city_size + 10)
	water.mesh = plane_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.30, 0.45, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.3
	mat.roughness = 0.2
	water.material_override = mat
	water.position = Vector3(bay_start + city_size * 0.25, -0.15, city_size / 2.0)
	get_parent().add_child.call_deferred(water)


var pathfinder: AStarGrid2D = null

func _create_navigation(city_gen) -> void:
	var plan: Dictionary = city_gen.plan
	var CellType = city_gen.Cell
	var grid_size: int = city_gen.grid_size
	var walkable := [CellType.ROAD, CellType.SIDEWALK, CellType.PARK, CellType.PLAZA]

	pathfinder = AStarGrid2D.new()
	pathfinder.region = Rect2i(0, 0, grid_size, grid_size)
	pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	pathfinder.update()

	var walkable_count := 0
	for x in range(grid_size):
		for z in range(grid_size):
			var pos := Vector2i(x, z)
			if plan.get(pos, CellType.WATER) in walkable:
				walkable_count += 1
			else:
				pathfinder.set_point_solid(pos, true)

	print("Pathfinder: %d walkable, %d blocked" % [walkable_count, grid_size * grid_size - walkable_count])


func _spawn_npcs(city_gen) -> void:
	var npc_spawner_script = load("res://scripts/npc_spawner.gd")
	var plan: Dictionary = city_gen.plan
	var district_map: Dictionary = city_gen.district_map
	var CellType = city_gen.Cell
	var DistrictType = city_gen.District

	var sidewalk_cells: Array[Vector2i] = []
	var entrance_cells: Array[Dictionary] = []

	for pos in plan:
		if plan[pos] == CellType.SIDEWALK:
			sidewalk_cells.append(pos)
			# Check if adjacent to a building (candidate for stationary NPC)
			for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				if plan.get(pos + off, CellType.WATER) == CellType.BUILDING:
					# Face toward the nearest road
					var facing := 0.0
					for road_off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
						if plan.get(pos + road_off, CellType.WATER) == CellType.ROAD:
							facing = atan2(float(road_off.x), float(road_off.y))
							break
					entrance_cells.append({"pos": pos, "facing": facing})
					break

	# Wandering NPCs (~30), biased toward downtown/commercial
	var wander_count := 0
	var downtown_sidewalks: Array[Vector2i] = []
	var other_sidewalks: Array[Vector2i] = []
	for cell in sidewalk_cells:
		var district = district_map.get(cell, DistrictType.RESIDENTIAL)
		if district == DistrictType.DOWNTOWN or district == DistrictType.COMMERCIAL:
			downtown_sidewalks.append(cell)
		else:
			other_sidewalks.append(cell)

	var wander_pool: Array[Vector2i] = []
	wander_pool.append_array(downtown_sidewalks)
	wander_pool.append_array(downtown_sidewalks)
	wander_pool.append_array(other_sidewalks)
	wander_pool.shuffle()

	for i in range(mini(30, wander_pool.size())):
		var cell: Vector2i = wander_pool[i]
		var pos := Vector3(cell.x + 0.5, 0.05, cell.y + 0.5)
		npc_spawner_script.spawn_wanderer(get_parent(), pos, sidewalk_cells, pathfinder)
		wander_count += 1

	# Stationary NPCs (~20) at building entrances
	entrance_cells.shuffle()
	var stationary_count := 0
	for i in range(mini(20, entrance_cells.size())):
		var entry: Dictionary = entrance_cells[i]
		var cell: Vector2i = entry["pos"]
		var facing: float = entry["facing"]
		var pos := Vector3(cell.x + 0.5, 0.05, cell.y + 0.5)
		npc_spawner_script.spawn_stationary(get_parent(), pos, facing)
		stationary_count += 1

	print("NPCs spawned: %d wandering, %d stationary" % [wander_count, stationary_count])


func get_mesh(packed_scene) -> Mesh:
	var scene_state: SceneState = packed_scene.get_state()
	for i in range(scene_state.get_node_count()):
		if(scene_state.get_node_type(i) == "MeshInstance3D"):
			for j in scene_state.get_node_property_count(i):
				var prop_name = scene_state.get_node_property_name(i, j)
				if prop_name == "mesh":
					var prop_value = scene_state.get_node_property_value(i, j)
					return prop_value.duplicate()
	return null
