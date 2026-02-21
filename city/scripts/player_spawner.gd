extends Node
class_name PlayerSpawner

## Spawns a player CharacterBody3D with the Kenney Mini Character model.
## Called from the main scene at startup.

const PLAYER_SCRIPT := preload("res://scripts/player.gd")


static func spawn(parent: Node3D, pos: Vector3) -> CharacterBody3D:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.script = PLAYER_SCRIPT
	player.position = pos
	player.collision_layer = 1
	player.collision_mask = 1

	# Collision shape (capsule)
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 0.9
	col_shape.shape = capsule
	col_shape.position = Vector3(0, 0.45, 0)
	player.add_child(col_shape)

	# Navigation agent for pathfinding
	var nav_agent := NavigationAgent3D.new()
	nav_agent.name = "NavAgent"
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.radius = 0.3
	player.add_child(nav_agent)

	# Load character model
	var model_scene := load("res://models/characters/character-male-a.glb")
	if model_scene:
		var model: Node3D = model_scene.instantiate()
		model.name = "Model"
		model.scale = Vector3(0.5, 0.5, 0.5)  # adjust scale to fit city
		player.add_child(model)

		# Find and expose AnimationPlayer if present
		var anim_player := _find_animation_player(model)
		if anim_player:
			print("Player animations: ", anim_player.get_animation_list())
	else:
		# Fallback: simple box as placeholder
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = "Model"
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.8, 0.3)
		mesh_inst.mesh = box
		mesh_inst.position = Vector3(0, 0.4, 0)
		player.add_child(mesh_inst)
		print("WARNING: Character model not found, using placeholder box")

	parent.add_child.call_deferred(player)
	return player


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null
