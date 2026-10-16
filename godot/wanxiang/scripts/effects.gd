extends Node2D

var board: BattleBoard
var data: Dictionary = {}
var clock := 0.0
var server_clock := 0.0
var rate := 1.0
var frozen := false
var finished := false
var context_key := ""
var seen: Dictionary = {}
var active: Array[Dictionary] = []
var numbers: Array[Dictionary] = []
var notices: Array[Dictionary] = []
var field_layer: Node2D
var font := SystemFont.new()
var soft: GradientTexture2D
var sound_enabled := true
var last_sound := -10.0
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var field_clip: Control
var hud: Node2D
var comic_line: Dictionary = {}
var last_comic_sound := -10.0

func _ready() -> void:
	font.font_names = ["Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI"]
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0, 0.22, 1])
	soft = GradientTexture2D.new()
	soft.gradient = gradient
	soft.width = 64
	soft.height = 64
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1, 0.5)
	hud = load("res://scripts/combat_hud.gd").new()
	hud.manager = self
	hud.z_index = 350
	board.add_child(hud)
	board.unit_layer.z_index = 5
	for i in 5:
		var player := AudioStreamPlayer.new()
		player.volume_db = -21
		add_child(player)
		voices.append(player)

func update_state(value: Dictionary) -> void:
	var key := str(value.get("matchKey", "")) + ":" + str(value.get("round", 0))
	data = value.get("board", {})
	server_clock = float(data.get("time", 0))
	if key != context_key or server_clock + 0.25 < clock and value.get("phase") == "prepare":
		context_key = key
		seen.clear()
		active.clear()
		numbers.clear()
		notices.clear()
		comic_line.clear()
		clock = server_clock
	clock = maxf(clock, server_clock)
	rate = float(value.get("speed", 1))
	frozen = bool(value.get("paused", false))
	finished = bool(data.get("done", false)) or value.get("phase") != "battle"
	for event in data.get("effects", []):
		var id := int(event.get("id", -1))
		if seen.has(id):
			continue
		seen[id] = true
		var e: Dictionary = event.duplicate(true)
		e.born = float(e.get("born", server_clock - float(e.life) + float(e.ttl)))
		if clock - e.born > maxf(float(e.life), 0.9):
			continue
		if e.type in ["text", "number"]:
			_add_number(e)
		else:
			active.append(e)
			if str(e.type).begins_with("gag_") and e.type!="gag_signature" and sound_enabled and clock-last_comic_sound>0.07:
				last_comic_sound=clock
				for voice in voices:
					if not voice.playing:
						voice.stream=ComicAudio.sound(str(e.type))
						voice.play()
						break
			if e.has("joke") and (comic_line.is_empty() or clock-float(comic_line.get("born",0))>2.2):
				comic_line = {"text":str(e.joke),"actor":int(e.get("actor",0)),"born":clock}
			if e.type == "cast":
				var notice := e.duplicate()
				notice.targets = []
				notice.target_names = []
				notice.operations = []
				notice.pending_target = ""
				notices.push_front(notice)
				if notices.size() > 4:
					notices.pop_back()
				_play_impact(str(e.faction), true)
			elif e.type == "contact" and e.get("skill", false):
				_play_impact(str(e.faction), false)
	for notice in notices:
		for cue in data.get("effects",[]):
			if str(cue.type).begins_with("gag_") and cue.get("skillToken") == notice.get("skillToken") and cue.get("targetUid")!=cue.get("sourceUid"):
				var pending := unit(str(cue.get("targetUid","")))
				if not pending.is_empty():
					notice.pending_target = str(ArtLibrary.character(int(pending.id)).name)
		for e in data.get("effects",[]):
			if e.get("skillToken") == null or e.get("skillToken") != notice.get("skillToken") or not e.type in ["contact","shield","heal","control"]:
				continue
			var target := unit(str(e.get("targetUid","")))
			if not target.is_empty() and not notice.targets.has(str(target.uid)):
				notice.targets.append(str(target.uid))
				notice.target_names.append(("友·" if int(target.team)==int(notice.team) else "敌·")+str(ArtLibrary.character(int(target.id)).name))
			var operation: String = {"contact":"伤害","shield":"护盾","heal":"治疗","control":"控制"}.get(str(e.type),"")
			if not notice.operations.has(operation):
				notice.operations.append(operation)

		for zone in data.get("zones",[]):
			if zone.get("skillToken")!=notice.get("skillToken") or zone.type!="triangle" or zone.vertices==null:
				continue
			if not notice.operations.has("区域减伤20%"):
				notice.operations.append("区域减伤20%")
			for vertex in zone.vertices:
				var target := unit(str(vertex.uid))
				if not target.is_empty() and not notice.targets.has(str(target.uid)):
					notice.targets.append(str(target.uid))
					notice.target_names.append("友·"+str(ArtLibrary.character(int(target.id)).name))

	if active.size() > 120:
		active = active.slice(active.size() - 120)
	queue_redraw()

