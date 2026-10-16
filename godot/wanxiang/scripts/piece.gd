class_name ChessPiece
extends Node2D

var state: Dictionary = {}
var sprite := AnimatedSprite2D.new()
var target_position := Vector2.ZERO
var actor_id := -1
var star := 0
var selected := false
var dragging := false
var animation_name := "idle"
var time_alive := 0.0
var upgrade_age := 10.0
var draw_scale := 1.0
var death_age := 0.0
var name_label := Label.new()
var visual_clock := 0.0
var time_scale := 1.0
var motion := Vector2.ZERO
var facing := 1.0
var previous_target := Vector2.ZERO
var actor_material := ShaderMaterial.new()
var action_label := Label.new()
var motion_profile: Dictionary = {}
var trailing_health := 1.0
var previous_health := 1.0
var health_delay := 0.0
var accessory := Sprite2D.new()

func _ready() -> void:
	add_child(sprite)
	add_child(accessory)
	sprite.position = Vector2(0, -48)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	actor_material.shader = preload("res://shaders/actor.gdshader")
	sprite.material = actor_material
	name_label.text = ""
	var font := SystemFont.new()
	font.font_names = ["Microsoft YaHei UI", "Microsoft YaHei"]
	name_label.add_theme_font_override("font", font)
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_shadow_color", Color("071019"))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-60, 8)
	name_label.size = Vector2(120, 20)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	action_label.add_theme_font_override("font", font)
	action_label.add_theme_font_size_override("font_size", 9)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(action_label)

