extends Node2D

var manager: Node2D
var surfaces: Dictionary = {}
var font := SystemFont.new()
var shader := preload("res://shaders/field.gdshader")

func _ready() -> void:
	font.font_names = ["Microsoft YaHei UI", "Microsoft YaHei"]

func _process(_delta: float) -> void:
	if manager == null:
		return
	var live := {}
	for zone in manager.data.get("zones", []):
		if float(zone.until) <= manager.clock or zone.type in ["triangle", "arc", "boundary", "court"]:
			continue
		var key := str(zone.id)
		live[key] = true
		if not surfaces.has(key):
			var node := ColorRect.new()
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var mat := ShaderMaterial.new()
			mat.shader = shader
			node.material = mat
			add_child(node)
			surfaces[key] = node
		var node: ColorRect = surfaces[key]
		var radius: float = float(zone.r) * manager.board.cell_size()
		var center: Vector2 = manager.board.projection(float(zone.x), float(zone.y))
		node.position = center - Vector2.ONE*radius
		node.size = Vector2.ONE*radius*2
		var mat: ShaderMaterial = node.material
		mat.set_shader_parameter("elapsed", manager.clock-float(zone.born))
		mat.set_shader_parameter("opacity", minf(1, (float(zone.until)-manager.clock)*3))
		mat.set_shader_parameter("tint", ArtLibrary.faction_color(str(zone.faction)))
		mat.set_shader_parameter("school", ["math","physics","chemistry","history","literature","law"].find(zone.faction))
	for key in surfaces.keys():
		if not live.has(key):
			surfaces[key].queue_free()
			surfaces.erase(key)

func line(points: PackedVector2Array, color: Color, alpha: float = 1.0, width: float = 1.5) -> void:
	if points.size() > 1:
		draw_polyline(points,Color(color,alpha*0.12),width*5,true)
		draw_polyline(points,Color(color,alpha),width,true)

