extends Node3D

## Camera that follows the player. Middle-mouse to rotate, scroll to zoom.

var camera_rotation: Vector3
var zoom: float = 20.0

@onready var camera = $Camera


func _ready():
	camera_rotation = rotation_degrees


func _process(delta):
	# Follow player
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var target_pos: Vector3 = players[0].global_position
		position = position.lerp(target_pos, delta * 8)

	# Smooth rotation
	rotation_degrees = rotation_degrees.lerp(camera_rotation, delta * 6)

	# Smooth zoom
	camera.position = camera.position.lerp(Vector3(0, 0, zoom), delta * 8)


func _input(event):
	# Middle-mouse drag to rotate camera
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("camera_rotate"):
			camera_rotation += Vector3(0, -event.relative.x / 10, 0)

	# Scroll zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = max(8, zoom - 3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = min(60, zoom + 3)
