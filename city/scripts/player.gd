extends CharacterBody3D

## Player controller: WASD movement (collision-based) + click-to-move (A* pathfinding).

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var acceleration := 10.0
@export var rotation_speed := 10.0

var pathfinder: AStarGrid2D = null
var building_entrances: Dictionary = {}
var path_points: PackedVector2Array = PackedVector2Array()
var path_index := 0
var _path_log_counter := 0
var _approach_target: Node3D = null
var _approach_building_pos := Vector3.INF

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var model: Node3D = null
var animation_player: AnimationPlayer = null


func _ready() -> void:
	add_to_group("player")
	call_deferred("_find_model")


func _find_model() -> void:
	model = get_node_or_null("Model")
	if model:
		animation_player = _find_anim_player(model)
		if animation_player:
			for anim_name in ["walk", "sprint", "idle"]:
				if animation_player.has_animation(anim_name):
					var anim: Animation = animation_player.get_animation(anim_name)
					if anim.loop_mode == Animation.LOOP_NONE:
						anim.loop_mode = Animation.LOOP_LINEAR
			print("Player animation player found with ", animation_player.get_animation_list().size(), " animations")


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_anim_player(child)
		if result:
			return result
	return null


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Vector3.ZERO

	# WASD — direct movement with collision
	var raw_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    raw_input.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  raw_input.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  raw_input.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): raw_input.x += 1

	if raw_input.length() > 0:
		raw_input = raw_input.normalized()
		path_points = PackedVector2Array()
		_approach_target = null
		_approach_building_pos = Vector3.INF

		var cam := get_viewport().get_camera_3d()
		if cam:
			var cam_basis := cam.global_transform.basis
			var forward := -cam_basis.z
			forward.y = 0
			forward = forward.normalized()
			var right := cam_basis.x
			right.y = 0
			right = right.normalized()
			input_dir = (forward * -raw_input.y + right * raw_input.x).normalized()
		else:
			input_dir = Vector3(raw_input.x, 0, raw_input.y)

	elif path_points.size() > 0 and path_index < path_points.size():
		if _approach_target and is_instance_valid(_approach_target):
			var dist_to := global_position.distance_to(_approach_target.global_position)
			if dist_to < 0.8:
				path_points = PackedVector2Array()
				_approach_target = null
				velocity.x = 0
				velocity.z = 0
				_update_animation()
				return

		if _approach_building_pos != Vector3.INF:
			var dist_to := global_position.distance_to(_approach_building_pos)
			if dist_to < 0.8:
				path_points = PackedVector2Array()
				_approach_building_pos = Vector3.INF
				velocity.x = 0
				velocity.z = 0
				_update_animation()
				return

		# Direct position movement along A* path (no collision)
		var target_cell := path_points[path_index]
		var target_pos := Vector3(target_cell.x + 0.5, global_position.y, target_cell.y + 0.5)
		var to_target := target_pos - global_position
		to_target.y = 0

		if to_target.length() < 0.2:
			path_index += 1
			if path_index >= path_points.size():
				path_points = PackedVector2Array()
		else:
			var step := to_target.normalized() * walk_speed * delta
			if step.length() > to_target.length():
				step = to_target
			global_position += step
			if model and to_target.length() > 0.1:
				var target_angle := atan2(to_target.x, to_target.z)
				model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)
			velocity.x = to_target.normalized().x * walk_speed
			velocity.z = to_target.normalized().z * walk_speed
		_update_animation()
		return
	elif path_points.size() > 0:
		path_points = PackedVector2Array()

	# WASD collision-based movement
	var is_running := Input.is_key_pressed(KEY_SHIFT)
	var speed := run_speed if is_running else walk_speed

	var target_velocity := input_dir * speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if input_dir.length() > 0.1 and model:
		var target_angle := atan2(input_dir.x, input_dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)

	_update_animation()
	move_and_slide()


func _update_animation() -> void:
	if animation_player == null:
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_running := Input.is_key_pressed(KEY_SHIFT)

	if horizontal_speed > 0.5:
		var anim := "sprint" if is_running and animation_player.has_animation("sprint") else "walk"
		if animation_player.has_animation(anim):
			if animation_player.current_animation != anim:
				animation_player.play(anim)
			animation_player.speed_scale = clampf(horizontal_speed / walk_speed, 0.5, 2.0)
	else:
		if animation_player.has_animation("idle"):
			if animation_player.current_animation != "idle":
				animation_player.play("idle")
		else:
			animation_player.stop()


