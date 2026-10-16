extends Node3D

var arena: WorldArena
var source: Node2D
var live: Dictionary = {}
var templates: Dictionary = {}
var context := ""

func _ready() -> void:
	for name in ["magnet-car","verdict-gavel"]:
		var path:String="res://assets/models/"+name+".glb"
		if not FileAccess.file_exists(path):continue
		var doc:=GLTFDocument.new()
		var state:=GLTFState.new()
		if doc.append_from_file(path,state)!=OK:continue
		var model:=doc.generate_scene(state)
		var helper:Node3D=load("res://scripts/scenery_model.gd").new()
		helper._soften_materials(model)
		var bounds:AABB=helper._bounds(model,Transform3D.IDENTITY)
		var extent:=maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
		var factor:float=(1.30 if name=="magnet-car" else 1.85)/maxf(extent,0.001)
		model.scale=Vector3.ONE*factor
		model.position=-bounds.get_center()*factor
		var root:=Node3D.new()
		root.add_child(model)
		_own(model,root)
		var packed:=PackedScene.new()
		if packed.pack(root)==OK:templates[name]=packed
		root.free()
		helper.free()

func _own(node:Node, owner_node:Node) -> void:
	node.owner=owner_node
	for child in node.get_children():_own(child,owner_node)

func handles(e:Dictionary) -> bool:
	if e.type=="gag_magnet":return templates.has("magnet-car")
	if e.type=="gag_gavel":return templates.has("verdict-gavel")
	if e.type=="gag_land":
		return (e.get("prop")=="car" and templates.has("magnet-car")) or (e.get("prop")=="gavel" and templates.has("verdict-gavel"))
	return e.type in ["contact","impact","burst","nova"]

func _paint(color:Color, alpha:float=1.0) -> StandardMaterial3D:
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color(color,alpha)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	return mat

func _mesh(parent:Node3D, mesh:Mesh, color:Color) -> MeshInstance3D:
	var n:=MeshInstance3D.new()
	n.mesh=mesh
	n.material_override=_paint(color)
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n

func _spawn(e:Dictionary) -> Node3D:
	var n:=Node3D.new()
	add_child(n)
	var color:=ArtLibrary.faction_color(str(e.get("faction","math")))
	if str(e.type).begins_with("gag_"):
		var key:="magnet-car" if e.type=="gag_magnet" or e.get("prop")=="car" else "verdict-gavel"
		var prop:Node3D=templates[key].instantiate()
		prop.name="Prop"
		n.add_child(prop)
		if e.type=="gag_magnet":
			var flux:=MeshInstance3D.new()
			flux.name="Flux"
			flux.mesh=ImmediateMesh.new()
			flux.material_override=_paint(Color("8bd8ec"),0.65)
			flux.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flux.top_level=true
			n.add_child(flux)
	if e.type not in ["gag_magnet","gag_gavel"]:
		var ring:=TorusMesh.new()
		ring.inner_radius=0.48
		ring.outer_radius=0.51
		ring.rings=48
		ring.ring_segments=6
		var mesh:=_mesh(n,ring,color)
		mesh.name="Wave"
		var pieces:=Node3D.new()
		pieces.name="Fragments"
		n.add_child(pieces)
		var school:=str(e.get("faction","math"))
		for i in (6 if e.type=="contact" else 14):
			var shape:Mesh
			if school=="chemistry":
				var orb:=SphereMesh.new()
				orb.radius=0.035
				orb.height=0.07
				orb.radial_segments=8
				orb.rings=4
				shape=orb
			elif school=="math":
				var prism:=PrismMesh.new()
				prism.size=Vector3(0.06,0.10,0.06)
				shape=prism
			elif school=="law":
				var seal:=CylinderMesh.new()
				seal.top_radius=0.045
				seal.bottom_radius=0.045
				seal.height=0.025
				seal.radial_segments=6
				shape=seal
			else:
				var box:=BoxMesh.new()
				box.size=Vector3(0.075,0.006,0.11) if school=="literature" else Vector3(0.10,0.045,0.065) if school=="history" else Vector3(0.035,0.08,0.035)
				shape=box
			_mesh(pieces,shape,Color("e8ddba") if school=="literature" else color.lightened(0.25))
	return n

