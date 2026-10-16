class_name ArtLibrary
extends RefCounted

static var textures: Dictionary = {}
static var frame_cache: Dictionary = {}
static var catalog: Dictionary = {}
static var animation_cache: Dictionary = {}
static var layouts: Dictionary = {}
static var prop_layouts: Dictionary = {}

static func prop(name: String) -> AtlasTexture:
	var key := "prop:"+name
	if frame_cache.has(key):
		return frame_cache[key]
	if prop_layouts.is_empty():
		prop_layouts = JSON.parse_string(FileAccess.get_file_as_string("res://data/prop-layouts.json"))
	if not prop_layouts.has(name):
		return null
	var entry: Dictionary = prop_layouts[name]
	var source := texture_at("res://assets/props/"+str(entry.file))
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(entry.rect[0],entry.rect[1],entry.rect[2],entry.rect[3])
	atlas.filter_clip = true
	frame_cache[key] = atlas
	return atlas

static func data() -> Dictionary:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	return catalog

static func character(id: int) -> Dictionary:
	var all := data()
	return all.characters[id] if id < 54 else all.monsters[id - 54]

static func texture_at(path: String) -> Texture2D:
	if textures.has(path):
		return textures[path]
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		return null
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	textures[path] = texture
	return texture

static func has_animation(id: int) -> bool:
	return FileAccess.file_exists("res://assets/characters/%03d.png" % id)

static func actor_frame(id: int, star: int = 1, frame: int = 0) -> AtlasTexture:
	var key := "%s:%s:%s" % [id, star, frame]
	if frame_cache.has(key):
		return frame_cache[key]
	var path := "res://assets/characters/%03d.png" % id
	var revised := "res://assets/characters/%03d-v2.png" % id
	if FileAccess.file_exists(revised):
		path = revised
	var source := texture_at(path)
	var rect: Rect2
	var frame_layout: Dictionary = {}
	if layouts.is_empty() and FileAccess.file_exists("res://data/atlas-layouts.json"):
		layouts = JSON.parse_string(FileAccess.get_file_as_string("res://data/atlas-layouts.json"))
	if layouts.has(path.get_file()):
		frame_layout = layouts[path.get_file()]
	if source != null:
		if not frame_layout.is_empty():
			var index := clampi(frame, 0, 8) + (0 if id >= 54 else clampi(star - 1, 0, 2) * 9)
			var r: Array = frame_layout.frames[index]
			rect = Rect2(r[0], r[1], r[2], r[3])
		elif id >= 54:
			var cell := Vector2(source.get_width() / 3.0, source.get_height() / 3.0)
			rect = Rect2(Vector2(clampi(frame, 0, 8) % 3, clampi(frame, 0, 8) / 3) * cell, cell)
		else:
			var cell := Vector2(source.get_width() / 9.0, source.get_height() / 3.0)
			rect = Rect2(Vector2(clampi(frame, 0, 8) * cell.x, clampi(star - 1, 0, 2) * cell.y), cell)
	else:
		var d := character(id)
		source = texture_at("res://assets/%s.png" % d.faction)
		if source == null:
			return null
		var cell := Vector2(source.get_width() / 3.0, source.get_height() / 3.0)
		rect = Rect2(Vector2(int(d.cell) % 3, int(d.cell) / 3) * cell, cell)
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = rect
	atlas.filter_clip = true
	if not frame_layout.is_empty():
		var canvas := Vector2(frame_layout.canvas[0], frame_layout.canvas[1])
		atlas.margin = Rect2(Vector2((canvas.x - rect.size.x) * 0.5, canvas.y - rect.size.y - 10), canvas - rect.size)
	frame_cache[key] = atlas
	return atlas

static func sprite_frames(id: int, star: int) -> SpriteFrames:
	var key := "%d:%d" % [id, star]
	if animation_cache.has(key):
		return animation_cache[key]
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var sequences := {"idle": [0], "walk": [1, 2, 3, 4], "attack": [6, 7, 0], "hurt": [8], "cast": [5]}
	for animation in sequences:
		result.add_animation(animation)
		result.set_animation_speed(animation, 8.0 if animation == "walk" else 7.0)
		result.set_animation_loop(animation, animation in ["walk", "idle"])
		for frame in sequences[animation]:
			var tex := actor_frame(id, star, frame)
			if tex != null:
				result.add_frame(animation, tex)
	animation_cache[key] = result
	return result

static func effect_frame(faction_id: String, row: int, frame: int) -> AtlasTexture:
	var key := "fx:%s:%d:%d" % [faction_id, row, frame]
	if frame_cache.has(key):
		return frame_cache[key]
	var path := "res://assets/effects/%s.png" % faction_id
	var tex := texture_at(path)
	if tex == null:
		return null
	var cell := Vector2(tex.get_width() / 4.0, tex.get_height() / 2.0)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(Vector2(clampi(frame, 0, 3) * cell.x, clampi(row, 0, 1) * cell.y), cell)
	frame_cache[key] = atlas
	return atlas

static func faction_color(id: String) -> Color:
	for f in data().factions:
		if f.id == id:
			return Color(f.color)
	return Color("d9ac7b")

static func quality_color(cost: int) -> Color:
	return Color(data().quality_colors[clampi(cost,1,5)])

static func item_frame(id: String) -> AtlasTexture:
	var ids := ["blade", "armor", "heart", "tempo", "focus", "veil"]
	var index := ids.find(id)
	var tex := texture_at("res://assets/equipment.png")
	if index < 0 or tex == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	var cell := tex.get_size() / Vector2(3, 2)
	atlas.region = Rect2(Vector2(index % 3, index / 3) * cell, cell)
	return atlas
