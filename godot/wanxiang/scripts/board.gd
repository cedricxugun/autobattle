class_name BattleBoard
extends Control

signal action(command: String, arguments: Dictionary)
signal inspect_unit(unit: Dictionary, screen_position: Vector2)
signal selection_changed(uid: String)
signal scenery_hint(message: String)

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
var geometry_only := false
var stage: WorldArena
var ambient_time := 0.0

func _input(event: InputEvent) -> void:
	if geometry_only:return
	if event is InputEventMouse:
		pointer_local = get_global_transform_with_canvas().affine_inverse() * event.position
		pointer_known = true

func drop_position(fallback: Vector2) -> Vector2:
	return pointer_local if drag_started and pointer_known else fallback

func _ready() -> void:
	add_child(unit_layer)
	if geometry_only:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		return
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	font.font_names=["Microsoft YaHei UI","Microsoft YaHei","Segoe UI"]
	stage=WorldArena.new()
	stage.board=self
	add_child(stage)
	move_child(stage,0)
	effects_layer=load("res://scripts/effects.gd").new()
	effects_layer.board=self
	var vfx_clip:=Control.new()
	vfx_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	vfx_clip.clip_contents=true
	vfx_clip.z_index=100
	add_child(vfx_clip)
	vfx_clip.add_child(effects_layer)
	var overlay: Node2D =load("res://scripts/world_unit_hud.gd").new()
	overlay.board=self
	overlay.z_index=95
	add_child(overlay)
	stage.attach_fields(effects_layer)
	resized.connect(_reposition)

func cell_size() -> float:
	if geometry_only:return 128.0
	if stage==null:return 50.0
	return stage.project(2,3).distance_to(stage.project(3,3))

func cell_size_at(x: float, y: float) -> float:
	if geometry_only:return 128.0
	return stage.project(x-0.5,y).distance_to(stage.project(x+0.5,y))

func grid_bounds() -> Rect2:
	return Rect2(Vector2.ZERO,Vector2(768,1024)) if geometry_only else stage.bounds()

func grid_origin() -> Vector2:
	return grid_bounds().position

func projection(x: float, y: float) -> Vector2:
	return Vector2(x+0.5,y+0.5)*128 if geometry_only else stage.project(x,y)

func effect_projection(x: float, y: float) -> Vector2:
	return projection(x,y) if geometry_only else stage.project(x,y,0.7)

func cell_at(point: Vector2) -> Vector2i:
	if geometry_only:return Vector2i(floori(point.x/128),floori(point.y/128))
	return stage.cell_at(point)

func unit_in_cell(point: Vector2, only_owned: bool = true) -> Dictionary:
	var cell:=cell_at(point)
	for u in snapshot.get("board",{}).get("units",[]):
		if u.get("alive",true) and (not only_owned or int(u.team)==0) and Vector2i(roundi(u.x),roundi(u.y))==cell:return u
	return {}

func drop_target(point: Vector2) -> Dictionary:
	# Dropping follows the highlighted ground tile, even when a tall piece in
	# the next rank overlaps it on screen. Mesh picking is for selecting bodies.
	var ground_bench:=stage.bench_at(point)
	if ground_bench>=0:
		return {"kind":"bench","index":ground_bench,"unit":stage.bench_units[ground_bench] if ground_bench<stage.bench_units.size() else {}}
	var ground_cell:=cell_at(point)
	if ground_cell.x>=0 and ground_cell.x<6 and ground_cell.y>=5 and ground_cell.y<8:
		return {"kind":"board","cell":ground_cell,"unit":unit_in_cell(point,true)}
	var actor:=stage.pick_actor(point,true)
	if not actor.is_empty():
		if actor.get("bench",false):return {"kind":"bench","index":int(actor.benchIndex),"unit":actor}
		return {"kind":"board","cell":Vector2i(roundi(actor.x),roundi(actor.y)),"unit":actor}
	var index:=stage.bench_at(point)
	if index>=0:return {"kind":"bench","index":index,"unit":stage.bench_units[index] if index<stage.bench_units.size() else {}}
	return {"kind":"board","cell":cell_at(point),"unit":unit_in_cell(point,true)}