func _point(x:float,y:float) -> Vector3:
	return Vector3(x-2.5,0.18,y-3.5)

func _target(e:Dictionary) -> Vector3:
	var uid:=str(e.get("targetUid",""))
	if arena.actors.has(uid):return arena.actors[uid].global_position
	return _point(float(e.x2),float(e.y2))

func _process(_delta:float) -> void:
	if source==null:return
	if context!=source.context_key:
		for node in live.values():node.queue_free()
		live.clear()
		context=source.context_key
	var present:Dictionary={}
	var shake:=0.0
	for e in source.active:
		if not handles(e):continue
		var id:=int(e.id)
		var age:=maxf(0,source.clock-float(e.born))
		var t:=clampf(age/maxf(0.01,float(e.life)),0,1)
		present[id]=true
		if not live.has(id):live[id]=_spawn(e)
		var node:Node3D=live[id]
		var a:=_point(float(e.x),float(e.y))
		var b:=_target(e)
		if e.type=="gag_magnet":
			node.position=(a+Vector3(-0.45,0.65,0)).lerp(b+Vector3(0,0.45,0),t)
			node.position.y+=sin(t*PI)*1.75
			node.rotation=Vector3(sin(t*PI)*-0.35,atan2(b.x-a.x,b.z-a.z)+PI*0.5,sin(t*PI*2)*0.25)
			var start:=a+Vector3(0,0.65,0)
			var caster_uid:=str(e.get("sourceUid",""))
			if arena.actors.has(caster_uid):start=arena.actors[caster_uid].global_position+Vector3(0,0.65,0)
			var flux:MeshInstance3D=node.get_node("Flux")
			var geometry:ImmediateMesh=flux.mesh
			geometry.clear_surfaces()
			for side in [-1,1]:
				geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
				for j in 21:
					var k:=float(j)/20
					var point:=start.lerp(node.position,k)+Vector3(side*sin(k*PI)*0.18,sin(k*PI*3+age*18)*0.04,0)
					var edge:=arena.camera.global_basis.x*0.012
					geometry.surface_add_vertex(point-edge)
					geometry.surface_add_vertex(point+edge)
				geometry.surface_end()
		elif e.type=="gag_gavel":
			node.position=b+Vector3(-0.2,0.85+1.65*(1-t*t),0)
			node.rotation=Vector3(0,0.25,lerpf(PI-0.65,PI,t*t))
		else:
			node.position=a
			var land:bool=e.type=="gag_land"
			var big:bool=land or e.type in ["impact","burst","nova"]
			var radius:float=(0.60 if land else 1.15 if big else 0.38)*minf(2.0,float(e.get("r",1)))
			var wave:MeshInstance3D=node.get_node("Wave")
			wave.visible=e.type!="contact" or e.get("skill",false)
			wave.position.y=0.04
			wave.scale=Vector3.ONE*maxf(0.04,radius*(0.15+1.8*t))
			wave.material_override.albedo_color.a=pow(1-t,2)*(0.8 if big else 0.45)
			var pieces:Node3D=node.get_node("Fragments")
			for i in pieces.get_child_count():
				var p:MeshInstance3D=pieces.get_child(i)
				var angle:=i*2.399+id*0.71
				var distance_value:=radius*(0.3+fmod(i*0.27,0.7))*t
				p.position=Vector3(cos(angle)*distance_value,0.15+sin(t*PI)*(0.25+fmod(i*0.17,0.6)),sin(angle)*distance_value)
				p.rotation=Vector3(t*4+i,t*5+i*0.4,t*3)
				p.material_override.albedo_color.a=pow(1-t,1.5)
			if land:
				var prop:Node3D=node.get_node("Prop")
				var car:bool=e.get("prop")=="car"
				prop.position=Vector3(0,0.45 if car else 0.85,0)
				prop.position.y+=sin(t*PI)*exp(-t*6)*0.35
				prop.rotation=Vector3(0,PI*0.5,0 if car else PI)
				prop.scale=Vector3.ONE*(1-smoothstep(0.55,1.0,t))
				shake=maxf(shake,0.045*exp(-age*18))
	for id in live.keys():
		if not present.has(id):live[id].queue_free();live.erase(id)
	arena.camera.h_offset=sin(source.clock*83)*shake
	arena.camera.v_offset=cos(source.clock*71)*shake*0.55
