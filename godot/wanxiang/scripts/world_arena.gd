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
var architecture:=Node3D.new()
var deployment_marks:=Node3D.new()
var showpiece: Node3D
var bench_root := Node3D.new()
var field_view: SubViewport
var field_surface: MeshInstance3D
var surface_texture: NoiseTexture2D
var surface_normal: NoiseTexture2D
var material_cache: Dictionary = {}
var world_effects: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_view.size = Vector2i(1000,700)
	scene_view.own_world_3d = true
	scene_view.msaa_3d = Viewport.MSAA_4X
	scene_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(scene_view)
	scene_view.add_child(world)
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov=30.0
	camera.size = zoom_size
	camera.near = 0.1
	camera.far = 100
	camera.current = true
	_set_camera()
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("101c34")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var studio_sky:=Sky.new()
	var atmosphere:=ProceduralSkyMaterial.new()
	atmosphere.sky_top_color=Color("7196b5")
	atmosphere.sky_horizon_color=Color("c8d1d1")
	atmosphere.ground_bottom_color=Color("273d54")
	atmosphere.ground_horizon_color=Color("a2b3bc")
	studio_sky.sky_material=atmosphere
	sky.sky=studio_sky
	sky.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	sky.ambient_light_color = Color("9cb6d4")
	sky.ambient_light_energy = 0.45
	sky.tonemap_mode = Environment.TONE_MAPPER_LINEAR if RenderingServer.get_current_rendering_method()=="gl_compatibility" else Environment.TONE_MAPPER_ACES
	sky.ssao_enabled=true
	sky.ssao_radius=.65
	sky.ssao_intensity=1.5
	sky.glow_enabled=true
	sky.glow_intensity=.25
	sky.glow_bloom=.03
	environment.environment = sky
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58,-28,0)
	sun.light_color = Color("ffe4bc")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill:=DirectionalLight3D.new()
	fill.rotation_degrees=Vector3(-25,145,0)
	fill.light_color=Color("9bc9e1")
	fill.light_energy=.18
	world.add_child(fill)
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

func _stone(tint: Color) -> ShaderMaterial:
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://shaders/courtyard_stone.gdshader")
	mat.set_shader_parameter("stone_texture",ArtLibrary.texture_at("res://assets/courtyard-slate-v1.png"))
	mat.set_shader_parameter("stone_tint",tint)
	return mat

