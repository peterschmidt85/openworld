extends Control

## Ask AI: Tab+A opens a chat panel with OpenAI tool-calling agent.
## The model reasons with low-level query tools and issues move_to(x,z) actions.

var canvas: CanvasLayer
var panel: PanelContainer
var chat_log: RichTextLabel
var scroll: ScrollContainer
var input_field: LineEdit
var thinking_label: Label
var error_banner: Label

var http_request: HTTPRequest
var api_key: String = ""

var city_plan: Dictionary = {}
var district_map: Dictionary = {}
var grid_size: int = 60
var cell_enum = null
var district_enum = null
var pathfinder: AStarGrid2D = null

var conversation: Array = []
var waiting := false
var agent_iterations: int = 0
const MAX_AGENT_ITERATIONS := 5

const DISTRICT_NAMES := {
	0: "Water", 1: "Downtown", 2: "Commercial", 3: "Residential",
	4: "Industrial", 5: "Park", 6: "Plaza", 7: "Waterfront"
}

const CELL_NAMES := {
	0: "empty", 1: "road", 2: "building", 3: "sidewalk",
	4: "park", 5: "plaza", 6: "water", 7: "grass"
}


func setup(camera: Camera3D, p_plan: Dictionary, p_district_map: Dictionary, p_grid_size: int, p_cell_enum, p_district_enum, p_pathfinder: AStarGrid2D) -> void:
	city_plan = p_plan
	district_map = p_district_map
	grid_size = p_grid_size
	cell_enum = p_cell_enum
	district_enum = p_district_enum
	pathfinder = p_pathfinder

	api_key = OS.get_environment("OPENAI_API_KEY")
	if api_key.strip_edges() == "":
		api_key = _read_key_from_envrc()

	http_request = HTTPRequest.new()
	http_request.timeout = 30.0
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

	_build_ui()

	if api_key.strip_edges() == "":
		error_banner.text = "OPENAI_API_KEY not set. Export it as an environment variable and restart."
		error_banner.visible = true

	set_process_input(true)
	print("AI Chat ready (API key %s)" % ("set" if api_key.strip_edges() != "" else "MISSING"))


# =========================================================
# UI
# =========================================================

func _build_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 101
	add_child(canvas)

	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -250
	panel.offset_bottom = 250
	panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.92)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.3, 0.35, 0.5, 0.6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title_bar := HBoxContainer.new()
	vbox.add_child(title_bar)

	var title := Label.new()
	title.text = "Ask AI"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.88, 1.0))
	title_bar.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(spacer)

	var hint := Label.new()
	hint.text = "Esc to close"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58))
	title_bar.add_child(hint)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	error_banner = Label.new()
	error_banner.add_theme_font_size_override("font_size", 13)
	error_banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	error_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_banner.visible = false
	vbox.add_child(error_banner)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.fit_content = true
	chat_log.scroll_active = false
	chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.add_theme_font_size_override("normal_font_size", 14)
	chat_log.add_theme_color_override("default_color", Color(0.82, 0.84, 0.9))
	scroll.add_child(chat_log)

	thinking_label = Label.new()
	thinking_label.text = "Thinking..."
	thinking_label.add_theme_font_size_override("font_size", 13)
	thinking_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	thinking_label.visible = false
	vbox.add_child(thinking_label)

	input_field = LineEdit.new()
	input_field.placeholder_text = "Ask something about the city..."
	input_field.add_theme_font_size_override("font_size", 14)
	input_field.custom_minimum_size = Vector2(0, 34)
	input_field.text_submitted.connect(_on_text_submitted)

	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	input_style.corner_radius_top_left = 4
	input_style.corner_radius_top_right = 4
	input_style.corner_radius_bottom_left = 4
	input_style.corner_radius_bottom_right = 4
	input_style.border_width_top = 1
	input_style.border_width_bottom = 1
	input_style.border_width_left = 1
	input_style.border_width_right = 1
	input_style.border_color = Color(0.25, 0.28, 0.4, 0.5)
	input_style.content_margin_left = 8
	input_style.content_margin_right = 8
	input_style.content_margin_top = 4
	input_style.content_margin_bottom = 4
	input_field.add_theme_stylebox_override("normal", input_style)
	vbox.add_child(input_field)


