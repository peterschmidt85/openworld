extends Node
class_name NpcSpawner

## Factory for spawning NPC CharacterBody3D instances.

const NPC_SCRIPT := preload("res://scripts/npc.gd")

const CHARACTER_MODELS := [
	"res://models/characters/character-male-a.glb",
	"res://models/characters/character-male-b.glb",
	"res://models/characters/character-male-c.glb",
	"res://models/characters/character-male-d.glb",
	"res://models/characters/character-male-e.glb",
	"res://models/characters/character-male-f.glb",
	"res://models/characters/character-female-a.glb",
	"res://models/characters/character-female-b.glb",
	"res://models/characters/character-female-c.glb",
	"res://models/characters/character-female-d.glb",
	"res://models/characters/character-female-e.glb",
	"res://models/characters/character-female-f.glb",
]


static func spawn_wanderer(parent: Node3D, pos: Vector3, sidewalk_cells: Array[Vector2i], pf: AStarGrid2D) -> CharacterBody3D:
	var npc := _create_base(pos)
	npc.set("mode", "wander")
	npc.set("sidewalk_cells", sidewalk_cells)
	npc.set("pathfinder", pf)
	parent.add_child.call_deferred(npc)
	return npc


static func spawn_stationary(parent: Node3D, pos: Vector3, facing_angle: float) -> CharacterBody3D:
	var npc := _create_base(pos)
	npc.set("mode", "stationary")
	parent.add_child.call_deferred(npc)
	# Set facing after model is ready
	var model_node: Node3D = npc.get_node_or_null("Model")
	if model_node:
		model_node.rotation.y = facing_angle
	return npc


static func _create_base(pos: Vector3) -> CharacterBody3D:
	var npc := CharacterBody3D.new()
	npc.name = "NPC"
	npc.script = NPC_SCRIPT
	npc.position = pos
	npc.add_to_group("npc")
	npc.collision_layer = 2
	npc.collision_mask = 1

	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.2
	capsule.height = 0.8
	col_shape.shape = capsule
	col_shape.position = Vector3(0, 0.4, 0)
	npc.add_child(col_shape)

	var model_path: String = CHARACTER_MODELS[randi() % CHARACTER_MODELS.size()]
	var model_scene: PackedScene = load(model_path)
	if model_scene:
		var model: Node3D = model_scene.instantiate()
		model.name = "Model"
		model.scale = Vector3(0.5, 0.5, 0.5)
		npc.add_child(model)
		_fix_skeleton_paths(model)

	return npc


static func _fix_skeleton_paths(node: Node) -> void:
	if node is Skeleton3D:
		for child in node.get_children():
			if child is MeshInstance3D:
				var mi: MeshInstance3D = child as MeshInstance3D
				if mi.skeleton == NodePath("") and mi.skin != null:
					mi.skeleton = NodePath("..")
	for child in node.get_children():
		_fix_skeleton_paths(child)