func _build_courtyard() -> void:
	var stone:=_stone(Color("425564"))
	var paving:=_stone(Color("63798a"))
	paving.set_shader_parameter("battle_tile",true)
	paving.set_shader_parameter("tile_texture",ArtLibrary.texture_at("res://assets/academy-slab-v2.png"))
	var alternate:=_stone(Color("6c8291"))
	alternate.set_shader_parameter("battle_tile",true)
	alternate.set_shader_parameter("tile_texture",ArtLibrary.texture_at("res://assets/academy-slab-v2.png"))
	var coping:=_stone(Color("c9c1a7"))
	var brass:=material(Color("9c8255"),0.35)
	# One physical courtyard: battle tiles and surrounding walks meet at the
	# same elevation and sample the same world-space stone material.
	box(Vector3(0,-0.29,0.5),Vector3(12.8,0.90,13.2),stone)
	for r in 8:
		for c in 6:
			var tile:=box(Vector3(c-2.5,0.17,r-3.5),Vector3(0.982,0.02,0.982),paving if (r+c)%2==0 else alternate)
			tiles.append(tile)
			var tile_top:=PlaneMesh.new()
			tile_top.size=Vector2(.974,.974)
			mesh_node(tile_top,Vector3(c-2.5,.183,r-3.5),paving if (r+c)%2==0 else alternate)
	# The low perimeter belongs to the island, not to a framed board panel.
	for side in [-1,1]:
		for z in range(-6,7):
			box(Vector3(side*6.25,0.22,z+0.5),Vector3(0.34,0.30,0.97),coping)
	for x in range(-6,7):
		box(Vector3(x,0.28,-6.32),Vector3(0.97,0.34,0.36),coping)
	for step in 3:
		box(Vector3(0,-0.05-step*0.15,7.18+step*0.25),Vector3(6.3+step*0.55,0.20,0.55),stone)
	var water_plane:=PlaneMesh.new()
	water_plane.size=Vector2(180,180)
	var water_mat:=ShaderMaterial.new()
	water_mat.shader=preload("res://shaders/courtyard_water.gdshader")
	mesh_node(water_plane,Vector3(0,-0.82,0),water_mat)
	world.add_child(architecture)
	_add_building("observatory",Vector3(-4.9,0.17,-3.0),2.65,8)
	_add_building("storybook-pavilion",Vector3(4.9,0.17,-3.25),2.65,-8)
	_add_building("academy-ginkgo",Vector3(-4.7,.18,2.6),1.9,25)
	_add_building("academy-ginkgo",Vector3(4.7,.18,1.9),2.0,-20)
	var court_ring:=TorusMesh.new()
	court_ring.inner_radius=4.66
	court_ring.outer_radius=4.68
	court_ring.rings=128
	court_ring.ring_segments=6
	mesh_node(court_ring,Vector3(0,0.16,0),brass)
	if FileAccess.file_exists("res://assets/models/academic-orrery.glb"):
		showpiece=load("res://scripts/scenery_model.gd").new()
		showpiece.position=Vector3(-4.8,0.18,-.25)
		showpiece.scale=Vector3.ONE*.72
		showpiece.rotation_degrees.y=22
		world.add_child(showpiece)
	# Bench sockets are embedded in the same courtyard apron.
	world.add_child(bench_root)
	for index in 9:
		cylinder(Vector3((index-4)*0.78,0.23,5.35),0.33,0.18,coping,bench_root)
		var rim:=TorusMesh.new()
		rim.inner_radius=0.30
		rim.outer_radius=0.32
		rim.rings=32
		rim.ring_segments=6
		mesh_node(rim,Vector3((index-4)*0.78,0.32,5.35),brass,bench_root)
		sign_text(str(index+1),Vector3((index-4)*0.78,0.22,5.78),bench_root,Color("ddc68c"))
	world.add_child(deployment_marks)
	for row in range(5,9):
		for col in range(7):
			cylinder(Vector3(col-3,0.19,row-4),0.025,0.012,brass,deployment_marks)
	var inlay:=material(Color("9caa95"),0.15)
	for row in range(5,8):
		for col in 6:
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
				var at:=Vector3(col-2.5+corner.x*0.42,0.188,row-3.5+corner.y*0.42)
				box(at-Vector3(corner.x*0.045,0,0),Vector3(0.12,0.006,0.016),inlay,deployment_marks)
				box(at-Vector3(0,0,corner.y*0.045),Vector3(0.016,0.006,0.12),inlay,deployment_marks)
	for at in [Vector3(-5.6,0.18,4.8),Vector3(5.6,0.18,4.8),Vector3(-2.6,0.18,-5.6),Vector3(2.6,0.18,-5.6)]:
		_light_post(at,brass,coping)
	world.add_child(highlights)
	marker=box(Vector3.ZERO,Vector3(0.96,0.012,0.96),material(Color(0.68,0.84,0.56,0.32),0,0.15),highlights)
	marker.visible=false

func _add_building(asset: String, at: Vector3, width: float, rotation: float) -> void:
	if not FileAccess.file_exists("res://assets/models/"+asset+".glb"):return
	var building:Node3D=load("res://scripts/architecture_model.gd").new()
	building.asset=asset
	building.footprint_width=width
	building.position=at
	building.rotation_degrees.y=rotation
	architecture.add_child(building)

func _light_post(at: Vector3, brass:Material, stone:Material) -> void:
	cylinder(at+Vector3(0,0.24,0),0.17,0.48,stone)
	cylinder(at+Vector3(0,0.80,0),0.035,0.85,brass)
	var glass:=material(Color("f5c37d"),0,0.7)
	cylinder(at+Vector3(0,1.28,0),0.12,0.30,glass)
	cylinder(at+Vector3(0,1.47,0),0.18,0.13,brass,null,0.02)
	var light:=OmniLight3D.new()
	light.position=at+Vector3(0,1.25,0)
	light.light_color=Color("ffd09a")
	light.light_energy=0.6
	light.omni_range=3.0
	world.add_child(light)
	light.shadow_enabled=false

func _resize_view() -> void:
	_set_camera()

func _set_camera() -> void:
	var angle:=deg_to_rad(yaw)
	var distance_scale:=zoom_size/8.8*(1.0+absf(yaw)/14.0*0.10)
	camera.position=Vector3(sin(angle)*13.5,10.4,cos(angle)*13.5)*distance_scale
	camera.look_at(Vector3(0,0,0.5))
	camera.fov=30.0

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
	deployment_marks.visible=bench_root.visible
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
	world_effects=load("res://scripts/world_effects.gd").new()
	world_effects.arena=self
	world_effects.source=source
	world.add_child(world_effects)
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
