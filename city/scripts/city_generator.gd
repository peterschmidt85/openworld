extends Node

## Auto-generates a city on the GridMap.
## Structure indices (from builder structures array):
##  0: road-straight          5: pavement              10: building-small-d
##  1: road-straight-lights   6: pavement-fountain     11: building-garage
##  2: road-corner            7: building-small-a      12: grass
##  3: road-split             8: building-small-b      13: grass-trees
##  4: road-intersection      9: building-small-c      14: grass-trees-tall

const ROAD_STRAIGHT := 0
const ROAD_LIGHTS := 1
const ROAD_CORNER := 2
const ROAD_SPLIT := 3
const ROAD_INTERSECTION := 4
const PAVEMENT := 5
const FOUNTAIN := 6
const BLDG_A := 7
const BLDG_B := 8
const BLDG_C := 9
const BLDG_D := 10
const GARAGE := 11
const GRASS := 12
const TREES := 13
const TREES_TALL := 14

const BUILDINGS := [BLDG_A, BLDG_B, BLDG_C, BLDG_D, GARAGE]
const GREENERY := [GRASS, TREES, TREES_TALL]

@export var grid_size := 24
@export var road_spacing := 4


func generate(gridmap: GridMap) -> void:
	gridmap.clear()
	seed(42)

	for x in range(grid_size):
		for z in range(grid_size):
			var is_road_x := (x % road_spacing == 0)
			var is_road_z := (z % road_spacing == 0)

			if is_road_x and is_road_z:
				gridmap.set_cell_item(Vector3i(x, 0, z), ROAD_INTERSECTION)
			elif is_road_x:
				_place_road_ns(gridmap, x, z)
			elif is_road_z:
				_place_road_ew(gridmap, x, z)
			else:
				_place_block(gridmap, x, z)

	print("City generated: %dx%d grid, road spacing %d" % [grid_size, grid_size, road_spacing])


func _place_road_ns(gridmap: GridMap, x: int, z: int) -> void:
	var item := ROAD_STRAIGHT if randi() % 3 != 0 else ROAD_LIGHTS
	gridmap.set_cell_item(Vector3i(x, 0, z), item)


func _place_road_ew(gridmap: GridMap, x: int, z: int) -> void:
	var item := ROAD_STRAIGHT if randi() % 3 != 0 else ROAD_LIGHTS
	var basis := Basis(Vector3.UP, deg_to_rad(90))
	gridmap.set_cell_item(Vector3i(x, 0, z), item, gridmap.get_orthogonal_index_from_basis(basis))


func _place_block(gridmap: GridMap, x: int, z: int) -> void:
	var roll := randf()

	if roll < 0.06:
		gridmap.set_cell_item(Vector3i(x, 0, z), GREENERY[randi() % GREENERY.size()])
	elif roll < 0.10:
		gridmap.set_cell_item(Vector3i(x, 0, z), FOUNTAIN)
	elif roll < 0.14:
		gridmap.set_cell_item(Vector3i(x, 0, z), PAVEMENT)
	else:
		var bldg: int = BUILDINGS[randi() % BUILDINGS.size()]
		var rot_steps := randi() % 4
		var basis := Basis(Vector3.UP, deg_to_rad(90.0 * rot_steps))
		gridmap.set_cell_item(Vector3i(x, 0, z), bldg, gridmap.get_orthogonal_index_from_basis(basis))