func unit(uid: String) -> Dictionary:
	for u in data.get("units", []):
		if str(u.uid) == uid:
			return u
	return {}

func _add_number(e: Dictionary) -> void:
	var text := str(e.get("text", ""))
	var kind := str(e.get("numberType", "text"))
	if text.begins_with("+"):
		kind = "heal"
		e.amount = int(text.trim_prefix("+"))
	if e.type == "number" or kind == "heal":
		for prior in numbers:
			if prior.get("targetUid") == e.get("targetUid") and prior.kind == kind and clock - float(prior.born) < 0.20:
				prior.amount += int(e.amount)
				return
	var same_target := numbers.filter(func(n): return n.get("targetUid") == e.get("targetUid") and n.kind != "text")
	if kind != "text" and same_target.size() >= 3:
		numbers.erase(same_target[0])
		same_target.pop_front()
	var lane := 3 if kind == "text" else 0
	while kind != "text" and same_target.any(func(n): return int(n.lane)==lane) and lane<3:
		lane += 1
	e.kind = kind
	e.lane = lane
	e.life = 1.05 if kind == "text" else 0.95
	numbers.append(e)
	if numbers.size() > 65:
		numbers.pop_front()

func _process(delta: float) -> void:
	if not frozen:
		clock += delta * rate
		if not finished:
			clock = minf(clock, server_clock + 0.18 * rate)
	active = active.filter(_cue_alive)
	numbers = numbers.filter(func(e): return clock - float(e.born) < float(e.life))
	notices = notices.filter(func(e): return clock - float(e.born) < 4.0)
	var clip: Control=get_parent()
	clip.position=Vector2.ZERO
	clip.size=board.size
	position=Vector2.ZERO
	hud.queue_redraw()
	queue_redraw()

func _cue_alive(e: Dictionary) -> bool:
	if clock-float(e.born)>=float(e.life)+(0.18 if e.type in ["bolt","orb"] else 0.0):return false
	if e.type in ["gag_gavel","gag_house"]:
		var caster:=unit(str(e.get("sourceUid","")))
		if caster.is_empty() or not caster.get("alive",true):return false
		if "stun" in caster.get("buffs",[]) or "silence" in caster.get("buffs",[]):return false
	return true

func glow(at: Vector2, radius: float, color: Color, alpha: float) -> void:
	if radius > 0:
		draw_texture_rect(soft, Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, Color(color, alpha))

func stroke(points: PackedVector2Array, color: Color, width: float, alpha: float) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, Color(color, alpha * 0.12), width * 5, true)
	draw_polyline(points, Color(color, alpha * 0.45), width * 2, true)
	draw_polyline(points, Color(color.lightened(0.45), alpha), width, true)