# =========================================================
# Input
# =========================================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A and Input.is_key_pressed(KEY_TAB):
			_toggle_panel()
			get_viewport().set_input_as_handled()
			return

	if not panel.visible:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_panel()
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if panel.visible and event is InputEventKey:
		get_viewport().set_input_as_handled()


func _toggle_panel() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		input_field.grab_focus.call_deferred()
		_set_game_input(false)
	else:
		input_field.release_focus()
		_set_game_input(true)


func _set_game_input(enabled: bool) -> void:
	for node_name in ["Atmosphere", "TileReporter", "HoverHighlight"]:
		var node := get_parent().get_node_or_null(node_name)
		if node:
			node.set_process_input(enabled)


func _process(_delta: float) -> void:
	if not thinking_label.visible:
		return
	var dots := int(Time.get_ticks_msec() / 400) % 4
	thinking_label.text = "Thinking" + ".".repeat(dots)


# =========================================================
# Chat submission and API requests
# =========================================================

func _on_text_submitted(text: String) -> void:
	var question := text.strip_edges()
	if question == "" or waiting:
		return

	if api_key.strip_edges() == "":
		_append_error("Cannot send: OPENAI_API_KEY is not set.")
		return

	input_field.text = ""
	_append_user_message(question)

	conversation.append({"role": "user", "content": question})
	agent_iterations = 0
	_fire_api_request()