func update_unit(value: Dictionary, destination: Vector2) -> void:
	state = value
	var next_id := int(value.id)
	var next_star := int(value.star)
	if actor_id != next_id or star != next_star:
		if star > 0 and next_star > star:
			upgrade_age = 0.0
		actor_id = next_id
		star = next_star
		motion_profile = MotionProfile.for_actor(actor_id)
		var accessories := {10:"magnet",19:"soda",29:"parcel",38:"crown",44:"ears",46:"camera"}
		accessory.texture = ArtLibrary.prop(accessories[actor_id]) if accessories.has(actor_id) else null
		trailing_health = float(value.get("hp",1))/maxf(1,float(value.get("maxhp",1)))
		name_label.text = str(ArtLibrary.character(actor_id).name)
		sprite.sprite_frames = ArtLibrary.sprite_frames(actor_id, star)
		position = destination
		animation_name = ""
	motion = destination - target_position if actor_id == next_id else Vector2.ZERO
	target_position = destination
	actor_material.set_shader_parameter("school_color", ArtLibrary.faction_color(str(value.get("faction", "math"))))
	if value.get("alive",true):
		death_age = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	var dt := delta*time_scale
	time_alive += dt
	upgrade_age += dt
	if state.is_empty() or sprite.sprite_frames == null:
		return
	var dead := not bool(state.get("alive",true))
	var health := float(state.get("hp",1))/maxf(1,float(state.get("maxhp",1)))
	if health < previous_health:
		health_delay = 0.18
	previous_health = health
	health_delay -= dt
	if health >= trailing_health:
		trailing_health = health
	elif health_delay <= 0:
		trailing_health = move_toward(trailing_health,health,dt*0.8)
	var hit_age := visual_clock-float(state.get("hitAt",-99))
	var attack_age := visual_clock-float(state.get("attackAt",-99))
	var skill_age := visual_clock-float(state.get("castAt",-99))
	var windup_age := visual_clock-float(state.get("attackWindupAt",-99))
	var casting: bool = state.get("casting",false) and visual_clock < float(state.get("castEnd",-99))
	var aim := Vector2(float(state.get("aimX",state.x))-float(state.x),float(state.get("aimY",state.y))-float(state.y))
	if state.get("moving",false) and motion.length_squared() > 0.001:
		aim = motion
	if aim.length_squared() < 0.02:
		aim = target_position-position
	if absf(aim.x) > 0.06:
		facing = signf(aim.x)
	sprite.flip_h = facing < 0
	aim = aim.normalized()
	var desired := "idle"
	var frame := 0
	var recoil := Vector2.ZERO
	var lean := 0.0
	var squash := Vector2.ONE
	var status := ""
	if dead:
		death_age += dt
		desired = "hurt"
		status = ""
		sprite.rotation = minf(0.8,death_age*1.8)*facing
	elif "stun" in state.get("buffs",[]):
		desired = "hurt"
		status = "眩晕"
	elif hit_age >= 0 and hit_age < 0.09 and not casting and attack_age > 0.38 and skill_age > 0.38 and windup_age > 0.18:
		desired = "hurt"
		var from := Vector2(state.get("hitFromX",state.x),state.get("hitFromY",state.y))
		recoil = (Vector2(state.x,state.y)-from).normalized()*5*(1-hit_age/0.09)
	elif casting:
		desired = "cast"
		status = str(ArtLibrary.character(actor_id).skill) + " · 蓄力"
		recoil = -aim*4
		squash = Vector2(1.025,0.975)
		lean = -aim.x*0.045
	elif windup_age >= 0 and windup_age < 0.18:
		desired = "cast"
		recoil = -aim*5*sin(windup_age/0.18*PI*0.5)
		lean = -aim.x*0.07
	elif minf(attack_age,skill_age) >= 0 and minf(attack_age,skill_age) < 0.38:
		var age := minf(attack_age,skill_age)
		desired = "attack"
		frame = 0 if age < 0.12 else 1 if age < 0.28 else 2
		recoil = aim*float(motion_profile.lunge)*sin(clampf(age/0.28,0,1)*PI)
		squash = Vector2(1.0+sin(clampf(age/0.28,0,1)*PI)*0.035,1.0-sin(clampf(age/0.28,0,1)*PI)*0.02)
		lean = aim.x*0.09*sin(clampf(age/0.28,0,1)*PI)
		if skill_age < 0.38:
			status = str(ArtLibrary.character(actor_id).skill)
	elif state.get("moving",false):
		desired = "walk"
		frame = int(visual_clock*float(motion_profile.cadence))%4
		lean = sin(visual_clock*float(motion_profile.cadence)*2)*float(motion_profile.lean)
	if not dead and hit_age >= 0 and hit_age < 0.09 and desired != "hurt":
		var from := Vector2(state.get("hitFromX",state.x),state.get("hitFromY",state.y))
		recoil += (Vector2(state.x,state.y)-from).normalized()*2*(1-hit_age/0.09)
	if not dead:
		sprite.rotation = lean
	animation_name = desired
	sprite.animation = desired
	sprite.frame = frame
	sprite.pause()
	if not dragging and dt>0:
		position = position.lerp(target_position,minf(1,delta*24*maxf(1,time_scale)))
	var tex := sprite.sprite_frames.get_frame_texture(desired,frame)
	var desired_size := 108.0*draw_scale*(0.67 if state.get("summon",false) else 1.0)
	var base := desired_size/maxf(tex.get_width(),tex.get_height())
	var breath := sin(time_alive*2.5+actor_id)*float(motion_profile.breath) if desired=="idle" else 0.0
	var pop := 1+sin(upgrade_age/0.65*PI)*0.13 if upgrade_age<0.65 else 1.0
	sprite.scale = Vector2(base*pop*(1-breath*0.35),base*pop*(1+breath))*squash
	sprite.position = Vector2(0,-desired_size*0.04)+recoil*draw_scale
	if desired=="walk":
		sprite.position.y -= absf(sin(visual_clock*float(motion_profile.cadence)*2))*float(motion_profile.bob)*draw_scale
	if not dead:
		sprite.position.y -= (1+sin(time_alive*2.6+actor_id))*float(motion_profile.hover)*draw_scale
	if accessory.texture != null:
		var accessory_size := desired_size*0.25
		accessory.scale = Vector2.ONE*accessory_size/maxf(accessory.texture.get_width(),accessory.texture.get_height())
		accessory.position = sprite.position+Vector2(facing*desired_size*0.22,-desired_size*0.12)
		if actor_id in [38,44]:
			accessory.position = sprite.position+Vector2(facing*desired_size*0.18,-desired_size*0.31)
		accessory.rotation = sprite.rotation+sin(time_alive*3+actor_id)*0.06
		accessory.flip_h = sprite.flip_h
		accessory.visible = not dead and (actor_id!=44 or casting or skill_age<0.6)
	actor_material.set_shader_parameter("flash",maxf(0,1-hit_age/0.13) if hit_age>=0 else 0.0)
	actor_material.set_shader_parameter("charge",(0.4+sin(visual_clock*16)*0.15) if casting else 0.0)
	actor_material.set_shader_parameter("dissolve",clampf((death_age-0.12)/0.43,0,1) if dead else 0.0)
	modulate.a = 0.35 if dragging else 0.7 if state.get("summon",false) else 1.0
	if dead:
		modulate.a *= maxf(0,1-death_age/0.55)
	visible = not dead or death_age<0.55
	name_label.position = Vector2(-55,desired_size*0.31)
	name_label.size = Vector2(110,16)
	name_label.add_theme_font_size_override("font_size",9)
	action_label.position = Vector2(-90,-desired_size*0.80)
	action_label.size = Vector2(180,16)
	action_label.text = status
	action_label.modulate = ArtLibrary.faction_color(str(state.get("faction","math")))
	queue_redraw()

