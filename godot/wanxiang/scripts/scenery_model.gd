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
	var bounds:=_bounds(model,Transform3D.IDENTITY)
	var factor:=1.85/maxf(bounds.size.y,0.001)
	model.scale=Vector3.ONE*factor
	model.position=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*factor
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
		sphere.radius=0.024
		sphere.height=0.048
		var mat:=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color=Color("c6e8d2") if i%2==0 else Color("f4ce83")
		spark.mesh=sphere
		spark.material_override=mat
		spark.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		sparks.append(spark)

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
		sparks[i].scale=Vector3.ONE*(1.9 if pulse>0 else 0.6)
