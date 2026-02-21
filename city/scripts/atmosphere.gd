extends Node

## Day/night toggle (N) and fog toggle (F).
## Spawns streetlights at lamp post tiles during night.

const ROAD_LIGHTS_ID := 1
const LIGHT_HEIGHT := 1.2

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var gridmap: GridMap

var is_night := false
var fog_on := false
var streetlights: Array[OmniLight3D] = []
var light_positions: Array[Vector3] = []

var day_sun_transform: Transform3D
var day_sun_energy: float
var day_sun_color: Color
var day_bg_color: Color
var day_ambient_color: Color
var day_ambient_energy: float
var day_sky_top: Color
var day_sky_horizon: Color
var day_ground_bottom: Color


func setup(p_sun: DirectionalLight3D, camera: Camera3D, p_gridmap: GridMap) -> void:
	sun = p_sun
	env = camera.environment
	sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	gridmap = p_gridmap

	day_sun_transform = sun.transform
	day_sun_energy = sun.light_energy
	day_sun_color = sun.light_color
	day_bg_color = env.background_color
	day_ambient_color = env.ambient_light_color
	day_ambient_energy = env.ambient_light_energy
	day_sky_top = sky_mat.sky_top_color
	day_sky_horizon = sky_mat.sky_horizon_color
	day_ground_bottom = sky_mat.ground_bottom_color

	_cache_light_positions()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			_toggle_day_night()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F:
			_toggle_fog()
			get_viewport().set_input_as_handled()


func _toggle_day_night() -> void:
	is_night = not is_night

	if is_night:
		sun.light_energy = 0.25
		sun.light_color = Color(0.5, 0.55, 0.7)
		sun.rotation_degrees.x = day_sun_transform.basis.get_euler().x * (180.0 / PI) + 160

		sky_mat.sky_top_color = Color(0.02, 0.02, 0.06)
		sky_mat.sky_horizon_color = Color(0.06, 0.04, 0.12)
		sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.03)

		env.background_color = Color(0.03, 0.03, 0.08)
		env.ambient_light_color = Color(0.15, 0.15, 0.22)
		env.ambient_light_energy = 0.3

		_spawn_streetlights()

		if fog_on:
			env.fog_light_color = Color(0.05, 0.05, 0.1)
	else:
		sun.transform = day_sun_transform
		sun.light_energy = day_sun_energy
		sun.light_color = day_sun_color

		sky_mat.sky_top_color = day_sky_top
		sky_mat.sky_horizon_color = day_sky_horizon
		sky_mat.ground_bottom_color = day_ground_bottom

		env.background_color = day_bg_color
		env.ambient_light_color = day_ambient_color
		env.ambient_light_energy = day_ambient_energy

		_remove_streetlights()

		if fog_on:
			env.fog_light_color = Color(0.7, 0.72, 0.78)

	print("Atmosphere: %s (%d streetlights)" % ["night" if is_night else "day", streetlights.size()])


func _toggle_fog() -> void:
	fog_on = not fog_on
	env.fog_enabled = fog_on

	if fog_on:
		env.fog_density = 0.02
		env.fog_sky_affect = 0.5
		env.fog_light_color = Color(0.05, 0.05, 0.1) if is_night else Color(0.7, 0.72, 0.78)

	print("Fog: %s" % ("on" if fog_on else "off"))


func _cache_light_positions() -> void:
	light_positions.clear()
	for cell in gridmap.get_used_cells():
		if gridmap.get_cell_item(cell) == ROAD_LIGHTS_ID:
			light_positions.append(Vector3(cell.x + 0.5, LIGHT_HEIGHT, cell.z + 0.5))
	print("Streetlight positions cached: %d" % light_positions.size())


func _spawn_streetlights() -> void:
	if streetlights.size() > 0:
		return
	for pos in light_positions:
		var light := OmniLight3D.new()
		light.light_color = Color(0.95, 0.92, 0.82)
		light.light_energy = 2.0
		light.omni_range = 2.5
		light.omni_attenuation = 2.5
		light.shadow_enabled = false
		light.position = pos
		get_parent().add_child(light)
		streetlights.append(light)


func _remove_streetlights() -> void:
	for light in streetlights:
		light.queue_free()
	streetlights.clear()
