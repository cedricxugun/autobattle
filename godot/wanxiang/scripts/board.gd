class_name BattleBoard
extends Control

signal action(command: String, arguments: Dictionary)
signal inspect_unit(unit: Dictionary, screen_position: Vector2)
signal selection_changed(uid: String)

var snapshot: Dictionary = {}
var pieces: Dictionary = {}
var selected_uid := ""
var unit_layer := Node2D.new()
var effects_layer: Node2D
var background: Texture2D
var drag_started := false
var ignore_click_until := 0
var hover_cell := Vector2i(-1, -1)
var font := SystemFont.new()
var pointer_local := Vector2.ZERO
var pointer_known := false
var ambient_time := 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		pointer_local = get_global_transform_with_canvas().affine_inverse() * event.position
		pointer_known = true

func drop_position(fallback: Vector2) -> Vector2:
	return pointer_local if drag_started and pointer_known else fallback

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	font.font_names = ["Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI"]
	background = ArtLibrary.texture_at("res://assets/arena-carnival-v1.png")
	add_child(unit_layer)
	effects_layer = load("res://scripts/effects.gd").new()
	effects_layer.board = self
	effects_layer.z_index = 100
	var vfx_clip := Control.new()
	vfx_clip.name = "EffectsClip"
	vfx_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vfx_clip.clip_contents = true
	vfx_clip.z_index = 100
	add_child(vfx_clip)
	vfx_clip.add_child(effects_layer)
	resized.connect(_reposition)

func cell_size() -> float:
	return maxf(24.0, minf((size.y - 52.0) / 8.0, (size.x - 70.0) / 6.0))

func grid_origin() -> Vector2:
	return Vector2((size.x - cell_size() * 6.0) * 0.5, 22.0)

func projection(x: float, y: float) -> Vector2:
	return grid_origin() + Vector2(x + 0.5, y + 0.5) * cell_size()

func cell_at(point: Vector2) -> Vector2i:
	var relative := (point - grid_origin()) / cell_size()
	return Vector2i(floori(relative.x), floori(relative.y))

func unit_in_cell(point: Vector2, only_owned: bool = true) -> Dictionary:
	var cell := cell_at(point)
	for u in snapshot.get("board", {}).get("units", []):
		if u.get("alive", true) and (not only_owned or int(u.team) == 0) and Vector2i(roundi(u.x), roundi(u.y)) == cell:
			return u
	return {}

func own_board() -> bool:
	return snapshot.get("watching", "you") == "you" and snapshot.get("phase", "") == "prepare"

func update_state(value: Dictionary) -> void:
	snapshot = value
	var live_keys := {}
	for u in value.get("board", {}).get("units", []):
		var key := str(u.uid)
		live_keys[key] = true
		if not pieces.has(key):
			var node := ChessPiece.new()
			unit_layer.add_child(node)
			pieces[key] = node
		var piece: ChessPiece = pieces[key]
		piece.draw_scale = cell_size() / 92.0
		piece.selected = key == selected_uid
		piece.z_index = int(float(u.y) * 10)
		piece.update_unit(u, projection(float(u.x), float(u.y)))
	for key in pieces.keys():
		if not live_keys.has(key):
			pieces[key].queue_free()
			pieces.erase(key)
	if effects_layer != null:
		effects_layer.update_state(value)
	queue_redraw()

func _reposition() -> void:
	if not snapshot.is_empty():
		update_state(snapshot)

func unit_at(point: Vector2, only_owned: bool = false) -> Dictionary:
	return unit_in_cell(point, only_owned)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_cell = cell_at(event.position)
		queue_redraw()
	if event is InputEventMouseButton and not event.pressed:
		if Time.get_ticks_msec() < ignore_click_until:
			return
		var u := unit_at(event.position)
		if not u.is_empty():
			if (own_board() and int(u.team) == 0) or snapshot.get("phase")=="battle":
				selected_uid = str(u.uid)
				selection_changed.emit(selected_uid)
			if event.button_index == MOUSE_BUTTON_RIGHT:
				inspect_unit.emit(u, get_global_mouse_position())

func _get_drag_data(at_position: Vector2):
	if not own_board():
		return null
	var u := unit_in_cell(at_position, true)
	if u.is_empty():
		return null
	selected_uid = str(u.uid)
	selection_changed.emit(selected_uid)
	if pieces.has(selected_uid):
		pieces[selected_uid].dragging = true
	var preview := TextureRect.new()
	preview.texture = ArtLibrary.actor_frame(int(u.id), int(u.star))
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(110, 110)
	preview.position = Vector2(-55, -85)
	set_drag_preview(preview)
	return {"kind": "unit", "uid": selected_uid, "id": u.id, "star": u.star}

