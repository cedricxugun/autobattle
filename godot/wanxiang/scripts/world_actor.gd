extends Node3D

var arena: WorldArena
var unit: Dictionary = {}
var body := ChessPiece.new()
var picture := Sprite3D.new()
var accessory := Sprite3D.new()
var hidden_canvas := Node2D.new()
var target_position := Vector3.ZERO
var collision := StaticBody3D.new()
var initialized := false
var ring: MeshInstance3D
var contact_shadow: MeshInstance3D
var placement_age := 1.0
var hero:Node3D

func _ready() -> void:
	add_child(hidden_canvas)
	hidden_canvas.visible=false
	body.render_3d_body=true
	body.draw_scale=1.2
	hidden_canvas.add_child(body)
	picture.pixel_size=0.006
	picture.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	picture.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	picture.alpha_scissor_threshold=0.08
	picture.position.y=0.71
	picture.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(picture)
	accessory.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	accessory.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	accessory.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(accessory)
	add_child(collision)
	collision.collision_layer=2
	collision.collision_mask=0
	var shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=0.34
	capsule.height=1.5
	shape.shape=capsule
	shape.position.y=0.75
	collision.add_child(shape)
	var torus:=TorusMesh.new()
	torus.inner_radius=0.34
	torus.outer_radius=0.38
	torus.rings=32
	torus.ring_segments=8
	ring=arena.mesh_node(torus,Vector3(0,0.035,0),arena.material(Color("efd28d"),0.3,0.5),self)
	ring.visible=false
	var shadow_mesh:=PlaneMesh.new()
	shadow_mesh.size=Vector2(0.85,0.65)
	var shadow_mat:=ShaderMaterial.new()
	shadow_mat.shader=preload("res://shaders/contact_shadow.gdshader")
	contact_shadow=arena.mesh_node(shadow_mesh,Vector3(0,0.015,0),shadow_mat,self)
	contact_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_unit(value: Dictionary, destination: Vector3) -> void:
	var old := target_position
	unit=value
	if int(value.id)==51 and hero==null and FileAccess.file_exists("res://assets/models/verdict-colossus-v2.glb"):
		hero=load("res://scripts/hero_actor.gd").new()
		add_child(hero)
	target_position=destination
	if not initialized or arena.board.snapshot.get("phase")=="prepare":
		if initialized and old.distance_to(destination)>0.1:placement_age=0.0
		position=destination
		old=destination
		initialized=true
		force_update_transform()
		collision.force_update_transform()
	collision.set_meta("uid",str(value.uid))
	if hero!=null:
		var hit_shape:CollisionShape3D=collision.get_child(0)
		var height:float=1.8*(1+(int(value.star)-1)*.065)
		hit_shape.shape.height=height
		hit_shape.position.y=height*.5
	var shown := value.duplicate(true)
	var aim_world:=Vector3(float(value.get("aimX",value.x))-2.5,0.18,float(value.get("aimY",value.y))-3.5)
	var aim_screen:=arena.camera.unproject_position(aim_world)-arena.camera.unproject_position(destination)
	shown.screenAimX=aim_screen.x
	shown.screenAimY=aim_screen.y
	var movement:=arena.camera.unproject_position(destination)-arena.camera.unproject_position(old)
	shown.screenMoveX=movement.x
	shown.screenMoveY=movement.y
	body.update_unit(shown,Vector2(96,96))
	var bench:bool=value.get("bench",false)
	var cost:int=int(ArtLibrary.character(int(value.id)).cost)
	scale=Vector3.ONE*(0.86 if bench else 1.0)*(1.22 if cost==5 and not value.get("summon",false) else 1.08 if cost==4 else 1.0)
	ring.material_override=arena.material(ArtLibrary.quality_color(cost),0.25,0.30 if cost==5 else 0.05)
	collision.collision_layer=2 if value.get("alive",true) else 0