func _draw() -> void:
	if board == null or soft == null:
		return
	var crowded:bool=data.get("units",[]).filter(func(u):return u.get("alive",true)).size()>8
	for e in active:
		if e.type=="gag_signature" and crowded and str(e.get("sourceUid",""))!=board.selected_uid:continue
		if board.stage.world_effects!=null and board.stage.world_effects.handles(e):continue
		var age := maxf(0, clock - float(e.born))
		var t := clampf(age / maxf(0.05, float(e.life)), 0, 1)
		var fade := pow(1.0 - t, 1.2)
		var p := board.effect_projection(float(e.x),float(e.y))
		var q := board.effect_projection(float(e.x2),float(e.y2))
		var end_unit := unit(str(e.get("targetUid","")))
		var anchor := unit(str(e.get("anchorUid","")))
		var target_x:float=float(end_unit.get("x",e.x2))
		var target_y:float=float(end_unit.get("y",e.y2))
		var cell:=board.cell_size_at(lerpf(float(e.x),target_x,t),lerpf(float(e.y),target_y,t))
		if e.type in ["bolt","orb","beam","chain","link","vine","charge"] and not end_unit.is_empty():
			q = board.effect_projection(end_unit.x,end_unit.y)
		if e.type in ["beam","chain","link","vine","charge"] and not anchor.is_empty():
			p = board.effect_projection(anchor.x,anchor.y)
		var color := ArtLibrary.faction_color(str(e.get("faction", "math")))
		if str(e.type).begins_with("gag_"):
			GagRenderer.draw(self,e,age,p,q,cell,font,data.get("units",[]))
			continue
		var direction := (q - p).normalized()
		if direction.length_squared() < 0.01:
			direction = Vector2.RIGHT
		var perpendicular := direction.orthogonal()
		var seed_value := float(e.get("id", 1))
		match str(e.type):
			"bolt", "orb":
				var travel := minf(0.27, float(e.life))
				var progress := clampf(age / travel, 0, 1)
				var at := p.lerp(q, progress)
				for i in 10:
					var trail_t := maxf(0, progress - i * 0.018)
					var trail := p.lerp(q, trail_t)
					glow(trail, (9.0 - i * 0.6) * cell / 60, color, (1.0 - i / 10.0) * fade * 0.6)
				stroke(PackedVector2Array([at - direction * cell * 0.24, at]), color, 2.0, fade)
				glow(at, cell * 0.16, Color.WHITE, fade)
				if progress >= 1:
					draw_arc(q, 4 + (age - travel) * 85, 0, TAU, 32, Color(color, fade), 1.5, true)
			"slash":
				var center := q
				var angle := direction.angle() + PI
				var points := PackedVector2Array()
				for i in 17:
					var sweep := float(i) / 16
					var a := angle - 1.1 + 2.2 * sweep * minf(1, t * 3)
					points.append(center + Vector2.from_angle(a) * cell * (0.28 + t * 0.16))
				stroke(points, color, 2.5 * (1-t), fade)
			"beam", "chain", "vine", "link", "inkwave", "dash":
				var points := PackedVector2Array()
				for i in 25:
					var along := float(i) / 24
					var bend := sin(along * PI) * (sin(along * 25 + age * 20) * 5 if e.type == "chain" else sin(age * 4 + along * 5) * 4)
					points.append(p.lerp(q, along) + perpendicular * bend)
				var width := 4.0 if e.type in ["beam", "inkwave"] else 1.2
				stroke(points, color, width * (0.5 + fade), fade * 0.85)
				for i in 4:
					var along := fmod(age * 1.8 + float(i) / 4, 1)
					glow(p.lerp(q, along), 5, color, fade)
				glow(q, cell * 0.18, color, fade * 0.6)
				if e.type=="link" and str(e.faction)=="literature":
					var caption := "对偶 · 增益传递" if int(e.get("actor",0))==39 else "叙事 · 因果连接" if int(e.get("actor",0))==42 else "借形 · 能力取样"
					var midpoint := p.lerp(q,0.5)
					draw_string_outline(font,midpoint+Vector2(-35,-8),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10,3,Color("121724",fade))
					draw_string(font,midpoint+Vector2(-35,-8),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(color,fade))
					for at in [p,q]:
						stroke(PackedVector2Array([at+Vector2(-8,-12),at+Vector2(-8,12),at+Vector2(8,12)]),color,1.5,fade)
				if e.type == "inkwave":
					for i in 18:
						var along := fmod(float(i) * 0.059 + age, 1)
						var at := p.lerp(q, along) + perpendicular * sin(i * 2.4) * cell * 0.2
						draw_circle(at, 2 + sin(i) * 0.8, Color("d7cbb2", fade * 0.6), true, -1, true)
			"charge", "cast":
				var radius := cell * (0.58 - t * 0.32)
				for i in 9:
					var angle := i * TAU / 9 + t * 1.1
					var at := p + Vector2.from_angle(angle) * radius
					glow(at, 4, color, sin(t * PI) * 0.8)
				if e.type == "cast":
					glow(p, cell * 0.38, color, fade * 0.3)
			"shield", "heal", "ring", "echo", "summon", "control", "seal", "mark", "wall":
				var radius := cell * (0.30 + sin(t * PI) * 0.14)
				if e.type == "shield":
					draw_arc(p, radius, PI * 1.05, PI * 2.95, 48, Color(color, fade * 0.8), 2, true)
					glow(p, radius, color, fade * 0.12)
				elif e.type in ["control", "seal"]:
					for i in 4:
						var at := p + Vector2.from_angle(i * PI * 0.5 + PI * 0.25) * radius
						stroke(PackedVector2Array([at + Vector2(-4, 8), at, at + Vector2(4, 8)]), color, 1.3, fade)
				else:
					for i in 7:
						var at := p + Vector2(sin(i * 3.4) * radius, radius * 0.4 - t * cell * (0.3 + i * 0.05))
						glow(at, 4.0, Color("a7e5bc") if e.type == "heal" else color, fade * 0.65)
			"reaction":
				var separation := cell*0.3*maxf(0,1-t*3)
				for side in [-1,1]:
					var at := p+Vector2(side*separation,-t*10)
					glow(at,cell*0.18,Color("abd98a") if side<0 else Color("f0bf81"),fade)
					draw_arc(at,cell*0.16,0,TAU,24,Color(color,fade),1.5,true)
				draw_string_outline(font,p+Vector2(-42,-cell*0.55),str(e.get("text","化学反应")),HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color("101c22",fade))
				draw_string(font,p+Vector2(-42,-cell*0.55),str(e.get("text","化学反应")),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d5eda5",fade))
			"contact", "burst", "nova", "impact", "death":
				var major: bool = e.type in ["nova", "impact", "burst"]
				var radius := cell * (0.8 if major else 0.25)
				if major:
					radius *= minf(2.5, float(e.get("r", 1)))
					var ripple := radius * (1-pow(1-t, 3))
					draw_arc(p, maxf(1,ripple), 0, TAU, 48, Color(color, fade * 0.65), 2.0 * fade + 0.3, true)
				glow(p, radius * (0.4 + t), color, pow(fade, 4) * 0.7)
				glow(p, radius * 0.22, Color.WHITE, maxf(0, 1-t*6) * 0.8)
				for i in (20 if major else 6):
					var angle := i * 2.39996 + seed_value * 1.7
					var speed_value := 0.45 + fmod(float(i) * 0.31, 0.6)
					var distance_value := radius * speed_value * (1-pow(1-t, 2))
					var at := p + Vector2.from_angle(angle) * distance_value
					at.y += t*t*cell*0.25 if e.type != "death" else -t*cell*0.6
					stroke(PackedVector2Array([at, at-Vector2.from_angle(angle)*4*fade]), color, 1.3, fade)
	_draw_numbers()


func _draw_focus(canvas: CanvasItem) -> void:
	if board.selected_uid.is_empty() or board.drag_started:return
	var focused := unit(board.selected_uid)
	if focused.is_empty() and board.stage.actors.has(board.selected_uid):focused=board.stage.actors[board.selected_uid].unit
	if focused.is_empty():return
	var d:=ArtLibrary.character(int(focused.id))
	canvas.draw_rect(Rect2(12,14,248,91),Color(0.035,0.065,0.10,0.86))
	canvas.draw_texture_rect(ArtLibrary.actor_frame(int(focused.id),int(focused.star),0),Rect2(18,19,72,72),false)
	canvas.draw_string(font,Vector2(98,39),str(d.name)+" "+"★".repeat(int(focused.star)),HORIZONTAL_ALIGNMENT_LEFT,155,15,ArtLibrary.faction_color(str(d.faction)))
	canvas.draw_string(font,Vector2(98,62),str(d.skill),HORIZONTAL_ALIGNMENT_LEFT,155,12,Color("e5d4b1"))
	canvas.draw_string(font,Vector2(98,84),"右键查看技能与知识",HORIZONTAL_ALIGNMENT_LEFT,155,11,Color("b4c5c6"))

func _draw_numbers() -> void:
	var occupied: Array[Rect2] = []
	var dense:bool=data.get("units",[]).filter(func(u):return u.get("alive",true)).size()>8
	for e in numbers:
		var age := maxf(0, clock - float(e.born))
		var t := clampf(age / float(e.life), 0, 1)
		var kind := str(e.kind)
		var amount := int(e.get("amount", 0))
		var text := str(e.get("text", ""))
		var focused:bool=str(e.get("targetUid",""))==board.selected_uid or str(e.get("sourceUid",""))==board.selected_uid
		if dense and not focused and not Input.is_key_pressed(KEY_ALT):
			if kind=="absorbed" and amount<25:continue
			if kind=="text" and not ["眩晕","沉默","禁足","闪避","免疫","暴击","净化"].any(func(word):return text.contains(word)):continue
		var color := Color("f1d8aa")
		if kind == "magic":
			color = Color("91d9ff")
		elif kind == "heal":
			color = Color("93ecc0")
		elif kind == "absorbed":
			color = Color("bbbed8")
		if kind != "text":
			text = ("+" if kind == "heal" else "盾 " if kind == "absorbed" else "") + str(amount)
		var big := kind in ["physical", "magic"] and amount >= 160
		var point := board.stage.project(float(e.x),float(e.y),1.55)
		point += Vector2((int(e.lane)-1) * 23, -int(e.lane)*13)
		point += Vector2(sin(float(e.get("id",0)))*t*15, -30*(1-pow(1-t,2)))
		var alpha := minf(1, (1-t)*3.5)
		var font_size := int((22 if big else 12 if kind=="absorbed" or amount<25 else 15 if kind != "text" else 12) * (1 + maxf(0,1-age/0.12)*0.22))
		var extent := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		point.x = clampf(point.x,board.grid_origin().x+2,board.grid_bounds().end.x-extent.x-2)
		var rect := Rect2(point-Vector2(2,extent.y),extent+Vector2(4,4))
		for attempt in 7:
			if not occupied.any(func(other): return other.intersects(rect)):
				break
			point.y -= 13
			rect.position.y -= 13
		occupied.append(rect)
		draw_string_outline(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.02,0.035,0.05,alpha))
		draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color,alpha))

