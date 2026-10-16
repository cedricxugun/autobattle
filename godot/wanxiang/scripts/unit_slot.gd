class_name UnitSlot
extends PanelContainer

signal command_requested(command: String, arguments: Dictionary)
signal inspected(info: Dictionary, at: Vector2)

var mode := "bench"
var info: Dictionary = {}
var editable := true
var ignore_click_until := 0
var picture := TextureRect.new()
var title_label := Label.new()
var sub_label := Label.new()
var quality_label := Label.new()
var reveal_age := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	add_child(vbox)
	quality_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	quality_label.add_theme_font_size_override("font_size",11)
	quality_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	vbox.add_child(quality_label)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(60, 62 if mode == "shop" else 44)
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(picture)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 14 if mode == "shop" else 11)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 10)
	sub_label.modulate = Color("acc4bd")
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sub_label)
	sub_label.visible = mode == "shop"
	for c in [vbox, title_label, sub_label]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()

func refresh() -> void:
	if not is_node_ready():
		return
	if mode == "item":
		picture.visible = true
		picture.custom_minimum_size = Vector2(26, 26)
		picture.texture = ArtLibrary.item_frame(str(info.get("id", "")))
		title_label.text = str(info.get("name", "遗物"))
		sub_label.text = str(info.get("desc", ""))
		tooltip_text = sub_label.text
		return
	if info.is_empty() or info.get("sold", false):
		quality_label.text=""
		picture.texture = null
		title_label.text = "已招募" if mode == "shop" else "空位"
		sub_label.text = ""
		return
	var id := int(info.id)
	var d := ArtLibrary.character(id)
	var quality:=ArtLibrary.quality_color(int(d.cost))
	var frame:=StyleBoxFlat.new()
	frame.bg_color=Color("182630").lerp(quality,0.09 if int(d.cost)<5 else 0.20)
	frame.border_color=quality
	frame.set_border_width_all(1 if int(d.cost)<4 else 2)
	frame.border_width_top=3 if int(d.cost)<5 else 5
	frame.set_corner_radius_all(6)
	frame.content_margin_top=4
	frame.content_margin_bottom=4
	add_theme_stylebox_override("panel",frame)
	quality_label.text="%s · %d 金"%[ArtLibrary.data().quality[int(d.cost)],int(d.cost)]
	quality_label.modulate=quality
	title_label.modulate=quality
	picture.texture = ArtLibrary.actor_frame(id, int(info.get("star", 1)))
	title_label.text = str(d.name) + (" · %d" % int(d.cost) if mode == "shop" else " " + "★".repeat(int(info.get("star", 1))))
	var school_name := str(d.faction)
	for f in ArtLibrary.data().factions:
		if f.id == d.faction:
			school_name = f.name
	sub_label.text = school_name + " · " + ArtLibrary.data().roles[d.role].name
	tooltip_text = d.name + "\n" + d.skill + "\n" + d.desc
	if d.get("legendary",false):tooltip_text+="\n定位："+str(d.identity)+"\n应对："+str(d.counter)

func _process(delta:float) -> void:
	reveal_age+=delta
	if mode=="shop" and int(info.get("cost",0))==5 and not info.get("sold",false):
		quality_label.modulate=ArtLibrary.quality_color(5).lightened((sin(reveal_age*3)+1)*0.10)

func _gui_input(event: InputEvent) -> void:
	if mode == "item":
		return
	if event is InputEventMouseButton and not event.pressed and Time.get_ticks_msec() >= ignore_click_until:
		if info.is_empty() or info.get("sold", false):
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			inspected.emit(info, get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_LEFT and editable and mode == "shop":
			command_requested.emit("buy", {"slot": int(info.slot)})

func _get_drag_data(_at_position: Vector2):
	if not editable or info.is_empty():
		return null
	if mode == "shop":
		return null
	modulate.a = 0.45
	var preview := VBoxContainer.new()
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(100, 100)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if mode == "bench":
		image.texture = ArtLibrary.actor_frame(int(info.id), int(info.star))
	elif mode == "item":
		image.texture = ArtLibrary.item_frame(str(info.id))
	preview.add_child(image)
	var caption := Label.new()
	caption.text = str(info.name) if mode == "item" else str(ArtLibrary.character(int(info.id)).name)
	preview.add_child(caption)
	preview.position = Vector2(-50, -90)
	set_drag_preview(preview)
	return {"kind": "item", "index": int(info.index)} if mode == "item" else {"kind": "unit", "uid": info.uid, "id": info.id, "star": info.star}

func _can_drop_data(_at_position: Vector2, value) -> bool:
	return editable and mode == "bench" and value is Dictionary and (value.get("kind") == "unit" or (value.get("kind") == "item" and info.has("uid")))

func _drop_data(_at_position: Vector2, value) -> void:
	if value.get("kind") == "item":
		command_requested.emit("equip", {"uid": info.uid, "index": int(value.index)})
		return
	if info.has("uid") and info.uid != value.uid:
		command_requested.emit("replace_bench", {"uid": value.uid, "target": info.uid})
	elif not info.has("uid"):
		command_requested.emit("move", {"uid": value.uid, "c": null, "r": null})

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0
		ignore_click_until = Time.get_ticks_msec() + 180
