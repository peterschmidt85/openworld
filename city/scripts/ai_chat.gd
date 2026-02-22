extends Control

## Ask AI: Tab+A opens a chat panel that sends game context to OpenAI.

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

var conversation: Array = []
var waiting := false

const DISTRICT_NAMES := {
	0: "Water", 1: "Downtown", 2: "Commercial", 3: "Residential",
	4: "Industrial", 5: "Park", 6: "Plaza", 7: "Waterfront"
}


func setup(camera: Camera3D, p_plan: Dictionary, p_district_map: Dictionary, p_grid_size: int, p_cell_enum, p_district_enum) -> void:
	city_plan = p_plan
	district_map = p_district_map
	grid_size = p_grid_size
	cell_enum = p_cell_enum
	district_enum = p_district_enum

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

	# Title bar
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

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	# Error banner (hidden by default)
	error_banner = Label.new()
	error_banner.add_theme_font_size_override("font_size", 13)
	error_banner.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	error_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_banner.visible = false
	vbox.add_child(error_banner)

	# Chat log
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

	# Thinking indicator
	thinking_label = Label.new()
	thinking_label.text = "Thinking..."
	thinking_label.add_theme_font_size_override("font_size", 13)
	thinking_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	thinking_label.visible = false
	vbox.add_child(thinking_label)

	# Input field
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


func _input(event: InputEvent) -> void:
	# Tab+A toggles the panel
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A and Input.is_key_pressed(KEY_TAB):
			_toggle_panel()
			get_viewport().set_input_as_handled()
			return

	if not panel.visible:
		return

	# Escape closes the panel
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


func _on_text_submitted(text: String) -> void:
	var question := text.strip_edges()
	if question == "" or waiting:
		return

	if api_key.strip_edges() == "":
		_append_error("Cannot send: OPENAI_API_KEY is not set.")
		return

	input_field.text = ""
	_append_user_message(question)
	_send_request(question)


func _send_request(question: String) -> void:
	waiting = true
	thinking_label.visible = true

	var system_prompt := _build_system_prompt()

	conversation.append({"role": "user", "content": question})

	var messages: Array = [{"role": "system", "content": system_prompt}]
	messages.append_array(conversation)

	var body := JSON.stringify({
		"model": "gpt-4o-mini",
		"messages": messages,
		"max_tokens": 300,
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
		conversation.pop_back()


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
		if conversation.size() > 0 and conversation[-1]["role"] == "user":
			conversation.pop_back()
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
		if conversation.size() > 0 and conversation[-1]["role"] == "user":
			conversation.pop_back()
		return

	var json: Variant = JSON.parse_string(text)
	if json == null or not json is Dictionary:
		_append_error("Failed to parse API response.")
		if conversation.size() > 0 and conversation[-1]["role"] == "user":
			conversation.pop_back()
		return

	var choices: Variant = json.get("choices", [])
	if choices is Array and choices.size() > 0:
		var message: Variant = choices[0].get("message", {})
		if message is Dictionary:
			var reply: String = message.get("content", "")
			reply = reply.strip_edges()
			if reply != "":
				conversation.append({"role": "assistant", "content": reply})
				_append_ai_message(reply)
				return

	_append_error("No response content from API.")
	if conversation.size() > 0 and conversation[-1]["role"] == "user":
		conversation.pop_back()


func _build_system_prompt() -> String:
	var lines: PackedStringArray = []
	lines.append("You are an AI assistant embedded in \"Open World City\", a procedural 3D city simulation built in Godot.")
	lines.append("Current game state:")

	# Player position and district
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p: Node3D = players[0]
		var px := int(floor(p.global_position.x))
		var pz := int(floor(p.global_position.z))
		var district_id: int = district_map.get(Vector2i(px, pz), 3)
		var district_name: String = DISTRICT_NAMES.get(district_id, "Unknown")
		lines.append("- Player at grid (%d, %d) in the %s district" % [px, pz, district_name])

	# Atmosphere (sibling node "Atmosphere" set up by builder)
	var time_str := "day"
	var fog_str := "clear"
	var atmo := get_parent().get_node_or_null("Atmosphere")
	if atmo:
		if "is_night" in atmo:
			time_str = "night" if atmo.is_night else "day"
		if "fog_on" in atmo:
			fog_str = "foggy" if atmo.fog_on else "clear"
	lines.append("- Time: %s, Weather: %s" % [time_str, fog_str])

	# City info
	lines.append("- City: %dx%d grid with districts: Downtown, Commercial, Residential, Industrial, Park, Plaza, Waterfront" % [grid_size, grid_size])

	# NPCs
	var npcs := get_tree().get_nodes_in_group("npc")
	var wander_count := 0
	var stationary_count := 0
	var nearby_positions: PackedStringArray = []
	var player_pos := Vector2.ZERO
	if players.size() > 0:
		player_pos = Vector2(players[0].global_position.x, players[0].global_position.z)

	for npc in npcs:
		if "mode" in npc:
			if npc.mode == "wander":
				wander_count += 1
			else:
				stationary_count += 1
		var npc_pos := Vector2(npc.global_position.x, npc.global_position.z)
		if player_pos.distance_to(npc_pos) < 10.0:
			nearby_positions.append("(%d,%d)" % [int(npc_pos.x), int(npc_pos.y)])

	lines.append("- NPCs: %d wandering, %d stationary total. %d nearby (within 10 tiles): %s" % [
		wander_count, stationary_count, nearby_positions.size(),
		", ".join(nearby_positions) if nearby_positions.size() > 0 else "none"
	])

	lines.append("")
	lines.append("Answer the player's questions about the city. You can describe surroundings, give directions, explain what you see, or just chat.")
	lines.append("Be concise (2-4 sentences) unless asked for detail.")

	return "\n".join(lines)


func _append_user_message(text: String) -> void:
	chat_log.append_text("[color=#7cacf0]You:[/color] %s\n\n" % _escape_bbcode(text))
	_scroll_to_bottom()


func _append_ai_message(text: String) -> void:
	chat_log.append_text("[color=#a0d995]AI:[/color] %s\n\n" % _escape_bbcode(text))
	_scroll_to_bottom()


func _append_error(text: String) -> void:
	chat_log.append_text("[color=#f07070]Error:[/color] %s\n\n" % _escape_bbcode(text))
	_scroll_to_bottom()


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
