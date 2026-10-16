class_name WorldArena
extends SubViewportContainer

var scene_view := SubViewport.new()
var world := Node3D.new()
var camera := Camera3D.new()
var actors: Dictionary = {}
var tiles: Array[MeshInstance3D] = []
var bench_units: Array = []
var highlights := Node3D.new()
var marker: MeshInstance3D
var world_time := 0.0
var bubbles: Array[Node3D] = []
var board: Control
var yaw := 0.0
var zoom_size := 8.8
var scenery: MeshInstance3D
var showpiece: Node3D
var bench_root := Node3D.new()
var field_view: SubViewport
var field_surface: MeshInstance3D
var surface_texture: NoiseTexture2D
var surface_normal: NoiseTexture2D
var material_cache: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_view.size = Vector2i(1000,700)
	scene_view.own_world_3d = true
	scene_view.msaa_3d = Viewport.MSAA_2X
	scene_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(scene_view)
	scene_view.add_child(world)
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zoom_size
	camera.near = 0.1
	camera.far = 100
	camera.current = true
	_set_camera()
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("101c34")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("9cb6d4")
	sky.ambient_light_energy = 0.72
	sky.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = sky
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54,-35,0)
	sun.light_color = Color("ffe4bc")
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	world.add_child(sun)
	var noise:=FastNoiseLite.new()
	noise.frequency=0.018
	noise.fractal_octaves=4
	surface_texture=NoiseTexture2D.new()
	surface_texture.width=256
	surface_texture.height=256
	surface_texture.noise=noise
	surface_texture.seamless=true
	var ramp:=Gradient.new()
	ramp.colors=PackedColorArray([Color("c0c9ce"),Color("e1e5e3")])
	surface_texture.color_ramp=ramp
	surface_normal=NoiseTexture2D.new()
	surface_normal.width=256
	surface_normal.height=256
	surface_normal.noise=noise
	surface_normal.seamless=true
	surface_normal.as_normal_map=true
	surface_normal.bump_strength=2.5
	_build_courtyard()
	resized.connect(_resize_view)
	_resize_view()