func _input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_TAB):
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_click_to_move(event.position)


func _click_to_move(screen_pos: Vector2) -> void:
	if pathfinder == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var ray_from := cam.project_ray_origin(screen_pos)
	var ray_dir := cam.project_ray_normal(screen_pos)

	var target_world: Vector3
	var clicked_npc: CharacterBody3D = null
	var clicked_building := false
	_approach_target = null
	_approach_building_pos = Vector3.INF
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_from + ray_dir * 200.0, 6)
	query.exclude = [get_rid()]
	var ray_result := space.intersect_ray(query)
	if not ray_result.is_empty():
		var collider = ray_result["collider"]
		if collider is CharacterBody3D:
			target_world = collider.global_position
			clicked_npc = collider
			_approach_target = collider
		else:
			target_world = ray_result["position"]
			clicked_building = true
	else:
		var plane := Plane(Vector3.UP, 0)
		var ground_hit: Variant = plane.intersects_ray(ray_from, ray_dir)
		if ground_hit == null:
			return
		target_world = ground_hit as Vector3
	var from_cell := Vector2i(int(floor(global_position.x)), int(floor(global_position.z)))
	var to_cell := Vector2i(int(floor(target_world.x)), int(floor(target_world.z)))

	# Clamp to grid bounds
	var region := pathfinder.region
	from_cell = from_cell.clamp(region.position, region.position + region.size - Vector2i.ONE)
	to_cell = to_cell.clamp(region.position, region.position + region.size - Vector2i.ONE)

	if pathfinder.is_point_solid(from_cell):
		from_cell = _nearest_walkable(from_cell)
	if clicked_building:
		var entrance := _find_building_entrance(to_cell)
		if entrance != Vector2i(-1, -1):
			to_cell = entrance
			_approach_building_pos = Vector3(_last_found_building_cell.x + 0.5, 0, _last_found_building_cell.y + 0.5)
		elif pathfinder.is_point_solid(to_cell):
			to_cell = _nearest_walkable(to_cell)
	elif pathfinder.is_point_solid(to_cell):
		to_cell = _nearest_walkable(to_cell)

	if from_cell == to_cell:
		return

	var blocked: Array[Vector2i] = []
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc == clicked_npc:
			continue
		var c := Vector2i(int(floor(npc.global_position.x)), int(floor(npc.global_position.z)))
		if c != from_cell and not pathfinder.is_point_solid(c):
			pathfinder.set_point_solid(c, true)
			blocked.append(c)

	if pathfinder.is_point_solid(to_cell):
		to_cell = _nearest_walkable(to_cell)
	if from_cell == to_cell:
		for c in blocked:
			pathfinder.set_point_solid(c, false)
		return

	path_points = pathfinder.get_point_path(from_cell, to_cell)
	path_index = 0

	if _approach_building_pos != Vector3.INF and path_points.size() > 0:
		path_points.append(Vector2(_last_found_building_cell.x, _last_found_building_cell.y))

	for c in blocked:
		pathfinder.set_point_solid(c, false)

	var dist := absi(from_cell.x - to_cell.x) + absi(from_cell.y - to_cell.y)
	if path_points.size() == 0:
		print("[PATH] FAILED %s → %s (no path! dist=%d)" % [from_cell, to_cell, dist])
	else:
		print("[PATH] %s → %s (%d steps, dist=%d, world=(%.0f,%.0f)→(%.0f,%.0f))" % [from_cell, to_cell, path_points.size(), dist, global_position.x, global_position.z, target_world.x, target_world.z])


var _last_found_building_cell := Vector2i(-1, -1)

func _find_building_entrance(cell: Vector2i) -> Vector2i:
	_last_found_building_cell = Vector2i(-1, -1)
	if building_entrances.has(cell):
		var e: Vector2i = building_entrances[cell]
		if not pathfinder.is_point_solid(e):
			_last_found_building_cell = cell
			return e
	for off in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var neighbor: Vector2i = cell + off
		if building_entrances.has(neighbor):
			var e: Vector2i = building_entrances[neighbor]
			if not pathfinder.is_point_solid(e):
				_last_found_building_cell = neighbor
				return e
	return Vector2i(-1, -1)


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	for radius in range(1, 5):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var c := cell + Vector2i(dx, dz)
				var region := pathfinder.region
				if c.x >= region.position.x and c.x < region.position.x + region.size.x and c.y >= region.position.y and c.y < region.position.y + region.size.y:
					if not pathfinder.is_point_solid(c):
						return c
	return cell
