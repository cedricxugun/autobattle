class_name GagRenderer
extends RefCounted

static func prop(canvas: CanvasItem, name: String, at: Vector2, size: float, angle: float = 0.0, alpha: float = 1.0, stretch: Vector2 = Vector2.ONE) -> void:
	var texture := ArtLibrary.prop(name)
	if texture == null:
		return
	var dimensions := texture.get_size()
	var extent := dimensions / maxf(dimensions.x,dimensions.y)*size
	canvas.draw_set_transform(at,angle,stretch)
	canvas.draw_texture_rect(texture,Rect2(-extent*0.5,extent),false,Color(1,1,1,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

static func caption(canvas: CanvasItem, font: Font, at: Vector2, words: String, color: Color, alpha: float = 1.0) -> void:
	var extent := font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,12)
	canvas.draw_string_outline(font,at-Vector2(extent.x*0.5,0),words,HORIZONTAL_ALIGNMENT_LEFT,-1,12,4,Color(0.03,0.05,0.07,alpha))
	canvas.draw_string(font,at-Vector2(extent.x*0.5,0),words,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(color,alpha))

static func draw(canvas: Node2D, e: Dictionary, age: float, p: Vector2, q: Vector2, cell: float, font: Font, units: Array) -> void:
	var t := clampf(age/maxf(0.05,float(e.life)),0,1)
	var fade := minf(1,(1-t)*5)
	var color := ArtLibrary.faction_color(str(e.get("faction","math")))
	if e.type == "gag_letters":
		for u in units:
			if str(u.uid) in [str(e.get("anchorUid","")),str(e.get("targetUid",""))] and (not u.get("alive",true) or int(u.get("linkUses",0))<=0):
				return
	for u in units:
		if str(u.uid)==str(e.get("targetUid","")) and e.type in ["gag_magnet","gag_delivery","gag_romance","gag_letters","gag_gavel","gag_house","gag_soda","gag_verse","gag_midnight"]:
			q=canvas.board.effect_projection(float(u.x),float(u.y))
			if e.type=="gag_midnight" and (not u.get("alive",true) or not "foreshadow" in u.get("buffs",[])):
				return
		if str(u.uid)==str(e.get("anchorUid","")) and e.type in ["gag_romance","gag_letters"]:
			p=canvas.board.effect_projection(float(u.x),float(u.y))
	match str(e.type):
		"gag_magnet":
			prop(canvas,"magnet",p-Vector2(0,cell*0.48),cell*0.58,sin(age*24)*0.12,fade)
			var start := p+Vector2(-cell*0.65,-cell*0.5)
			var travel := start.lerp(q,t)
			travel.y-=sin(t*PI)*cell*1.25
			canvas.draw_set_transform(q,0,Vector2(1,0.32))
			canvas.draw_circle(Vector2.ZERO,cell*(0.1+t*0.3),Color(0.02,0.04,0.06,0.25+t*0.15))
			canvas.draw_set_transform(Vector2.ZERO)
			for i in 5:
				var point:=p.lerp(travel,fmod(age*2+float(i)/5,1))
				canvas.draw_arc(point,5,0,PI,12,Color(color,0.55),1.5,true)
			prop(canvas,"car",travel,cell*1.02,-0.35+0.7*t)
			caption(canvas,font,q+Vector2(0,cell*0.6),"注意：铁皮车来袭",color,fade)
		"gag_land":
			var at := p-Vector2(0,sin(t*PI)*cell*0.12)
			var squash := Vector2(1.0+0.22*exp(-t*8)*sin(t*22),1.0-0.2*exp(-t*8)*sin(t*22))
			prop(canvas,str(e.get("prop","book")),at,cell*0.96,-0.12*exp(-t*5),fade,squash)
			canvas.draw_arc(p,cell*(0.22+t*0.7),0,TAU,48,Color(color,1-t),2*(1-t)+0.3,true)
			for i in 12:
				var direction:=Vector2.from_angle(i*2.4)
				var point:=p+direction*cell*t*(0.4+fmod(i*0.37,0.6))
				canvas.draw_line(point,point-direction*5*(1-t),Color(color,1-t),1.5,true)
		"gag_dice":
			var at := p.lerp(q,t)+Vector2(0,-sin(t*PI)*cell*1.05-cell*0.24)
			prop(canvas,"dice",at,cell*(0.52+sin(t*PI)*0.18),t*TAU*1.5)
			caption(canvas,font,at-Vector2(0,cell*0.44),"开奖中…" if t<0.8 else ["攻击！","护盾！","减速！"][int(e.get("outcome",0))],color)
		"gag_soda":
			var at:=p.lerp(q,t)+Vector2(0,-sin(t*PI)*cell*0.65)
			prop(canvas,"soda",at,cell*0.78,sin(t*PI*7)*0.14)
			for i in 8:
				var point:=at+Vector2(sin(i*4.3)*cell*0.3,-fmod(age*1.7+i*0.16,1)*cell*0.5)
				canvas.draw_arc(point,2.5,0,TAU,16,Color("b6eccb",0.6),1,true)
		"gag_fizz":
			prop(canvas,"soda",p,cell*0.65,0,fade)
			for i in 28:
				var angle := i*2.399
				var radius := cell*t*(0.25+fmod(i*0.27,1))
				var point := p+Vector2(cos(angle)*radius,-sin(t*PI)*cell*0.85+sin(angle)*radius*0.4)
				canvas.draw_circle(point,(2+fmod(i,4))*fade,Color(0.75,0.96,0.84,fade*0.6),false,1.3,true)
		"gag_delivery":
			var at:=p.lerp(q,smoothstep(0,1,t))+Vector2(0,-sin(t*PI)*cell*0.55)
			prop(canvas,"parcel",at,cell*0.62,sin(t*PI*4)*0.14)
			for i in 6:
				var behind:=p.lerp(q,maxf(0,t-i*0.035))+Vector2(0,-sin(t*PI)*cell*0.55)
				canvas.draw_line(behind-Vector2(8,0),behind,Color(color,(1-float(i)/6)*0.3),1,true)
		"gag_romance":
			prop(canvas,"letter",p.lerp(q,t)+Vector2(0,-sin(t*PI)*cell*0.55),cell*0.36,sin(t*PI)*0.3)
		"gag_letters":
			var progress := fmod(age*0.85,1)
			var curve := PackedVector2Array()
			for i in 25:
				var k:=float(i)/24
				curve.append(p.lerp(q,k)+Vector2(0,-sin(k*PI)*cell*0.35))
			canvas.draw_polyline(curve,Color("e4a8be",fade*0.65),1.5,true)
			for k in [progress,1-progress]:
				prop(canvas,"letter",p.lerp(q,k)+Vector2(0,-sin(k*PI)*cell*0.35),cell*0.24,sin(age*3)*0.12,fade)
			caption(canvas,font,p.lerp(q,0.5)-Vector2(0,cell*0.45),"治疗 / 护盾互传 40%",Color("f2c3d3"),fade)
		"gag_house":
			var name: String = ["straw","wood","brick"][int(e.get("variant",0))]
			var at:=q-Vector2(0,cell*1.7*(1-t*t))
			prop(canvas,name,at,cell*0.85,sin(t*8)*0.08)
			canvas.draw_arc(q,cell*0.3,0,TAU,32,Color(color,0.7),1.5,true)
		"gag_midnight":
			prop(canvas,"pumpkin",q+Vector2(cell*0.3,-cell*0.3),cell*0.36,sin(age*9)*0.08,0.8)
			canvas.draw_arc(q,cell*0.4,-PI*0.5,-PI*0.5+TAU*(1-t),48,Color("efbb83",0.8),2,true)
			caption(canvas,font,q-Vector2(0,cell*0.65),"午夜倒计时 · %d" % maxi(1,ceili(3-age)),Color("f0d4a0"),fade)
		"gag_gavel":
			var at := q-Vector2(0,cell*(0.65+(1-t)*0.5))
			prop(canvas,"gavel",at,cell*1.2,-0.8+t*0.5)
			canvas.draw_arc(q,cell*0.4,0,TAU,40,Color(color,0.8),2,true)
			caption(canvas,font,q+Vector2(0,cell*0.55),"裁决蓄力",color)
		"gag_poem", "gag_verse":
			var at:=p if e.type=="gag_poem" else p.lerp(q,minf(1,t*2))
			prop(canvas,"book",at-Vector2(0,cell*0.3),cell*0.6,sin(age*4)*0.12,fade)
			for i in 8:
				var point:=at+Vector2(sin(i*2.4+age*3)*cell*0.45,-t*cell*0.6+i*2)
				canvas.draw_set_transform(point,i*0.7+age)
				canvas.draw_rect(Rect2(-3,-5,6,10),Color(0.95,0.9,0.75,fade))
			canvas.draw_set_transform(Vector2.ZERO)
		"gag_signature":
			var at:=p-Vector2(0,cell*(0.45+sin(t*PI)*0.18))
			prop(canvas,str(e.get("prop","book")),at,cell*0.42,sin(t*PI*2)*0.1,fade)
			if e.get("caption","")!="":
				caption(canvas,font,at-Vector2(0,cell*0.3),str(e.caption),color,fade)