func _draw() -> void:
	if state.is_empty():
		return
	var color := Color("87d4b0") if int(state.get("team", 0)) == 0 else Color("db978b")
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 31.0 * draw_scale, Color(0.02, 0.04, 0.06, 0.34))
	draw_arc(Vector2.ZERO, 32.0 * draw_scale, 0, TAU, 32, Color(color, 0.7), 1.8)
	if selected:
		draw_arc(Vector2.ZERO, 37.0 * draw_scale, 0, TAU, 32, Color("f0d18e"), 2.5)
	draw_set_transform(Vector2.ZERO)
	var hp := float(state.get("hp", 1.0)) / maxf(1.0, float(state.get("maxhp", 1.0)))
	var bar := Rect2(-26 * draw_scale, -48 * draw_scale, 52 * draw_scale, 5)
	draw_rect(bar.grow(1), Color("15252c"))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(trailing_health,0,1),5)),Color("d5be91"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(hp, 0, 1), 5)), color)
	var shield := float(state.get("shield", 0.0)) / maxf(1.0, float(state.get("maxhp", 1.0)))
	if shield > 0:
		draw_rect(Rect2(bar.position + Vector2(0, 6), Vector2(bar.size.x * minf(shield, 1), 2)), Color("a9dfeb"))
	var cooldown := float(state.get("cdMax",0))
	if cooldown>0 and not state.get("summon",false):
		var ready := clampf(1-float(state.get("cd",cooldown))/cooldown,0,1)
		draw_rect(Rect2(bar.position+Vector2(0,9),Vector2(bar.size.x,2)),Color("162731"))
		draw_rect(Rect2(bar.position+Vector2(0,9),Vector2(bar.size.x*ready,2)),ArtLibrary.faction_color(str(state.get("faction","math"))))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-15 * draw_scale, -54 * draw_scale), "★".repeat(star), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("efd18b"))
	if upgrade_age < 0.85:
		var color_fx := ArtLibrary.faction_color(str(state.get("faction","math")))
		for i in 3:
			var radius := (22+upgrade_age*65+i*7)*draw_scale
			draw_arc(Vector2.ZERO,radius,0,TAU,48,Color(color_fx,(1-upgrade_age/0.85)*0.6),1.5,true)
	var tags: Array[String] = []
	var translations := {"stun":"眩晕","root":"禁足","silence":"沉默","slow":"减速","acid":"酸","charge":"电","heat":"热"}
	for key in state.get("buffs",[]):
		if translations.has(key):
			tags.append(translations[key])
	for key in state.get("marks",[]):
		if translations.has(key):
			tags.append(translations[key])
	if int(state.get("evidence",0))>0:
		tags.append("证据%d" % int(state.evidence))
	if not tags.is_empty():
		var label_text := " · ".join(tags)
		var f: Font = name_label.get_theme_font("font")
		draw_string_outline(f,Vector2(-25,-36*draw_scale),label_text,HORIZONTAL_ALIGNMENT_LEFT,-1,9,3,Color("08141d"))
		draw_string(f,Vector2(-25,-36*draw_scale),label_text,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("f1d18e"))
