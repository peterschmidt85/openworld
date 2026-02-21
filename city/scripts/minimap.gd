extends Control

## Minimap: top-right corner, proportional to city shape, live 3D top-down view.

var grid_size := 60
var map_max_side := 180.0

var sub_viewport: SubViewport
var minimap_cam: Camera3D
var player_dot: Control
var svc: SubViewportContainer

var city_min := Vector2.ZERO
var city_max := Vector2.ZERO


func setup(plan: Dictionary, p_grid_size: int, _cell_types) -> void:
	grid_size = p_grid_size
	_compute_bounds(plan)
	call_deferred("_build")


func _compute_bounds(plan: Dictionary) -> void:
	var min_x := grid_size
	var min_z := grid_size
	var max_x := 0
	var max_z := 0
	for pos in plan:
		if plan[pos] == 6:
			continue
		min_x = mini(min_x, pos.x)
		min_z = mini(min_z, pos.y)
		max_x = maxi(max_x, pos.x)
		max_z = maxi(max_z, pos.y)
	city_min = Vector2(min_x, min_z)
	city_max = Vector2(max_x + 1, max_z + 1)


func _build() -> void:
	var city_w: float = city_max.x - city_min.x
	var city_h: float = city_max.y - city_min.y
	var aspect: float = city_w / city_h if city_h > 0 else 1.0

	var map_w: float
	var map_h: float
	if aspect >= 1.0:
		map_w = map_max_side
		map_h = map_max_side / aspect
	else:
		map_h = map_max_side
		map_w = map_max_side * aspect

	svc = SubViewportContainer.new()
	svc.stretch = true
	svc.anchor_left = 1.0
	svc.anchor_right = 1.0
	svc.anchor_top = 0.0
	svc.offset_left = -(map_w + 12)
	svc.offset_right = -10
	svc.offset_top = 10
	svc.offset_bottom = map_h + 12
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)

	# SubViewport inside the container
	sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(int(map_w * 2), int(map_h * 2))
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.transparent_bg = false
	svc.add_child(sub_viewport)

	# Orthographic camera covers the city
	minimap_cam = Camera3D.new()
	minimap_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_cam.size = maxf(city_w, city_h) * 1.02
	minimap_cam.position = Vector3((city_min.x + city_max.x) / 2.0, 100, (city_min.y + city_max.y) / 2.0)
	minimap_cam.rotation_degrees = Vector3(-90, 0, 0)
	minimap_cam.far = 200.0
	minimap_cam.near = 0.1
	sub_viewport.add_child(minimap_cam)

	# Player dot
	player_dot = Control.new()
	player_dot.z_index = 10
	player_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_dot)
	player_dot.draw.connect(func():
		player_dot.draw_circle(Vector2.ZERO, 4, Color(1, 1, 1, 0.95))
		player_dot.draw_circle(Vector2.ZERO, 2.5, Color(0.2, 0.6, 1.0))
	)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		var show := not svc.visible
		svc.visible = show
		player_dot.visible = show
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if player_dot == null:
		return
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return

	if not svc.visible:
		return
	var p: Vector3 = players[0].global_position
	var nx: float = clampf((p.x - city_min.x) / (city_max.x - city_min.x), 0, 1)
	var nz: float = clampf((p.z - city_min.y) / (city_max.y - city_min.y), 0, 1)
	var svc_pos := svc.global_position
	var svc_sz := svc.size
	player_dot.position = Vector2(svc_pos.x + nx * svc_sz.x, svc_pos.y + nz * svc_sz.y)
	player_dot.queue_redraw()
