extends Node3D
var arena:WorldArena
var pieces:Array[MeshInstance3D]=[]
var code:=8
var kind:=""
var radius:=2.6
var tint:=Color.WHITE
var page_texture:ViewportTexture

func mesh(shape:Mesh,at:Vector3,color:Color) -> MeshInstance3D:
	var m:=MeshInstance3D.new()
	m.mesh=shape
	m.position=at
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color(color,0.8)
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	m.material_override=mat
	m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	pieces.append(m)
	return m

func make_page() -> void:
	var page:=SubViewport.new()
	page.size=Vector2i(192,256)
	page.transparent_bg=false
	page.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(page)
	var paper:=ColorRect.new()
	paper.color=Color("f3e6bf");paper.size=Vector2(192,256)
	page.add_child(paper)
	var border:=ColorRect.new()
	border.color=Color("8b5b3b");border.position=Vector2(16,16);border.size=Vector2(160,3)
	page.add_child(border)
	var writing:=Label.new()
	writing.text="万卷大结局\n\n第一幕 · 相遇\n第二幕 · 误会\n第三幕 · 重逢\n\n全剧终"
	writing.position=Vector2(22,30)
	writing.add_theme_font_size_override("font_size",18)
	writing.add_theme_color_override("font_color",Color("493627"))
	page.add_child(writing)
	page_texture=page.get_texture()

func configure(e:Dictionary) -> void:
	code=int(e.get("legend",8));kind=str(e.type);radius=float(e.get("r",2.6))
	tint=ArtLibrary.faction_color(str(e.get("faction","math")))
	position=Vector3(float(e.x2)-2.5,0.21,float(e.y2)-3.5)
	var ring:=TorusMesh.new()
	ring.inner_radius=radius-0.035;ring.outer_radius=radius+0.035
	ring.rings=80;ring.ring_segments=6
	mesh(ring,Vector3.ZERO,tint)
	if kind=="legendary_charge":return
	if code==44:make_page()
	for i in 12:
		var angle:=i*TAU/12
		var shape:Mesh
		if code==8:
			var prism:=PrismMesh.new();prism.size=Vector3(.28,.65,.28);shape=prism
		elif code==17:
			var tick:=BoxMesh.new();tick.size=Vector3(.07,.24,.07);shape=tick
		elif code==26:
			var orb:=SphereMesh.new();orb.radius=.18;orb.height=.36;orb.radial_segments=12;orb.rings=6;shape=orb
		elif code==35:
			var arch:=BoxMesh.new();arch.size=Vector3(.10,.65,.10);shape=arch
		elif code==44:
			var page:=PlaneMesh.new();page.size=Vector2(.38,.54);shape=page
		else:
			var pillar:=CylinderMesh.new();pillar.top_radius=.06;pillar.bottom_radius=.10;pillar.height=.75;pillar.radial_segments=6;shape=pillar
		var piece:=mesh(shape,Vector3(cos(angle)*radius,.3,sin(angle)*radius),Color.WHITE if code==44 else tint)
		if code==44:piece.material_override.albedo_texture=page_texture
	if code==17:
		for i in 3:
			var orbit:=TorusMesh.new();orbit.inner_radius=1.15;orbit.outer_radius=1.19;orbit.rings=64;orbit.ring_segments=6
			var node:=mesh(orbit,Vector3(0,1.2,0),tint);node.rotation=Vector3(PI*.5,i*PI/3,0)
	if code==35:
		var gate:=TorusMesh.new();gate.inner_radius=1.05;gate.outer_radius=1.13;gate.rings=64;gate.ring_segments=8
		mesh(gate,Vector3(0,1.1,0),tint).rotation.x=PI*.5

func animate(age:float,life:float) -> void:
	var t:=clampf(age/maxf(.01,life),0,1)
	for i in pieces.size():
		var m:MeshInstance3D=pieces[i]
		m.material_override.albedo_color.a=(.2+.35*t) if kind=="legendary_charge" else minf(1,(1-t)*3)*(.8 if code==44 else .45)
		if i==0:
			m.scale=Vector3.ONE
		elif i<=12:
			var a:float=(i-1)*TAU/12
			if code==44:
				m.position=Vector3(cos(a+age)*radius*(1-t*.35),.25+(1-t)*1.6,sin(a+age)*radius*(1-t*.35))
				m.rotation=Vector3(age*3+i,age*2,i*.7)
			elif code==26:
				m.position=Vector3(cos(a)*radius*t,.2+sin(t*PI)*(.8+fmod(i*.31,1)),sin(a)*radius*t)
			else:
				m.position.y=.15+sin(t*PI)*(.25 if code in [35,53] else .4)
				m.rotation.y=age*(.4 if code==17 else 1.5)