func _process(delta: float) -> void:
	if arena.board.effects_layer==null:return
	var active_combat:bool=arena.board.snapshot.get("phase")=="battle" and not arena.board.snapshot.get("board",{}).get("done",false)
	var bookbound:bool=active_combat and "bookbound" in unit.get("buffs",[])
	body.visual_clock=arena.board.effects_layer.clock
	body.time_scale=0 if arena.board.snapshot.get("paused",false) else float(arena.board.snapshot.get("speed",1))
	body.selected=str(unit.get("uid",""))==arena.board.selected_uid
	placement_age+=delta
	if body.time_scale>0:position=position.lerp(target_position,minf(1,delta*22))
	picture.visible=body.visible
	if body.sprite.sprite_frames!=null and body.animation_name!="":
		var texture:=body.sprite.sprite_frames.get_frame_texture(body.animation_name,body.sprite.frame)
		picture.texture=texture
		picture.pixel_size=1.42/maxf(texture.get_width(),texture.get_height())
		var base:=129.6/maxf(texture.get_width(),texture.get_height())
		picture.scale=Vector3(body.sprite.scale.x/base,body.sprite.scale.y/base,1)
		var settle:=maxf(0,1-placement_age/0.24)
		picture.position.y=0.71+sin(settle*PI)*0.22
		picture.scale*=Vector3(1+sin(settle*PI)*0.07,1-sin(settle*PI)*0.05,1)
		picture.rotation.z=-body.sprite.rotation
		picture.flip_h=body.sprite.flip_h
		picture.offset=Vector2(body.sprite.position.x,-body.sprite.position.y)*1.6
		var flash:float=body.actor_material.get_shader_parameter("flash")
		picture.modulate=Color(1+flash*0.55,1+flash*0.35,1+flash*0.25,body.modulate.a)
		collision.collision_layer=0 if body.dragging or not unit.get("alive",true) else 2
	contact_shadow.visible=unit.get("alive",true) and not body.dragging
	var lift:=maxf(0,picture.position.y-0.71)+maxf(0,-body.sprite.position.y-5)*0.011
	contact_shadow.scale=Vector3.ONE*(1.0+lift*0.5)
	contact_shadow.material_override.set_shader_parameter("opacity",clampf(0.48-lift*0.25,0.20,0.48))
	if bookbound:
		picture.texture=ArtLibrary.prop("book")
		picture.pixel_size=0.95/maxf(picture.texture.get_width(),picture.texture.get_height())
		picture.scale=Vector3.ONE
		picture.position.y=0.45
	accessory.visible=body.accessory.visible and body.accessory.texture!=null and body.visible
	if accessory.visible:
		accessory.texture=body.accessory.texture
		accessory.pixel_size=0.34/maxf(accessory.texture.get_width(),accessory.texture.get_height())
		accessory.position=Vector3(body.accessory.position.x/91.3,0.71-body.accessory.position.y/91.3,0.03)
		accessory.flip_h=body.accessory.flip_h
		accessory.modulate.a=body.modulate.a

	ring.visible=body.selected or body.upgrade_age<0.85 or (int(ArtLibrary.character(int(unit.get("id",0))).cost)>=4 and not unit.get("summon",false))
	if body.upgrade_age<0.85:
		ring.scale=Vector3.ONE*(1+body.upgrade_age)
	else:ring.scale=Vector3.ONE

	if hero!=null and hero.ready_model and bookbound:
		hero.visible=false
	elif hero!=null and hero.ready_model:
		picture.visible=false
		accessory.visible=false
		var shown:Dictionary=unit
		if not active_combat:
			shown=unit.duplicate()
			shown.merge({"moving":false,"casting":false,"attackWindupAt":-99,"skillWindupAt":-99,"hitAt":-99,"buffs":[]},true)
		hero.drive(shown,body.visual_clock,delta*float(arena.board.snapshot.get("speed",1)),bool(arena.board.snapshot.get("paused",false)),body.dragging,float(arena.board.snapshot.get("speed",1)))
