extends Node3D

var model: Node3D
var pulse := 0.0
var elapsed := 0.0
var sparks: Array[MeshInstance3D] = []

func _ready() -> void:
	# Runtime glTF loading keeps the portable game independent of editor import caches.
	var file := "res://assets/models/academic-orrery.glb"
	if not FileAccess.file_exists(file):return
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	var result:=document.append_from_file(file,state)
	if result!=OK:
		push_error("Could not load academic orrery: %s" % result)
		return
	model=document.generate_scene(state)
	add_child(model)
	_soften_materials(model)
	var bounds:=_bounds(model,Transform3D.IDENTITY)
	var factor:=1.85/maxf(bounds.size.y,0.001)
	model.scale=Vector3.ONE*factor
	model.position=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*factor
	var contact:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(1.45,1.35)
	contact.mesh=plane
	contact.position.y=0.015
	var shadow:=ShaderMaterial.new()
	shadow.shader=load("res://shaders/contact_shadow.gdshader")
	contact.material_override=shadow
	contact.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(contact)
	var collider:=StaticBody3D.new()
	collider.collision_layer=4
	collider.collision_mask=0
	add_child(collider)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(1.2,1.85,1.2)
	shape.shape=box
	shape.position.y=0.925
	collider.add_child(shape)
	for i in 8:
		var spark:=MeshInstance3D.new()
		var sphere:=SphereMesh.new()
		sphere.radius=0.010
		sphere.height=0.020
		var mat:=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color=Color("c6e8d2") if i%2==0 else Color("f4ce83")
		spark.mesh=sphere
		spark.material_override=mat
		spark.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		sparks.append(spark)

func _soften_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var original:Material=node.mesh.surface_get_material(index)
			if not original is StandardMaterial3D:continue
			var mat:StandardMaterial3D=original.duplicate()
			mat.roughness=0.86
			mat.metallic=0.12
			mat.metallic_specular=0.15
			mat.normal_enabled=false
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			for slot in [BaseMaterial3D.TEXTURE_ALBEDO,BaseMaterial3D.TEXTURE_METALLIC,BaseMaterial3D.TEXTURE_ROUGHNESS]:
				var texture:=mat.get_texture(slot)
				if texture==null:continue
				var pixels:=texture.get_image()
				if pixels!=null and not pixels.has_mipmaps():
					if pixels.is_compressed():pixels.decompress()
					pixels.generate_mipmaps()
					mat.set_texture(slot,ImageTexture.create_from_image(pixels))
			node.set_surface_override_material(index,mat)
	for child in node.get_children():_soften_materials(child)

func _bounds(node: Node, inherited: Transform3D) -> AABB:
	var current:=inherited
	if node is Node3D:current=inherited*node.transform
	var found:=false
	var result:=AABB()
	if node is MeshInstance3D and node.mesh!=null:
		result=current*node.mesh.get_aabb()
		found=true
	for child in node.get_children():
		var part:=_bounds(child,current)
		if part.size.length_squared()>0:
			result=result.merge(part) if found else part
			found=true
	return result

func activate() -> void:
	pulse=3.0

func _process(delta: float) -> void:
	elapsed+=delta*(2.4 if pulse>0 else 0.4)
	pulse=maxf(0,pulse-delta)
	for i in sparks.size():
		var angle:=elapsed+i*TAU/8
		sparks[i].position=Vector3(cos(angle)*0.76,1.25+sin(angle)*0.34,sin(angle)*0.48)
		sparks[i].scale=Vector3.ONE*(1.5 if pulse>0 else 0.6)
