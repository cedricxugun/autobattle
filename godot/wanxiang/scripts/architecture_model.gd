extends "res://scripts/scenery_model.gd"

var asset := "observatory"
var footprint_width := 3.4

func _ready() -> void:
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	var result:=document.append_from_file("res://assets/models/"+asset+".glb",state)
	if result!=OK:
		push_error("Building GLB failed: "+asset)
		return
	model=document.generate_scene(state)
	add_child(model)
	_soften_materials(model)
	var bounds:=_bounds(model,Transform3D.IDENTITY)
	var factor:=footprint_width/maxf(bounds.size.x,bounds.size.z)
	model.scale=Vector3.ONE*factor
	model.position=Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z)*factor