func own_board() -> bool:
	return snapshot.get("watching", "you") == "you" and snapshot.get("phase", "") == "prepare"

func update_state(value: Dictionary) -> void:
	snapshot=value
	stage.update_units(value)
	pieces.clear()
	for uid in stage.actors:
		pieces[uid]=stage.actors[uid].body
	if effects_layer!=null:effects_layer.update_state(value)
	queue_redraw()

func _reposition() -> void:
	if not snapshot.is_empty():
		update_state(snapshot)

func unit_at(point: Vector2, only_owned: bool = false) -> Dictionary:
	# Feet have priority over an overlapping foreground silhouette.
	for actor in stage.actors.values():
		var u:Dictionary=actor.unit
		if not u.get("alive",true) or (only_owned and int(u.team)!=0):continue
		var foot:=stage.camera.unproject_position(actor.global_position)
		if point.distance_to(foot)<cell_size()*0.24:return u
	var hit:=stage.pick_actor(point,only_owned)
	if not hit.is_empty():return hit
	var index:=stage.bench_at(point)
	if index>=0 and index<stage.bench_units.size():
		return stage.actors[str(stage.bench_units[index].uid)].unit
	return unit_in_cell(point,only_owned)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE and not drag_started:
			stage.yaw=clampf(stage.yaw-event.relative.x*0.12,-14,14)
			stage._set_camera()
		hover_cell = cell_at(event.position)
		queue_redraw()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			stage.zoom_size=clampf(stage.zoom_size+(-0.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.25),8.2,9.6)
			stage._set_camera()
			accept_event()
			return
	if event is InputEventMouseButton and not event.pressed:
		if Time.get_ticks_msec() < ignore_click_until:
			return
		if event.button_index==MOUSE_BUTTON_LEFT and stage.activate_scenery(event.position):
			scenery_hint.emit("星轨书台：这些圆环用来表示天球坐标，天上并没有实体轨道。")
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
	var u := unit_at(at_position, true)
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
	at_position=drop_position(at_position)
	if not own_board() or not data is Dictionary:return false
	var target:=drop_target(at_position)
	if data.get("kind")=="item":return not target.unit.is_empty()
	if data.get("kind")!="unit":return false
	if target.kind=="bench":return not target.unit.is_empty() or stage.bench_units.size()<9
	var cell:Vector2i=target.cell
	return cell.x>=0 and cell.x<6 and cell.y>=5 and cell.y<8

func _drop_data(at_position: Vector2, data) -> void:
	at_position=drop_position(at_position)
	var target:=drop_target(at_position)
	if data.get("kind")=="item" and not target.unit.is_empty():
		action.emit("equip",{"uid":target.unit.uid,"index":int(data.index)})
	elif target.kind=="bench":
		if target.unit.has("uid") and target.unit.uid!=data.uid:action.emit("replace_bench",{"uid":data.uid,"target":target.unit.uid})
		elif not target.unit.has("uid"):action.emit("move",{"uid":data.uid,"c":null,"r":null})
	else:
		var cell:Vector2i=target.cell
		action.emit("move",{"uid":data.uid,"c":cell.x,"r":cell.y})

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
	if geometry_only:return
	stage.highlight(pointer_local,drag_started and own_board())
	queue_redraw()

func _draw() -> void:
	if geometry_only:return
	var instruction:="拖动棋子布阵 · 近端石座为备战席 · 中键轻转 / 滚轮缩放" if own_board() else "点击关注棋子 · 按住 Alt 查看完整文字 · 中键查看场景"
	draw_string(font,Vector2(18,size.y-9),instruction,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("c7d5bd"))
