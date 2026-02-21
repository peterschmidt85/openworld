extends CharacterBody3D

## Player controller: WASD movement (camera-relative) + click-to-move.
## Uses the Kenney Mini Character GLB model with walk animation.

@export var walk_speed := 3.0
@export var run_speed := 6.0
@export var acceleration := 10.0
@export var rotation_speed := 10.0

var move_target: Vector3 = Vector3.ZERO
var has_move_target := false
var nav_agent: NavigationAgent3D = null
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

	nav_agent = get_node_or_null("NavAgent")


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

	var raw_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    raw_input.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  raw_input.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  raw_input.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): raw_input.x += 1

	if raw_input.length() > 0:
		raw_input = raw_input.normalized()
		has_move_target = false

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

	elif has_move_target:
		var to_target := move_target - global_position
		to_target.y = 0
		if to_target.length() < 0.5:
			has_move_target = false
		else:
			input_dir = to_target.normalized()

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

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_click_to_move(event.position)
		else:
			_click_to_move(event.position)

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_click_to_move(event.position)


func _click_to_move(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)

	var plane := Plane(Vector3.UP, 0)
	var hit: Variant = plane.intersects_ray(from, dir)
	if hit != null:
		move_target = hit as Vector3
		has_move_target = true
		if nav_agent:
			nav_agent.target_position = move_target
