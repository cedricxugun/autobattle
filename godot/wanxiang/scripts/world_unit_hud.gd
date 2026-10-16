extends Node2D
var board: BattleBoard
var font:=SystemFont.new()
func _ready() -> void:
	font.font_names=["Microsoft YaHei UI","Microsoft YaHei"]
func _process(_delta:float) -> void:
	queue_redraw()
func _draw() -> void:
	if board.stage==null:return
	for actor in board.stage.actors.values():
		var u:Dictionary=actor.unit
		if not u.get("alive",true):continue
		var name: String = ArtLibrary.character(int(u.id)).name
		var point:=board.stage.camera.unproject_position(actor.global_position+Vector3(0,1.47,0))
		var foot:=board.stage.camera.unproject_position(actor.global_position)
		var color:=Color("a9dbc6") if int(u.team)==0 else Color("e2a295")
		var title:=name+" "+"★".repeat(int(u.star)) if u.get("bench",false) else name
		var width:=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		draw_string_outline(font,foot+Vector2(-width/2,12),title,HORIZONTAL_ALIGNMENT_LEFT,-1,10,3,Color("0a1824"))
		draw_string(font,foot+Vector2(-width/2,12),title,HORIZONTAL_ALIGNMENT_LEFT,-1,10,color)
		if u.get("bench",false):continue
		var hp:=clampf(float(u.hp)/maxf(1,float(u.maxhp)),0,1)
		draw_rect(Rect2(point-Vector2(23,2),Vector2(46,6)),Color("101e29"))
		draw_rect(Rect2(point-Vector2(22,1),Vector2(44*actor.body.trailing_health,4)),Color("bda777"))
		draw_rect(Rect2(point-Vector2(22,1),Vector2(44*hp,4)),color)
		var shield:=clampf(float(u.get("shield",0))/maxf(1,float(u.maxhp)),0,1)
		if shield>0:draw_rect(Rect2(point+Vector2(-22,5),Vector2(44*shield,2)),Color("c4d9f1"))
		var cooldown:=float(u.get("cdMax",0))
		if cooldown>0:
			var ready:=clampf(1-float(u.get("cd",cooldown))/cooldown,0,1)
			draw_rect(Rect2(point+Vector2(-22,9),Vector2(44*ready,2)),ArtLibrary.faction_color(str(u.faction)))
		draw_string(font,point+Vector2(-14,-5),"★".repeat(int(u.star)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ead5a0"))
		var tags:Array[String]=[]
		var names:Dictionary={"stun":"晕","root":"定","silence":"默","slow":"缓","acid":"酸","charge":"电","heat":"热"}
		for key in u.get("buffs",[]):
			if names.has(key):tags.append(names[key])
		for key in u.get("marks",[]):
			if names.has(key) and not tags.has(names[key]):tags.append(names[key])
		if int(u.get("evidence",0))>0:tags.append("证%d"%int(u.evidence))
		if not tags.is_empty():
			var status:=" ".join(tags)
			draw_string_outline(font,point+Vector2(26,4),status,HORIZONTAL_ALIGNMENT_LEFT,-1,10,3,Color("0b1721"))
			draw_string(font,point+Vector2(26,4),status,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("efd99f"))
		if actor.body.action_label.text!="":
			draw_string_outline(font,point+Vector2(-35,-20),actor.body.action_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,10,3,Color("111e28"))
			draw_string(font,point+Vector2(-35,-20),actor.body.action_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("f0dfac"))