func material(color: Color, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var key:=str(color)+str(metallic)+str(glow)
	if material_cache.has(key):return material_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.88 if metallic<0.2 else 0.48
	if color.a>0.99 and glow==0 and metallic<0.4 and surface_texture!=null:
		mat.albedo_texture=surface_texture
		mat.normal_enabled=true
		mat.normal_texture=surface_normal
		mat.normal_scale=0.035
	if color.a<0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow>0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	material_cache[key]=mat
	return mat

func mesh_node(mesh: Mesh, position_value: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = position_value
	(world if parent==null else parent).add_child(node)
	return node

func box(at: Vector3, extent: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = extent
	return mesh_node(shape,at,mat,parent)

func cylinder(at: Vector3, radius: float, height: float, mat: Material, parent: Node3D = null, top: float = -1) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius if top<0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 24
	return mesh_node(shape,at,mat,parent)

func sphere(at: Vector3, radius: float, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius*2
	shape.radial_segments = 24
	shape.rings = 12
	return mesh_node(shape,at,mat,parent)

func rod(a: Vector3, b: Vector3, radius: float, mat: Material, parent: Node3D = null) -> void:
	var node := cylinder((a+b)*0.5,radius,a.distance_to(b),mat,parent)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func sign_text(text: String, at: Vector3, parent: Node3D = null, color: Color = Color("efdbad")) -> void:
	var sign := Label3D.new()
	var font := SystemFont.new()
	font.font_names = ["Microsoft YaHei UI","Microsoft YaHei"]
	sign.font = font
	sign.text = text
	sign.font_size = 30
	sign.pixel_size = 0.006
	sign.modulate = color
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = at
	sign.outline_size = 6
	(world if parent==null else parent).add_child(sign)

func _build_courtyard() -> void:
	var dark_stone := material(Color("24384a"))
	var stone := material(Color("58737c"))
	var brass := material(Color("b39258"),0.65)
	var wood := material(Color("483a36"))
	var cream := material(Color("c4b798"))
	var cyan := material(Color("6ccfd0"),0.3,0.45)
	var indigo := material(Color("334967"),0.25)
	_build_scenery()
	if FileAccess.file_exists("res://assets/models/academic-orrery.glb"):
		showpiece=load("res://scripts/scenery_model.gd").new()
		showpiece.position=Vector3(-4.15,-0.12,2.0)
		showpiece.rotation_degrees.y=22
		world.add_child(showpiece)
	box(Vector3(0,-0.13,0),Vector3(6.28,0.20,8.28),wood)
	box(Vector3(0,-0.23,0),Vector3(6.44,0.10,8.44),brass)
	for r in 8:
		for c in 6:
			var color := Color("344957") if (r+c)%2==0 else Color("304451")
			if r>=5:
				color=Color("365d62") if (r+c)%2==0 else Color("32575c")
			elif r<=2:
				color=Color("455269") if (r+c)%2==0 else Color("404c62")
			var slab:=CylinderMesh.new()
			slab.radial_segments=4
			slab.top_radius=0.692
			slab.bottom_radius=0.703
			slab.height=0.12
			var tile:=mesh_node(slab,Vector3(c-2.5,0.12,r-3.5),material(color))
			tile.rotation.y=PI*0.25
			tiles.append(tile)
	for x in [-3.08,3.08]:
		box(Vector3(x,0.19,0),Vector3(0.045,0.08,8.28),brass)
	for z in [-4.08,4.08]:
		box(Vector3(0,0.19,z),Vector3(6.20,0.08,0.045),brass)
	# A quiet seam marks the deployment limit without a glowing UI border.
	box(Vector3(0,0.187,1.5),Vector3(6.0,0.008,0.018),material(Color("73a2a0"),0.25))
	world.add_child(bench_root)
	box(Vector3(0,-0.08,5.42),Vector3(7.4,0.22,1.0),dark_stone,bench_root)
	box(Vector3(0,0.045,5.92),Vector3(7.4,0.04,0.035),brass,bench_root)
	for index in 9:
		cylinder(Vector3((index-4)*0.78,0.17,5.35),0.32,0.24,stone,bench_root)
		cylinder(Vector3((index-4)*0.78,0.30,5.35),0.30,0.035,material(Color("304951")),bench_root)
		var rim:=TorusMesh.new()
		rim.inner_radius=0.30
		rim.outer_radius=0.32
		rim.rings=32
		rim.ring_segments=6
		mesh_node(rim,Vector3((index-4)*0.78,0.32,5.35),brass,bench_root)
		sign_text(str(index+1),Vector3((index-4)*0.78,0.38,5.76),bench_root,Color("ddc68c"))
	sign_text("备 战 席",Vector3(0,-0.05,6.2),bench_root)
	# Only the board and bench are mesh geometry. The painted environment is
	# deliberately registered to the fixed gameplay camera, not an orbit backdrop.
	world.add_child(highlights)
	marker=box(Vector3.ZERO,Vector3(0.95,0.025,0.95),material(Color(0.86,0.93,0.53,0.45),0,0.5),highlights)
	marker.visible=false

func _build_scenery() -> void:
	var quad := QuadMesh.new()
	quad.size=Vector2(16,10.67)
	var mat := StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture=ArtLibrary.texture_at("res://assets/arena-carnival-v2.png")
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	scenery=mesh_node(quad,Vector3.ZERO,mat)
	scenery.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_register_scenery()

func _register_scenery() -> void:
	if scenery==null:return
	# Stable camera-space registration across window sizes. Zoom scales both art and board.
	var aspect:=maxf(1.0,size.x/maxf(1.0,size.y))
	var height:=maxf(8.8,8.8*aspect/1.5)
	scenery.mesh.size=Vector2(height*1.5,height)
	scenery.basis=camera.basis
	scenery.position=Vector3(0,0,0.5)-camera.basis.z*18

func _resize_view() -> void:
	_set_camera()
	_register_scenery()

func _set_camera() -> void:
	var angle := deg_to_rad(yaw)
	camera.position=Vector3(sin(angle)*18,13,cos(angle)*18)
	camera.look_at(Vector3(0,0,0.5))
	camera.size=zoom_size

func project(c: float, r: float, height: float = 0.18) -> Vector2:
	return camera.unproject_position(Vector3(c-2.5,height,r-3.5))

func world_hit(point: Vector2, height: float = 0.18) -> Variant:
	return Plane(Vector3.UP,height).intersects_ray(camera.project_ray_origin(point),camera.project_ray_normal(point))

func cell_at(point: Vector2) -> Vector2i:
	var hit = world_hit(point)
	if hit == null:return Vector2i(-99,-99)
	return Vector2i(floori(hit.x+3),floori(hit.z+4))

func bench_at(point: Vector2) -> int:
	var hit = world_hit(point,0.32)
	if hit == null or hit.z<4.86 or hit.z>5.86 or hit.x< -3.51 or hit.x>=3.51:return -1
	return floori(hit.x/0.78+4.5)

func bench_screen(index: int) -> Vector2:
	return camera.unproject_position(Vector3((index-4)*0.78,0.32,5.35))

func bounds() -> Rect2:
	var points := [project(-0.5,-0.5),project(5.5,-0.5),project(5.5,7.5),project(-0.5,7.5)]
	var rect := Rect2(points[0],Vector2.ZERO)
	for p in points:rect=rect.expand(p)
	return rect

func pick_actor(point: Vector2, owned_only: bool = false) -> Dictionary:
	var origin := camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(point)*100,2)
	var space := world.get_world_3d()
	if space==null:return {}
	var hit := space.direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var uid: String = str(hit.collider.get_meta("uid",""))
		if actors.has(uid):
			var center:Vector3=actors[uid].global_position
			if Vector2(hit.position.x-center.x,hit.position.z-center.z).length()>0.5:return {}
			var u: Dictionary = actors[uid].unit
			if u.get("alive",true) and (not owned_only or int(u.team)==0):return u
	return {}

func activate_scenery(point: Vector2) -> bool:
	if showpiece==null:return false
	var origin:=camera.project_ray_origin(point)
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(point)*100,4)
	if world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():return false
	showpiece.activate()
	return true

func update_units(snapshot: Dictionary) -> void:
	var live := {}
	bench_units=snapshot.get("ownUnits",[]).filter(func(u):return u.c==null) if snapshot.get("watching")=="you" else []
	bench_root.visible=snapshot.get("phase")=="prepare" and snapshot.get("watching")=="you"
	var list: Array = snapshot.get("board",{}).get("units",[]).duplicate(true)
	if bench_root.visible:
		for i in bench_units.size():
			var u:Dictionary=bench_units[i].duplicate(true)
			u.merge({"bench":true,"benchIndex":i,"x":0.0,"y":0.0,"team":0,"alive":true,"hp":1,"maxhp":1,"faction":ArtLibrary.character(int(u.id)).faction},true)
			list.append(u)
	for u in list:
		var uid:=str(u.uid)
		live[uid]=true
		if not actors.has(uid):
			var actor: Node3D = load("res://scripts/world_actor.gd").new()
			actor.arena=self
			world.add_child(actor)
			actors[uid]=actor
		var location := Vector3(float(u.x)-2.5,0.18,float(u.y)-3.5)
		if u.get("bench",false):location=Vector3((int(u.benchIndex)-4)*0.78,0.32,5.35)
		actors[uid].update_unit(u,location)
	for uid in actors.keys():
		if not live.has(uid):actors[uid].queue_free();actors.erase(uid)

func highlight(point: Vector2, enabled: bool) -> void:
	marker.visible=false
	if not enabled:return
	var cell:=cell_at(point)
	var index:=bench_at(point)
	if index>=0:
		marker.position=Vector3((index-4)*0.78,0.35,5.35)
		marker.visible=true
	elif cell.x>=0 and cell.x<6 and cell.y>=5 and cell.y<8:
		marker.position=Vector3(cell.x-2.5,0.205,cell.y-3.5)
		marker.visible=true

func attach_fields(source: Node2D) -> void:
	field_view=SubViewport.new()
	field_view.size=Vector2i(768,1024)
	field_view.transparent_bg=true
	field_view.disable_3d=true
	field_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	world.add_child(field_view)
	var canvas: Node2D = load("res://scripts/world_field_canvas.gd").new()
	canvas.source=source
	field_view.add_child(canvas)
	var plane:=PlaneMesh.new()
	plane.size=Vector2(6,8)
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://shaders/world_field.gdshader")
	mat.set_shader_parameter("field_texture",field_view.get_texture())
	field_surface=mesh_node(plane,Vector3(0,0.205,0),mat)
	field_surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	world_time+=delta
	for i in bubbles.size():
		bubbles[i].rotation.y += delta*(0.15 if i==0 else 0.3)