func _draw() -> void:
	if manager == null:
		return
	var board: BattleBoard = manager.board
	var cell := board.cell_size()
	var focus := board.selected_uid
	if focus.is_empty():
		for u in manager.data.get("units",[]):
			if int(u.team)==0 and u.get("alive",true):
				focus = str(u.uid)
				break
	for z in manager.data.get("zones", []):
		var remaining: float = float(z.until)-manager.clock
		if remaining <= 0:
			continue
		var color := ArtLibrary.faction_color(str(z.faction))
		var alpha := minf(1,remaining*3)
		var emphasized: bool = str(z.get("sourceUid",""))==focus or manager.data.get("zones",[]).size()<=2
		if not emphasized:
			alpha *= 0.55
		var center := board.projection(float(z.x),float(z.y))
		var radius := float(z.r)*cell
		var caption := ""
		if z.type == "triangle":
			if z.vertices == null or z.vertices.size() != 3:
				continue
			var polygon := PackedVector2Array()
			for vertex in z.vertices:
				polygon.append(board.projection(float(vertex.x),float(vertex.y)))
			if absf((polygon[1]-polygon[0]).cross(polygon[2]-polygon[0])) > 1:
				draw_colored_polygon(polygon,Color(color,0.12*alpha))
			polygon.append(polygon[0])
			line(polygon,color,alpha,2)
			for i in 3:
				draw_circle(polygon[i],4,Color(color,alpha),true,-1,true)
			center=(polygon[0]+polygon[1]+polygon[2])/3
			caption="△ 区域减伤 20%"
		elif z.type == "arc":
			if z.ends != null and z.ends.size() == 2:
				var a := board.projection(z.ends[0].x,z.ends[0].y)
				var b := board.projection(z.ends[1].x,z.ends[1].y)
				var points:=PackedVector2Array()
				for i in 25:
					var t:=float(i)/24
					points.append(a.lerp(b,t)+(b-a).normalized().orthogonal()*sin(t*40+manager.clock*15)*3*sin(t*PI))
				line(points,color,alpha,2)
				center=(a+b)*0.5
				caption="电解 · 电极通路"
		elif z.type in ["court", "boundary"]:
			var points:=PackedVector2Array()
			for i in 49:
				points.append(center+Vector2.from_angle(TAU*i/48.0)*radius)
			line(points,color,alpha,2)
			for i in 8:
				var at:=center+Vector2.from_angle(i*TAU/8)*radius
				line(PackedVector2Array([at-Vector2(0,4),at-Vector2(0,17)]),color,alpha,2)
			caption="终审领域 · 敌方施法后裁决" if z.type == "court" else "边界 · 首次越界禁足"
		elif z.type == "vortex":
			caption="引力井 · 向心牵引"
			draw_arc(center,radius,0,TAU,80,Color(color,alpha*0.55),1.0,true)
			for i in 8:
				var angle: float =i*TAU/8+manager.clock*0.18
				var r:=radius*(1-fmod(manager.clock*0.4+i*0.12,0.8))
				var direction:=Vector2.from_angle(angle)
				var at:=center+direction*r
				line(PackedVector2Array([at+direction.rotated(0.5)*7,at,at+direction.rotated(-0.5)*7]),color,alpha*0.65,1)
		elif z.type in ["acid","reactor"]:
			caption="反应堆 · 百分比伤害与连锁反应" if z.type=="reactor" else "酸蚀区域 · 持续伤害"
			draw_arc(center,radius,0,TAU,80,Color(color,alpha*0.55),1.0,true)
			for i in 12:
				var angle: float =i*2.399
				var at:=center+Vector2.from_angle(angle)*radius*sqrt(float(i)/12)*0.8
				var pulse:=fmod(manager.clock*0.8+i*0.17,1)
				draw_arc(at,2+pulse*5,0,TAU,16,Color(color,(1-pulse)*alpha*0.6),1,true)
		if not caption.is_empty() and emphasized:
			draw_string_outline(font,center+Vector2(-40,15),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10,3,Color("0b1720",alpha))
			draw_string(font,center+Vector2(-40,15),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(color,alpha))
	# Connections are attached to actual current units, not frozen picture coordinates.
	for e in manager.active:
		var age:float=manager.clock-float(e.born)
		var fade:=maxf(0,1-age/float(e.life))
		if e.type in ["gag_magnet","gag_soda","gag_house","gag_gavel","gag_delivery","gag_romance"]:
			var caster:Dictionary=manager.unit(str(e.get("sourceUid","")))
			var recipient:Dictionary=manager.unit(str(e.get("targetUid","")))
			if not caster.is_empty() and not recipient.is_empty() and recipient.get("alive",true):
				var start:=board.projection(float(caster.x),float(caster.y))
				var end:=board.projection(float(recipient.x),float(recipient.y))
				var friendly:bool=int(caster.team)==int(recipient.team)
				var warning:=Color("7cd8af") if friendly else Color("efaa7c")
				var radius:float=1.5 if e.type=="gag_soda" else (1.8 if int(e.get("variant",0))==2 else 1.2) if e.type=="gag_house" else 0.66
				var progress:=clampf(age/maxf(0.01,float(e.life)),0,1)
				line(PackedVector2Array([start,end]),warning,0.32,1.6)
				draw_arc(end,radius*cell,0,TAU,64,Color(warning,0.65),2.4,true)
				draw_arc(end,radius*cell*0.96,-PI*0.5,-PI*0.5+TAU*progress,64,Color(warning,0.95),3.8,true)
				var tip:=start.lerp(end,0.65)
				var direction:Vector2=(end-start).normalized()
				line(PackedVector2Array([tip-direction.rotated(0.5)*10,tip,tip-direction.rotated(-0.5)*10]),warning,0.8,2.2)
		if e.type == "gag_romance":
			for uid in [e.get("anchorUid",""),e.get("targetUid","")]:
				var actor: Dictionary = manager.unit(str(uid))
				if not actor.is_empty():
					var at := board.projection(float(actor.x),float(actor.y))
					GagRenderer.prop(self,"balcony",at+Vector2(0,cell*0.10),cell*1.1,0,sin(clampf(age/float(e.life),0,1)*PI)*0.95)
		if not e.type in ["charge","shield","heal","link"]:
			continue
		var source:Dictionary=manager.unit(str(e.get("sourceUid","")))
		var target:Dictionary=manager.unit(str(e.get("targetUid","")))
		if source.is_empty() or target.is_empty():
			continue
		var a:=board.projection(source.x,source.y)
		var b:=board.projection(target.x,target.y)
		var color:=ArtLibrary.faction_color(str(e.faction))
		if source.uid != target.uid:
			line(PackedVector2Array([a,b]),color,fade*0.5,1)
			draw_arc(b,cell*0.36,0,TAU,32,Color(color,fade*0.8),1.5,true)
			var direction:Vector2=(b-a).normalized()
			var tip:=a.lerp(b,0.72)
			line(PackedVector2Array([tip-direction.rotated(0.5)*7,tip,tip-direction.rotated(-0.5)*7]),color,fade,1.3)
		if e.type == "charge":
			var source_id:=int(source.id)
			var radii:Dictionary={13:1.5,15:2.0,19:1.5,40:1.2,53:2.3,58:1.8,60:2.0,62:2.5}
			if radii.has(source_id):
				draw_arc(b,float(radii[source_id])*cell,0,TAU,64,Color(color,0.65),1.5,true)
				for i in 12:
					var at:=b+Vector2.from_angle(i*TAU/12)*float(radii[source_id])*cell
					draw_line(at,at+(b-at).normalized()*5,Color(color,0.7),1,true)
	# History supply nodes and law evidence express the actual mechanics.
	for u in manager.data.get("units", []):
		if not u.get("alive",true):
			continue
		var p:=board.projection(u.x,u.y)
		var warning_radii := {13:1.5,15:2.0,19:1.5,40:1.2,53:2.3,58:1.8,60:2.0,62:2.5}
		if u.get("casting",false) and float(u.get("castEnd",0))>manager.clock and warning_radii.has(int(u.id)):
			var aim := board.projection(float(u.get("aimX",u.x)),float(u.get("aimY",u.y)))
			var warning := Color("f0a28d") if int(u.team)==1 else ArtLibrary.faction_color(str(u.faction))
			draw_arc(aim,float(warning_radii[int(u.id)])*cell,0,TAU,64,Color(warning,0.65),1.5,true)
			draw_string(font,aim+Vector2(-25,-12),"蓄力 %.1fs" % (float(u.castEnd)-manager.clock),HORIZONTAL_ALIGNMENT_LEFT,-1,11,warning)
		if "wall" in u.get("buffs",[]):
			var front := p+Vector2(0,-cell*0.48 if int(u.team)==0 else cell*0.48)
			for i in 5:
				var block := Rect2(front+Vector2((i-2)*cell*0.18,-7),Vector2(cell*0.16,12))
				draw_rect(block,Color("ae8659",0.65))
				draw_rect(block,Color("f0cf9a",0.8),false,1)
			draw_string(font,front+Vector2(-23,-12),"城墙 · 远程拦截",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e8ca96"))
		if float(u.get("shield",0))>0:
			var hexagon:=PackedVector2Array()
			for i in 7:
				hexagon.append(p+Vector2.from_angle(i*TAU/6)*cell*0.43)
			line(hexagon,Color("a4d7e6"),0.22+sin(manager.clock*3)*0.05,1)
		if "root" in u.get("buffs",[]) or "stun" in u.get("buffs",[]):
			draw_rect(Rect2(p-Vector2.ONE*cell*0.37,Vector2.ONE*cell*0.74),Color("ebd193",0.8),false,1.5)
		if u.get("node",false):
			var color:=Color("e4b578")
			draw_arc(p,cell*0.46,0,TAU,32,Color(color,0.6),1.5,true)
			for friend in manager.data.get("units", []):
				if friend.team==u.team and friend.uid!=u.uid and friend.get("alive",true) and Vector2(friend.x-u.x,friend.y-u.y).length()<=2:
					line(PackedVector2Array([p,board.projection(friend.x,friend.y)]),color,0.22,1)