func _draw_notices(canvas: CanvasItem) -> void:
	if notices.is_empty():return
	var y:=board.size.y-72
	var visible_notices:=notices.slice(0,2)
	canvas.draw_rect(Rect2(12,y-17,390,visible_notices.size()*26+10),Color(0.025,0.05,0.085,0.76))
	for n in visible_notices:
		var target: String="、".join(n.target_names.slice(0,1)) if not n.target_names.is_empty() else str(n.get("pending_target","范围内目标"))
		var text:=str(n.sourceName)+" · "+str(n.skillName)+" → "+target
		canvas.draw_string(font,Vector2(20,y),text,HORIZONTAL_ALIGNMENT_LEFT,374,12,ArtLibrary.faction_color(str(n.faction)))
		y+=26

func _play_impact(school: String, cast: bool) -> void:
	if not sound_enabled or clock-last_sound < 0.13:
		return
	last_sound = clock
	var key := school + str(cast)
	if not sounds.has(key):
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		var bytes := PackedByteArray()
		var samples := 6500 if cast else 2300
		bytes.resize(samples*2)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(key)
		var low := 0.0
		var frequency: float = {"math":620,"physics":110,"chemistry":230,"history":85,"literature":340,"law":440}.get(school,150)
		for i in samples:
			var time := float(i)/22050
			var ratio := float(i)/samples
			low = lerpf(low,rng.randf_range(-1,1),0.35)
			var tone := sin(TAU*frequency*time*(1-ratio*0.2))*exp(-ratio*7)
			var noise_value := low*exp(-ratio*5)*(0.65 if cast else 1.0)
			bytes.encode_s16(i*2,int((tone*0.45+noise_value)*10000*minf(1,ratio*30)))
		wav.data = bytes
		sounds[key] = wav
	for player in voices:
		if not player.playing:
			player.stream = sounds[key]
			player.play()
			break