func _fire_api_request() -> void:
	waiting = true
	thinking_label.visible = true

	var system_prompt := _build_system_prompt()
	var messages: Array = [{"role": "system", "content": system_prompt}]
	messages.append_array(conversation)

	var body := JSON.stringify({
		"model": "gpt-4o-mini",
		"messages": messages,
		"max_tokens": 500,
		"tools": _get_tools(),
	})

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
	]

	var err := http_request.request("https://api.openai.com/v1/chat/completions", headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		waiting = false
		thinking_label.visible = false
		_append_error("HTTP request failed to start (error %d)." % err)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	waiting = false
	thinking_label.visible = false

	if result != HTTPRequest.RESULT_SUCCESS:
		var reason := "Connection failed"
		match result:
			HTTPRequest.RESULT_CANT_CONNECT: reason = "Cannot connect to server"
			HTTPRequest.RESULT_CANT_RESOLVE: reason = "Cannot resolve hostname"
			HTTPRequest.RESULT_CONNECTION_ERROR: reason = "Connection error"
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: reason = "TLS handshake failed"
			HTTPRequest.RESULT_NO_RESPONSE: reason = "No response from server"
			HTTPRequest.RESULT_REQUEST_FAILED: reason = "Request failed"
			HTTPRequest.RESULT_TIMEOUT: reason = "Request timed out"
		_append_error("%s (result %d)." % [reason, result])
		return

	var text := body.get_string_from_utf8()

	if response_code != 200:
		var detail := ""
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary and parsed.has("error"):
			var err_obj: Variant = parsed["error"]
			if err_obj is Dictionary and err_obj.has("message"):
				detail = str(err_obj["message"])
		if detail != "":
			_append_error("API error %d: %s" % [response_code, detail])
		else:
			_append_error("API returned status %d." % response_code)
		return

	var json: Variant = JSON.parse_string(text)
	if json == null or not json is Dictionary:
		_append_error("Failed to parse API response.")
		return

	var choices: Variant = json.get("choices", [])
	if not choices is Array or choices.size() == 0:
		_append_error("No choices in API response.")
		return

	var message: Variant = choices[0].get("message", {})
	if not message is Dictionary:
		_append_error("Invalid message in API response.")
		return

	var tool_calls: Variant = message.get("tool_calls", null)

	if tool_calls is Array and tool_calls.size() > 0:
		_handle_tool_calls(message, tool_calls)
		return

	var reply: String = str(message.get("content", "")).strip_edges()
	if reply != "":
		conversation.append({"role": "assistant", "content": reply})
		_append_ai_message(reply)
	else:
		_append_error("Empty response from API.")


func _handle_tool_calls(assistant_message: Dictionary, tool_calls: Array) -> void:
	# Append the assistant message (with tool_calls) to conversation as-is
	var conv_msg: Dictionary = {"role": "assistant"}
	var content: Variant = assistant_message.get("content", null)
	if content != null and str(content).strip_edges() != "":
		conv_msg["content"] = str(content)
	else:
		conv_msg["content"] = null

	var tc_array: Array = []
	for tc in tool_calls:
		tc_array.append({
			"id": str(tc.get("id", "")),
			"type": "function",
			"function": {
				"name": str(tc.get("function", {}).get("name", "")),
				"arguments": str(tc.get("function", {}).get("arguments", "{}")),
			}
		})
	conv_msg["tool_calls"] = tc_array
	conversation.append(conv_msg)

	# Execute each tool and append results
	for tc in tool_calls:
		var func_info: Variant = tc.get("function", {})
		var tool_name: String = str(func_info.get("name", ""))
		var args_str: String = str(func_info.get("arguments", "{}"))
		var tool_id: String = str(tc.get("id", ""))

		var args: Variant = JSON.parse_string(args_str)
		if args == null:
			args = {}

		_append_action("%s(%s)" % [tool_name, args_str])
		print("[AGENT] tool_call: %s(%s)" % [tool_name, args_str])

		var result_str := _execute_tool(tool_name, args)
		print("[AGENT] result: %s" % result_str)

		conversation.append({
			"role": "tool",
			"tool_call_id": tool_id,
			"content": result_str,
		})

	# Continue the agent loop
	agent_iterations += 1
	if agent_iterations >= MAX_AGENT_ITERATIONS:
		_append_error("Agent reached max iterations (%d). Stopping." % MAX_AGENT_ITERATIONS)
		return

	_fire_api_request()


# =========================================================
# Tool definitions (OpenAI format)
# =========================================================

func _get_tools() -> Array:
	return [
		{
			"type": "function",
			"function": {
				"name": "move_to",
				"description": "Walk the player to a grid cell via A* pathfinding. Like clicking on the ground. Returns path length or error if unreachable.",
				"parameters": {
					"type": "object",
					"properties": {
						"x": {"type": "integer", "description": "Grid X coordinate (0 to %d)" % (grid_size - 1)},
						"z": {"type": "integer", "description": "Grid Z coordinate (0 to %d)" % (grid_size - 1)},
					},
					"required": ["x", "z"],
				},
			},
		},
		{
			"type": "function",
			"function": {
				"name": "get_player_info",
				"description": "Get the player's current position, district, time of day, and fog state.",
				"parameters": {"type": "object", "properties": {}},
			},
		},
		{
			"type": "function",
			"function": {
				"name": "list_npcs",
				"description": "List NPCs within a radius of the player. Returns positions, modes (wander/stationary), and distances.",
				"parameters": {
					"type": "object",
					"properties": {
						"radius": {"type": "integer", "description": "Search radius in grid tiles (default 20)"},
					},
				},
			},
		},
		{
			"type": "function",
			"function": {
				"name": "describe_surroundings",
				"description": "Describe what districts and tile types are around the player within a radius. Returns district names with coordinate ranges so you can pick a move_to target.",
				"parameters": {
					"type": "object",
					"properties": {
						"radius": {"type": "integer", "description": "Search radius in grid tiles (default 15)"},
					},
				},
			},
		},
		{
			"type": "function",
			"function": {
				"name": "toggle_time",
				"description": "Toggle between day and night. Returns the new time state.",
				"parameters": {"type": "object", "properties": {}},
			},
		},
		{
			"type": "function",
			"function": {
				"name": "toggle_fog",
				"description": "Toggle fog on/off. Returns the new fog state.",
				"parameters": {"type": "object", "properties": {}},
			},
		},
	]


# =========================================================
# Tool execution
# =========================================================

func _execute_tool(tool_name: String, args: Variant) -> String:
	if not args is Dictionary:
		args = {}
	match tool_name:
		"move_to":
			return _tool_move_to(args)
		"get_player_info":
			return _tool_get_player_info()
		"list_npcs":
			return _tool_list_npcs(args)
		"describe_surroundings":
			return _tool_describe_surroundings(args)
		"toggle_time":
			return _tool_toggle_time()
		"toggle_fog":
			return _tool_toggle_fog()
		_:
			return JSON.stringify({"error": "Unknown tool: %s" % tool_name})


func _tool_move_to(args: Dictionary) -> String:
	var x: int = int(args.get("x", -1))
	var z: int = int(args.get("z", -1))

	if x < 0 or x >= grid_size or z < 0 or z >= grid_size:
		return JSON.stringify({"error": "Coordinates (%d, %d) out of bounds (grid is %dx%d)" % [x, z, grid_size, grid_size]})

	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return JSON.stringify({"error": "No player found"})
	var player: CharacterBody3D = players[0]

	if pathfinder == null:
		return JSON.stringify({"error": "Pathfinder not available"})

	var region := pathfinder.region
	var target := Vector2i(x, z).clamp(region.position, region.position + region.size - Vector2i.ONE)
	var from := Vector2i(int(floor(player.global_position.x)), int(floor(player.global_position.z)))
	from = from.clamp(region.position, region.position + region.size - Vector2i.ONE)

	if pathfinder.is_point_solid(from):
		from = _nearest_walkable(from)
	if pathfinder.is_point_solid(target):
		var original := target
		target = _nearest_walkable(target)
		if pathfinder.is_point_solid(target):
			return JSON.stringify({"error": "Target (%d, %d) is unreachable (solid tile, no nearby walkable)" % [original.x, original.y]})

	if from == target:
		return JSON.stringify({"status": "already_there", "x": from.x, "z": from.y})

	var path := pathfinder.get_point_path(from, target)
	if path.size() == 0:
		return JSON.stringify({"error": "No path from (%d, %d) to (%d, %d)" % [from.x, from.y, target.x, target.y]})

	player.path_points = path
	player.path_index = 0
	player._approach_target = null
	player._approach_building_pos = Vector3.INF

	return JSON.stringify({"status": "walking", "path_length": path.size(), "from": [from.x, from.y], "to": [target.x, target.y]})


func _tool_get_player_info() -> String:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return JSON.stringify({"error": "No player found"})

	var p: Node3D = players[0]
	var px := int(floor(p.global_position.x))
	var pz := int(floor(p.global_position.z))
	var district_id: int = district_map.get(Vector2i(px, pz), 3)
	var district_name: String = DISTRICT_NAMES.get(district_id, "Unknown")

	var time_str := "day"
	var fog_str := "off"
	var atmo := get_parent().get_node_or_null("Atmosphere")
	if atmo:
		if "is_night" in atmo:
			time_str = "night" if atmo.is_night else "day"
		if "fog_on" in atmo:
			fog_str = "on" if atmo.fog_on else "off"

	return JSON.stringify({
		"x": px, "z": pz,
		"district": district_name,
		"time": time_str,
		"fog": fog_str,
	})


func _tool_list_npcs(args: Dictionary) -> String:
	var radius: float = float(args.get("radius", 20))

	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return JSON.stringify({"error": "No player found"})
	var player_pos := Vector2(players[0].global_position.x, players[0].global_position.z)

	var npcs := get_tree().get_nodes_in_group("npc")
	var result: Array = []
	for npc in npcs:
		var npc_pos := Vector2(npc.global_position.x, npc.global_position.z)
		var dist := player_pos.distance_to(npc_pos)
		if dist <= radius:
			var mode_str := "unknown"
			if "mode" in npc:
				mode_str = str(npc.mode)
			result.append({
				"x": int(npc_pos.x),
				"z": int(npc_pos.y),
				"mode": mode_str,
				"distance": snappedf(dist, 0.1),
			})

	result.sort_custom(func(a, b): return a["distance"] < b["distance"])
	return JSON.stringify({"count": result.size(), "npcs": result})


func _tool_describe_surroundings(args: Dictionary) -> String:
	var radius: int = int(args.get("radius", 15))

	var players := get_tree().get_nodes_in_group("player")
	if players.size() == 0:
		return JSON.stringify({"error": "No player found"})
	var px := int(floor(players[0].global_position.x))
	var pz := int(floor(players[0].global_position.z))

	# Gather districts with coordinate ranges
	var district_cells: Dictionary = {}
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			var cx := px + dx
			var cz := pz + dz
			if cx < 0 or cx >= grid_size or cz < 0 or cz >= grid_size:
				continue
			var pos := Vector2i(cx, cz)
			var d_id: int = district_map.get(pos, -1)
			if d_id < 0:
				continue
			var d_name: String = DISTRICT_NAMES.get(d_id, "Unknown")
			if not district_cells.has(d_name):
				district_cells[d_name] = {"min_x": cx, "max_x": cx, "min_z": cz, "max_z": cz, "count": 0, "walkable_example": null}
			var dc: Dictionary = district_cells[d_name]
			dc["count"] = dc["count"] + 1
			if cx < dc["min_x"]: dc["min_x"] = cx
			if cx > dc["max_x"]: dc["max_x"] = cx
			if cz < dc["min_z"]: dc["min_z"] = cz
			if cz > dc["max_z"]: dc["max_z"] = cz

			if dc["walkable_example"] == null:
				var cell_type: int = city_plan.get(pos, 0)
				if cell_type in [1, 3, 4, 5]:
					dc["walkable_example"] = [cx, cz]

	var districts_out: Array = []
	for d_name in district_cells:
		var dc: Dictionary = district_cells[d_name]
		var entry: Dictionary = {
			"district": d_name,
			"cells": dc["count"],
			"x_range": [dc["min_x"], dc["max_x"]],
			"z_range": [dc["min_z"], dc["max_z"]],
		}
		if dc["walkable_example"] != null:
			entry["walkable_example"] = dc["walkable_example"]
		districts_out.append(entry)

	return JSON.stringify({
		"player": [px, pz],
		"radius": radius,
		"districts": districts_out,
	})


func _tool_toggle_time() -> String:
	var atmo := get_parent().get_node_or_null("Atmosphere")
	if atmo == null:
		return JSON.stringify({"error": "Atmosphere node not found"})
	atmo._toggle_day_night()
	var new_state: String = "night" if atmo.is_night else "day"
	return JSON.stringify({"time": new_state})


func _tool_toggle_fog() -> String:
	var atmo := get_parent().get_node_or_null("Atmosphere")
	if atmo == null:
		return JSON.stringify({"error": "Atmosphere node not found"})
	atmo._toggle_fog()
	var new_state: String = "on" if atmo.fog_on else "off"
	return JSON.stringify({"fog": new_state})


func _nearest_walkable(cell: Vector2i) -> Vector2i:
	var region := pathfinder.region
	for radius in range(1, 6):
		for dx in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var c := cell + Vector2i(dx, dz)
				if c.x >= region.position.x and c.x < region.position.x + region.size.x and c.y >= region.position.y and c.y < region.position.y + region.size.y:
					if not pathfinder.is_point_solid(c):
						return c
	return cell


# =========================================================
# System prompt
# =========================================================

func _build_system_prompt() -> String:
	var lines: PackedStringArray = []
	lines.append("You are an AI agent controlling a player in \"Open World City\", a procedural 3D city simulation.")
	lines.append("You have tools to query the game world and move the player. Use query tools first to gather information, then use move_to(x, z) to navigate.")
	lines.append("")
	lines.append("Current game state:")

	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p: Node3D = players[0]
		var px := int(floor(p.global_position.x))
		var pz := int(floor(p.global_position.z))
		var district_id: int = district_map.get(Vector2i(px, pz), 3)
		var district_name: String = DISTRICT_NAMES.get(district_id, "Unknown")
		lines.append("- Player at grid (%d, %d) in the %s district" % [px, pz, district_name])

	var time_str := "day"
	var fog_str := "clear"
	var atmo := get_parent().get_node_or_null("Atmosphere")
	if atmo:
		if "is_night" in atmo:
			time_str = "night" if atmo.is_night else "day"
		if "fog_on" in atmo:
			fog_str = "foggy" if atmo.fog_on else "clear"
	lines.append("- Time: %s, Weather: %s" % [time_str, fog_str])
	lines.append("- City: %dx%d grid. Districts: Downtown, Commercial, Residential, Industrial, Park, Plaza, Waterfront" % [grid_size, grid_size])

	var npcs := get_tree().get_nodes_in_group("npc")
	var wander_count := 0
	var stationary_count := 0
	for npc in npcs:
		if "mode" in npc:
			if npc.mode == "wander":
				wander_count += 1
			else:
				stationary_count += 1
	lines.append("- NPCs: %d wandering, %d stationary" % [wander_count, stationary_count])

	lines.append("")
	lines.append("Guidelines:")
	lines.append("- Use describe_surroundings() or get_player_info() to learn where you are before moving.")
	lines.append("- Use list_npcs() to find NPCs, then move_to their coordinates.")
	lines.append("- move_to(x, z) walks the player there via pathfinding -- pick walkable coordinates (roads, sidewalks, parks, plazas).")
	lines.append("- If you cannot fulfill a request (e.g., spawn objects, modify the city), say so upfront.")
	lines.append("- Be concise in responses (1-3 sentences). Show what you did.")

	return "\n".join(lines)


# =========================================================
# Chat display helpers
# =========================================================

func _append_user_message(text: String) -> void:
	chat_log.append_text("[color=#7cacf0]You:[/color] %s\n\n" % _escape_bbcode(text))
	_scroll_to_bottom()


func _append_ai_message(text: String) -> void:
	chat_log.append_text("[color=#a0d995]AI:[/color] %s\n\n" % _escape_bbcode(text))
	_scroll_to_bottom()


func _append_action(text: String) -> void:
	chat_log.append_text("[color=#c4a6e8]> %s[/color]\n" % _escape_bbcode(text))
	_scroll_to_bottom()


func _append_error(text: String) -> void:
	chat_log.append_text("[color=#f07070]Error:[/color] %s\n\n" % _escape_bbcode(text))
	_scroll_to_bottom()


# =========================================================
# Utilities
# =========================================================

func _read_key_from_envrc() -> String:
	for rel in ["../../.envrc", "../.envrc", ".envrc"]:
		var abs_path := ProjectSettings.globalize_path("res://").path_join(rel)
		if not FileAccess.file_exists(abs_path):
			continue
		var file := FileAccess.open(abs_path, FileAccess.READ)
		if file == null:
			continue
		while not file.eof_reached():
			var line := file.get_line().strip_edges()
			if line.begins_with("export OPENAI_API_KEY="):
				var val := line.substr("export OPENAI_API_KEY=".length())
				if val.begins_with("\"") and val.ends_with("\""):
					val = val.substr(1, val.length() - 2)
				elif val.begins_with("'") and val.ends_with("'"):
					val = val.substr(1, val.length() - 2)
				if val.strip_edges() != "":
					print("AI Chat: loaded API key from %s" % abs_path)
					return val.strip_edges()
		file.close()
	return ""


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
