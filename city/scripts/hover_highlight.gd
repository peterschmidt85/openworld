extends Node3D

## Highlights players, NPCs, and buildings with an outline when the mouse hovers over them.
## Uses physics raycasting (layers 2+3) and the inverted-hull outline shader.

var camera: Camera3D
var gridmap: GridMap
var building_cells: Dictionary = {}

var outline_mat: ShaderMaterial
var building_outline: MeshInstance3D

var _hovered_body: CollisionObject3D = null
var _hovered_meshes: Array[MeshInstance3D] = []
var _hovered_cell := Vector3i(-999, -999, -999)

const HOVER_MASK := 2 + 4  # layers 2 (characters) + 3 (buildings)


func setup(cam: Camera3D, gm: GridMap, bldg_cells: Dictionary) -> void:
	camera = cam
	gridmap = gm
	building_cells = bldg_cells

	var shader := load("res://shaders/outline.gdshader") as Shader
	outline_mat = ShaderMaterial.new()
	outline_mat.shader = shader

	building_outline = MeshInstance3D.new()
	building_outline.material_override = outline_mat
	building_outline.visible = false
	building_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(building_outline)


func _process(_delta: float) -> void:
	if camera == null or gridmap == null:
		return

	if Input.is_key_pressed(KEY_TAB):
		_clear_highlight()
		return

	var space := get_world_3d().direct_space_state
	if space == null:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 200.0

	var query := PhysicsRayQueryParameters3D.create(from, to, HOVER_MASK)
	var result := space.intersect_ray(query)

	if result.is_empty():
		_clear_highlight()
		return

	var collider: Object = result["collider"]

	if collider is CharacterBody3D:
		_highlight_character(collider as CharacterBody3D)
	elif collider is StaticBody3D:
		_highlight_building(result["position"] as Vector3)
	else:
		_clear_highlight()


func _highlight_character(body: CharacterBody3D) -> void:
	if body == _hovered_body:
		return
	_clear_highlight()
	_hovered_body = body

	var model := body.get_node_or_null("Model")
	if model == null:
		return
	_collect_mesh_instances(model)
	for mi in _hovered_meshes:
		mi.material_overlay = outline_mat

	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _highlight_building(hit_pos: Vector3) -> void:
	var cell := Vector3i(int(floor(hit_pos.x)), 0, int(floor(hit_pos.z)))
	if cell == _hovered_cell:
		return

	if not building_cells.has(Vector2i(cell.x, cell.z)):
		_clear_highlight()
		return

	_clear_highlight()
	_hovered_cell = cell

	var item_id := gridmap.get_cell_item(cell)
	if item_id < 0:
		return

	var mesh: Mesh = gridmap.mesh_library.get_item_mesh(item_id)
	if mesh == null:
		return

	var orient := gridmap.get_cell_item_orientation(cell)
	var basis := gridmap.get_basis_with_orthogonal_index(orient)
	building_outline.mesh = mesh
	building_outline.transform = Transform3D(basis, Vector3(cell.x, 0, cell.z))
	building_outline.visible = true

	_hovered_body = null
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _clear_highlight() -> void:
	for mi in _hovered_meshes:
		if is_instance_valid(mi):
			mi.material_overlay = null
	_hovered_meshes.clear()

	building_outline.visible = false

	if _hovered_body != null or _hovered_cell != Vector3i(-999, -999, -999):
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	_hovered_body = null
	_hovered_cell = Vector3i(-999, -999, -999)


func _collect_mesh_instances(node: Node) -> void:
	if node is MeshInstance3D:
		_hovered_meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child)