func _can_drop_data(at_position: Vector2, data) -> bool:
	at_position = drop_position(at_position)
	if not own_board() or not data is Dictionary:
		return false
	var u := unit_in_cell(at_position, true)
	if data.get("kind") == "item":
		return not u.is_empty()
	if data.get("kind") != "unit":
		return false
	var cell := cell_at(at_position)
	return cell.x >= 0 and cell.x < 6 and cell.y >= 5 and cell.y < 8

func _drop_data(at_position: Vector2, data) -> void:
	at_position = drop_position(at_position)
	var u := unit_in_cell(at_position, true)
	if data.get("kind") == "item" and not u.is_empty():
		action.emit("equip", {"uid": u.uid, "index": int(data.index)})
	else:
		var cell := cell_at(at_position)
		action.emit("move", {"uid": data.uid, "c": cell.x, "r": cell.y})

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		drag_started = true
	elif what == NOTIFICATION_DRAG_END:
		drag_started = false
		for piece in pieces.values():
			piece.dragging = false
		ignore_click_until = Time.get_ticks_msec() + 180
		queue_redraw()

func _process(_delta: float) -> void:
	var previous_tick := int(ambient_time*12)
	ambient_time += _delta
	if int(ambient_time*12)!=previous_tick:
		queue_redraw()
	if drag_started:
		hover_cell = cell_at(pointer_local)
		queue_redraw()
	if effects_layer != null:
		for piece in pieces.values():
			piece.visual_clock = effects_layer.clock
			piece.time_scale = 0.0 if snapshot.get("paused", false) else float(snapshot.get("speed", 1))

func _draw() -> void:
	if background != null:
		draw_texture_rect(background, Rect2(Vector2.ZERO, size), false, Color(0.82, 0.88, 0.96))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.05, 0.075, 0.25))
	for i in 16:
		var edge_x := size.x*(0.05+fmod(i*0.173,0.18)) if i%2==0 else size.x*(0.77+fmod(i*0.117,0.18))
		var at := Vector2(edge_x+sin(ambient_time*0.4+i)*12,size.y*(0.08+fmod(i*0.131,0.84))+sin(ambient_time*0.7+i*2)*8)
		draw_circle(at,1.5,Color(1,0.85,0.5,0.35+sin(ambient_time*2+i)*0.2),true,-1,true)
	var cell := cell_size()
	var origin := grid_origin()
	var area := Rect2(origin, Vector2(6, 8) * cell)
	draw_rect(area.grow(6), Color("b1a079"), false, 2.0)
	if background != null:
		var dimensions := background.get_size()
		draw_texture_rect_region(background,area,Rect2(dimensions*Vector2(0.37,0.30),dimensions*Vector2(0.26,0.50)),Color(0.75,0.85,0.94))
	draw_rect(area.grow(3), Color("071219",0.45))
	for row in 8:
		for col in 6:
			var tile := Rect2(origin + Vector2(col, row) * cell, Vector2.ONE * cell)
			var fill := Color("243b44") if (col + row) % 2 == 0 else Color("2b444d")
			if own_board() and row >= 5:
				fill = Color("284b4b") if (col + row) % 2 == 0 else Color("315756")
			draw_rect(tile, Color(fill,0.52))
			draw_rect(tile, Color("577078"), false, 1.0)
			if drag_started and hover_cell == Vector2i(col, row):
				var valid := own_board() and row >= 5
				draw_rect(tile.grow(-2), Color(0.7, 0.9, 0.6, 0.25) if valid else Color(0.95, 0.3, 0.2, 0.25))
				draw_rect(tile.grow(-2), Color("d4e8a1") if valid else Color("f49c91"), false, 3)
				if valid:
					var occupied := unit_in_cell(tile.get_center(),true)
					draw_string(font,tile.position+Vector2(5,tile.size.y-6),"交换" if not occupied.is_empty() else "放置",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("edf3be"))
	for col in 6:
		draw_string(font, origin + Vector2((col + 0.5) * cell - 5, -7), String.chr(65 + col), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("92b3b5"))
	for row in 8:
		draw_string(font, origin + Vector2(-16, (row + 0.5) * cell + 4), str(8 - row), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("92b3b5"))
	if own_board():
		draw_line(origin + Vector2(0, 5 * cell), origin + Vector2(6 * cell, 5 * cell), Color("9bd3b4"), 2)
		draw_string(font, Vector2(origin.x, size.y - 7), "下方三排可布阵 · 拖至已有棋子交换", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("bad7c5"))
