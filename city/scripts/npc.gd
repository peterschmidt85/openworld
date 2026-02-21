extends CharacterBody3D

## NPC with two modes: "wander" (A* path between sidewalks) or "stationary" (idle at entrance).

@export var walk_speed := 1.5
@export var rotation_speed := 8.0

var mode := "wander"
var sidewalk_cells: Array[Vector2i] = []
var pathfinder: AStarGrid2D = null

var path_points: PackedVector2Array = PackedVector2Array()
var path_index := 0
var pause_timer := 0.0

var _settled := false
var model: Node3D = null
var animation_player: AnimationPlayer = null
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	call_deferred("_find_model")


func _find_model() -> void:
	model = get_node_or_null("Model")
	if model:
		animation_player = _find_anim_player(model)
		if animation_player:
			for anim_name in ["walk", "idle"]:
				if animation_player.has_animation(anim_name):
					var anim: Animation = animation_player.get_animation(anim_name)
					if anim.loop_mode == Animation.LOOP_NONE:
						anim.loop_mode = Animation.LOOP_LINEAR
			if mode == "stationary":
				_play_anim("idle")
			elif mode == "wander":
				pause_timer = randf_range(0.5, 3.0)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_anim_player(child)
		if result:
			return result
	return null


func _physics_process(delta: float) -> void:
	if mode == "wander":
		_process_wander(delta)
	elif mode == "stationary":
		if not _settled:
			velocity.y = -gravity
			move_and_slide()
			if is_on_floor():
				_settled = true


func _process_wander(delta: float) -> void:
	if pause_timer > 0:
		pause_timer -= delta
		velocity.x = 0
		velocity.z = 0
		_play_anim("idle")
		if pause_timer <= 0:
			_pick_wander_target()
		return

	if path_points.size() == 0 or path_index >= path_points.size():
		pause_timer = randf_range(2.0, 4.0)
		velocity.x = 0
		velocity.z = 0
		_play_anim("idle")
		return

	var target_cell := path_points[path_index]
	var target_pos := Vector3(target_cell.x + 0.5, global_position.y, target_cell.y + 0.5)
	var to_target := target_pos - global_position
	to_target.y = 0

	if to_target.length() < 0.2:
		path_index += 1
		if path_index >= path_points.size():
			path_points = PackedVector2Array()
			pause_timer = randf_range(2.0, 4.0)
			velocity.x = 0
			velocity.z = 0
			_play_anim("idle")
		return

	var step := to_target.normalized() * walk_speed * delta
	if step.length() > to_target.length():
		step = to_target
	global_position += step

	if model:
		var target_angle := atan2(to_target.x, to_target.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, rotation_speed * delta)

	velocity.x = to_target.normalized().x * walk_speed
	velocity.z = to_target.normalized().z * walk_speed
	_play_anim("walk")


func _pick_wander_target() -> void:
	if sidewalk_cells.size() == 0 or pathfinder == null:
		return
	var my_cell := Vector2i(int(floor(global_position.x)), int(floor(global_position.z)))

	var region := pathfinder.region
	my_cell = my_cell.clamp(region.position, region.position + region.size - Vector2i.ONE)

	# If NPC drifted into a solid cell, snap to nearest walkable
	if pathfinder.is_point_solid(my_cell):
		my_cell = _nearest_walkable_cell(my_cell)
		if pathfinder.is_point_solid(my_cell):
			return
		global_position = Vector3(my_cell.x + 0.5, global_position.y, my_cell.y + 0.5)

	# Pick a random nearby sidewalk on the same row or column (stay on sidewalks)
	var nearby: Array[Vector2i] = []
	for cell in sidewalk_cells:
		if cell.x == my_cell.x or cell.y == my_cell.y:
			var dist := absi(cell.x - my_cell.x) + absi(cell.y - my_cell.y)
			if dist >= 2 and dist <= 10:
				nearby.append(cell)
	if nearby.size() == 0:
		for cell in sidewalk_cells:
			var dist := absi(cell.x - my_cell.x) + absi(cell.y - my_cell.y)
			if dist >= 2 and dist <= 8:
				nearby.append(cell)
	if nearby.size() == 0:
		return

	var target: Vector2i = nearby[randi() % nearby.size()]
	target = target.clamp(region.position, region.position + region.size - Vector2i.ONE)

	path_points = pathfinder.get_point_path(my_cell, target)
	path_index = 0


func _nearest_walkable_cell(cell: Vector2i) -> Vector2i:
	for radius in range(1, 4):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var c := cell + Vector2i(dx, dz)
				var region := pathfinder.region
				if c.x >= region.position.x and c.x < region.position.x + region.size.x and c.y >= region.position.y and c.y < region.position.y + region.size.y:
					if not pathfinder.is_point_solid(c):
						return c
	return cell


func _play_anim(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		if animation_player.current_animation != anim_name:
			animation_player.play(anim_name)
