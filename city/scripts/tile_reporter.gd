extends Node3D

## Feedback journal: Tab+Click a tile, type what's wrong, saved to a per-session file.
## Each session gets its own file under reports/sessions/ with map dump + feedback.

var gridmap: GridMap
var camera: Camera3D
var info_label: Label
var hover_overlay: MeshInstance3D = null
var text_input: LineEdit = null
var pending_cell := Vector3i(-999, -999, -999)

var selected_cells: Array[Vector3i] = []
var selection_overlays: Array[MeshInstance3D] = []
var selection_mat: StandardMaterial3D = null

var help_panel: PanelContainer = null
var help_hint: Label = null

var session_id: int = 0
var session_path: String = ""
var sessions_dir: String = ""
var meta_path: String = ""
var has_feedback := false

const ORIENT_TO_DEG := { 0: 0, 16: 90, 10: 180, 22: 270 }
const NAMES := {
	0: "straight", 1: "lights", 2: "corner",
	3: "split", 4: "intersection", 5: "pavement",
	6: "fountain", 12: "grass", 13: "trees", 14: "trees-tall"
}


func setup(gm: GridMap, cam: Camera3D) -> void:
	gridmap = gm
	camera = cam

	sessions_dir = ProjectSettings.globalize_path("res://reports/sessions")
	DirAccess.make_dir_recursive_absolute(sessions_dir)
	meta_path = sessions_dir.path_join("meta.json")
	session_id = _next_session_id()
	session_path = sessions_dir.path_join("session_%03d.log" % session_id)

	# Hover overlay
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	hover_overlay = MeshInstance3D.new()
	hover_overlay.visible = false
	hover_overlay.material_override = mat
	add_child(hover_overlay)

	selection_mat = StandardMaterial3D.new()
	selection_mat.albedo_color = Color(0.3, 1, 0.5, 0.4)
	selection_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	selection_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	selection_mat.no_depth_test = true

	# HUD
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color(1, 1, 0.7))
	info_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	info_label.add_theme_constant_override("shadow_offset_x", 1)
	info_label.add_theme_constant_override("shadow_offset_y", 1)
	info_label.visible = false
	canvas.add_child(info_label)

	# Text input (hidden until needed)
	text_input = LineEdit.new()
	text_input.placeholder_text = "What's wrong? (Enter to submit, Esc to cancel)"
	text_input.visible = false
	text_input.custom_minimum_size = Vector2(500, 30)
	text_input.add_theme_font_size_override("font_size", 14)
	text_input.anchor_left = 0.5
	text_input.anchor_right = 0.5
	text_input.anchor_top = 1.0
	text_input.anchor_bottom = 1.0
	text_input.offset_left = -250
	text_input.offset_right = 250
	text_input.offset_top = -50
	text_input.offset_bottom = -20
	text_input.text_submitted.connect(_on_text_submitted)
	canvas.add_child(text_input)

	_create_help_panel(canvas)

	process_priority = -10
	set_process_input(true)
	print("Feedback journal: session %d (created on first feedback)" % session_id)


# =========================================================
# Hover
# =========================================================

func _process(_delta: float) -> void:
	if camera == null or gridmap == null:
		return

	# If text input is active, don't process hover
	if text_input.visible:
		return

	if not Input.is_key_pressed(KEY_TAB):
		info_label.visible = false
		hover_overlay.visible = false
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	if absf(dir.y) < 0.001:
		info_label.visible = false
		return
	var t := -from.y / dir.y
	if t < 0:
		info_label.visible = false
		return

	var world_pos: Vector3 = from + dir * t
	var cell := Vector3i(int(floor(world_pos.x)), 0, int(floor(world_pos.z)))
	var tid: int = gridmap.get_cell_item(cell)

	var cell_info := ""
	if tid == -1:
		cell_info = "(%d,%d) empty" % [cell.x, cell.z]
	else:
		var deg: int = ORIENT_TO_DEG.get(gridmap.get_cell_item_orientation(cell), -1)
		var tname: String = NAMES.get(tid, "m%d" % tid)
		cell_info = "(%d,%d) %s rot=%d°" % [cell.x, cell.z, tname, deg]

	if selected_cells.size() > 0:
		info_label.text = "%s — click to add/remove | %d selected, Enter to comment" % [cell_info, selected_cells.size()]
	else:
		info_label.text = "%s — click to select" % cell_info

	info_label.visible = true
	info_label.position = mouse_pos + Vector2(15, -10)
	pending_cell = cell

	# Hover overlay
	if tid >= 0:
		var mesh: Mesh = gridmap.mesh_library.get_item_mesh(tid)
		if mesh:
			hover_overlay.mesh = mesh
			var orient: int = gridmap.get_cell_item_orientation(cell)
			hover_overlay.transform = Transform3D(gridmap.get_basis_with_orthogonal_index(orient), Vector3(cell.x, 0, cell.z))
			hover_overlay.visible = true
	else:
		hover_overlay.visible = false


