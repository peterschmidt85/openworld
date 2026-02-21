extends Node3D

## Auto-generates city and spawns player. No manual building mode.

@export var structures: Array[Structure] = []
@export var view_camera: Camera3D
@export var gridmap: GridMap

var player: CharacterBody3D


func _ready():
	# Build MeshLibrary (visuals only — no GridMap collision)
	var mesh_library = MeshLibrary.new()
	for i in range(structures.size()):
		var structure: Structure = structures[i]
		var id = mesh_library.get_last_unused_item_id()
		mesh_library.create_item(id)
		mesh_library.set_item_mesh(id, get_mesh(structure.model))
		mesh_library.set_item_mesh_transform(id, Transform3D())
	gridmap.mesh_library = mesh_library

	# Generate city
	var city_gen = preload("res://scripts/city_generator.gd").new()
	city_gen.generate(gridmap)

	# Build trimesh collision from actual 3D mesh faces
	var solid_indices := [7, 8, 9, 10, 11]  # buildings + garage

	# Pre-generate collision shapes from each structure's mesh
	var collision_shapes: Dictionary = {}  # index -> ConcavePolygonShape3D
	for i in solid_indices:
		if i < structures.size():
			var mesh: Mesh = get_mesh(structures[i].model)
			if mesh:
				var shape := mesh.create_trimesh_shape()
				if shape:
					collision_shapes[i] = shape

	var collision_root := StaticBody3D.new()
	collision_root.name = "CityCollision"
	var col_count := 0

	for cell in gridmap.get_used_cells():
		var item_id: int = gridmap.get_cell_item(cell)
		if collision_shapes.has(item_id):
			var col_shape := CollisionShape3D.new()
			col_shape.shape = collision_shapes[item_id]
			# Position at cell + account for GridMap cell_center=false
			var orientation: int = gridmap.get_cell_item_orientation(cell)
			var basis: Basis = gridmap.get_basis_with_orthogonal_index(orientation)
			col_shape.transform = Transform3D(basis, Vector3(cell.x, 0, cell.z))
			collision_root.add_child(col_shape)
			col_count += 1

	get_parent().add_child.call_deferred(collision_root)
	print("Building collisions: ", col_count)

	# Navigation mesh for pathfinding
	_create_navigation(city_gen)

	# Ground plane
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(city_gen.grid_size + 10, 0.2, city_gen.grid_size + 10)
	ground_col.shape = ground_shape
	ground_col.position = Vector3(city_gen.grid_size / 2.0, -0.1, city_gen.grid_size / 2.0)
	ground.add_child(ground_col)
	get_parent().add_child.call_deferred(ground)

	# Spawn player on a road cell (not inside a building)
	var spawn_pos := Vector3(city_gen.road_spacing / 2.0, 1.0, city_gen.grid_size / 2.0)
	player = PlayerSpawner.spawn(get_parent(), spawn_pos)


func _create_navigation(city_gen) -> void:
	var nav_region := NavigationRegion3D.new()
	nav_region.name = "NavRegion"

	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.3
	nav_mesh.agent_height = 1.0
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25

	# Create walkable polygon vertices from road cells
	# Simple approach: one big ground plane, buildings excluded by geometry parsing
	var size: float = city_gen.grid_size + 2
	nav_mesh.set_vertices(PackedVector3Array([
		Vector3(-1, 0, -1),
		Vector3(size, 0, -1),
		Vector3(size, 0, size),
		Vector3(-1, 0, size),
	]))
	nav_mesh.add_polygon(PackedInt32Array([0, 1, 2]))
	nav_mesh.add_polygon(PackedInt32Array([0, 2, 3]))

	nav_region.navigation_mesh = nav_mesh
	get_parent().add_child.call_deferred(nav_region)

	# Bake after everything is in the scene
	nav_region.bake_navigation_mesh.call_deferred(true)
	print("Navigation region created, baking...")


func get_mesh(packed_scene):
	var scene_state: SceneState = packed_scene.get_state()
	for i in range(scene_state.get_node_count()):
		if(scene_state.get_node_type(i) == "MeshInstance3D"):
			for j in scene_state.get_node_property_count(i):
				var prop_name = scene_state.get_node_property_name(i, j)
				if prop_name == "mesh":
					var prop_value = scene_state.get_node_property_value(i, j)
					return prop_value.duplicate()