func _input(event: InputEvent) -> void:
	# H → toggle help
	if event is InputEventKey and event.pressed and event.keycode == KEY_H and not text_input.visible:
		help_panel.visible = not help_panel.visible
		help_hint.visible = not help_panel.visible
		get_viewport().set_input_as_handled()
		return

	if text_input.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			text_input.visible = false
			text_input.text = ""
			get_viewport().set_input_as_handled()
		return

	if not Input.is_key_pressed(KEY_TAB):
		return

	# Tab+Click → toggle tile in selection
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if pending_cell != Vector3i(-999, -999, -999):
			_toggle_selection(pending_cell)
			get_viewport().set_input_as_handled()

	# Tab+Enter → open text input for selected tiles
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		if selected_cells.size() > 0:
			text_input.visible = true
			text_input.text = ""
			text_input.grab_focus()
			info_label.visible = false
			get_viewport().set_input_as_handled()

	# Tab+Esc → clear selection
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_clear_selection()
		get_viewport().set_input_as_handled()


func _toggle_selection(cell: Vector3i) -> void:
	var idx := selected_cells.find(cell)
	if idx >= 0:
		selected_cells.remove_at(idx)
		selection_overlays[idx].queue_free()
		selection_overlays.remove_at(idx)
	else:
		selected_cells.append(cell)
		var overlay := MeshInstance3D.new()
		overlay.material_override = selection_mat
		var tid: int = gridmap.get_cell_item(cell)
		if tid >= 0:
			var mesh: Mesh = gridmap.mesh_library.get_item_mesh(tid)
			if mesh:
				overlay.mesh = mesh
			var orient: int = gridmap.get_cell_item_orientation(cell)
			overlay.transform = Transform3D(gridmap.get_basis_with_orthogonal_index(orient), Vector3(cell.x, 0, cell.z))
		else:
			var box := BoxMesh.new()
			box.size = Vector3(1, 0.1, 1)
			overlay.mesh = box
			overlay.position = Vector3(cell.x + 0.5, 0.05, cell.z + 0.5)
		overlay.visible = true
		add_child(overlay)
		selection_overlays.append(overlay)


func _clear_selection() -> void:
	for overlay in selection_overlays:
		overlay.queue_free()
	selection_overlays.clear()
	selected_cells.clear()


func _on_text_submitted(text: String) -> void:
	if text.strip_edges().length() > 0:
		_write_feedback_multi(selected_cells.duplicate(), text.strip_edges())
		info_label.add_theme_color_override("font_color", Color(0.3, 1, 0.5))
		info_label.text = "Feedback saved for %d tile(s)!" % selected_cells.size()
		info_label.visible = true
		info_label.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 80, get_viewport().get_visible_rect().size.y - 80)
		get_tree().create_timer(1.5).timeout.connect(func():
			info_label.visible = false
			info_label.add_theme_color_override("font_color", Color(1, 1, 0.7)))
	_clear_selection()
	text_input.visible = false
	text_input.text = ""


# =========================================================
# Help panel
# =========================================================

func _create_help_panel(canvas: CanvasLayer) -> void:
	help_panel = PanelContainer.new()
	help_panel.anchor_left = 0.0
	help_panel.anchor_top = 0.0
	help_panel.offset_left = 12
	help_panel.offset_top = 12

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	help_panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.88))
	label.text = (
		"CONTROLS\n"
		+ "\n"
		+ "  WASD / Arrows    Move\n"
		+ "  Shift            Run\n"
		+ "  Mouse drag       Camera\n"
		+ "  Click            Walk to\n"
		+ "\n"
		+ "FEEDBACK REPORTER\n"
		+ "\n"
		+ "  Tab + Hover      Inspect tile\n"
		+ "  Tab + Click      Select / deselect tile\n"
		+ "  Tab + Enter      Comment on selected tiles\n"
		+ "  Tab + Esc        Clear selection\n"
		+ "  Esc              Cancel typing\n"
		+ "\n"
		+ "ATMOSPHERE\n"
		+ "\n"
		+ "  N                Toggle day / night\n"
		+ "  F                Toggle fog\n"
		+ "  M                Toggle minimap\n"
		+ "\n"
		+ "  H                Toggle this help"
	)
	help_panel.add_child(label)
	help_panel.visible = false
	canvas.add_child(help_panel)

	help_hint = Label.new()
	help_hint.add_theme_font_size_override("font_size", 12)
	help_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65, 0.6))
	help_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	help_hint.add_theme_constant_override("shadow_offset_x", 1)
	help_hint.add_theme_constant_override("shadow_offset_y", 1)
	help_hint.text = "H — help"
	help_hint.position = Vector2(14, 14)
	canvas.add_child(help_hint)


# =========================================================
# Write feedback entry
# =========================================================

func _write_feedback_multi(cells: Array[Vector3i], user_text: String) -> void:
	if not has_feedback:
		has_feedback = true
		_write_session_header()
		_save_meta()
	var entry := ""
	for cell in cells:
		entry += _cell_info_string(cell) + "\n"
	entry += "> \"%s\"\n\n" % user_text
	_append_to_session(entry)
	var coords := ", ".join(cells.map(func(c: Vector3i) -> String: return "(%d,%d)" % [c.x, c.z]))
	print("[FEEDBACK] %s: %s" % [coords, user_text])


func _cell_info_string(cell: Vector3i) -> String:
	var tid: int = gridmap.get_cell_item(cell)
	var tname: String = NAMES.get(tid, "m%d" % tid) if tid >= 0 else "empty"
	var deg: int = ORIENT_TO_DEG.get(gridmap.get_cell_item_orientation(cell), -1) if tid >= 0 else -1

	var neighbors := ""
	for d in ["N", "S", "W", "E"]:
		var off: Vector3i
		match d:
			"N": off = Vector3i(0, 0, -1)
			"S": off = Vector3i(0, 0, 1)
			"W": off = Vector3i(-1, 0, 0)
			"E": off = Vector3i(1, 0, 0)
		var ncell: Vector3i = cell + off
		var nid: int = gridmap.get_cell_item(ncell)
		if nid == -1:
			neighbors += "%s:empty " % d
		else:
			var no: int = gridmap.get_cell_item_orientation(ncell)
			var nd: int = ORIENT_TO_DEG.get(no, -1)
			var nn: String = NAMES.get(nid, "m%d" % nid)
			neighbors += "%s:%s@%d " % [d, nn, nd]

	return "[%d,%d] %s@%d | %s" % [cell.x, cell.z, tname, deg, neighbors.strip_edges()]


func _append_to_session(text: String) -> void:
	var file := FileAccess.open(session_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
	else:
		file = FileAccess.open(session_path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()


# =========================================================
# Session file with map dump
# =========================================================

func _write_session_header() -> void:
	var file := FileAccess.open(session_path, FileAccess.WRITE)
	if file == null:
		return

	var timestamp: String = Time.get_datetime_string_from_system()
	file.store_string("Session %d | %s | seed:42\n" % [session_id, timestamp])
	file.store_string("STATUS: open\n")
	file.store_string("=" .repeat(70) + "\n\n")

	file.store_string("MAP DUMP (tile_id.orient per cell, . = empty):\n")
	file.store_string("     ")
	for x in range(60):
		file.store_string("%3d " % x)
	file.store_string("\n")

	for z in range(60):
		file.store_string("z%2d: " % z)
		for x in range(60):
			var cell := Vector3i(x, 0, z)
			var tid: int = gridmap.get_cell_item(cell)
			if tid == -1:
				file.store_string("  . ")
			else:
				var o: int = gridmap.get_cell_item_orientation(cell)
				file.store_string("%2d.%d" % [tid, ORIENT_TO_DEG.get(o, 0) / 90])
			if x < 59:
				file.store_string(" ")
		file.store_string("\n")

	file.store_string("\nFEEDBACK:\n\n")
	file.close()


# =========================================================
# Meta: session counter + status index
# =========================================================

func _load_meta() -> Dictionary:
	if FileAccess.file_exists(meta_path):
		var file := FileAccess.open(meta_path, FileAccess.READ)
		if file:
			var data: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if data is Dictionary:
				return data
	return {}


func _save_meta() -> void:
	var meta := _load_meta()
	meta["next_session"] = session_id + 1
	if not meta.has("sessions"):
		meta["sessions"] = {}
	meta["sessions"][str(session_id)] = "open"
	var file := FileAccess.open(meta_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(meta, "  "))
		file.close()


func _next_session_id() -> int:
	var meta := _load_meta()
	if meta.has("next_session"):
		return int(meta["next_session"])
	return 1
