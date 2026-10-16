extends SceneTree

var failed := false

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error("TEST FAILED: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var board := BattleBoard.new()
	root.add_child(board)
	for dimensions in [Vector2(600,360),Vector2(960,470),Vector2(1180,780)]:
		board.size = dimensions
		for row in 8:
			for column in 6:
				var center := board.projection(column,row)
				check(board.cell_at(center)==Vector2i(column,row),"cell center inverse")
				check(board.cell_at(board.projection(column+0.49,row+0.49))==Vector2i(column,row),"full visible tile belongs to same drop cell")
		check(is_equal_approx(board.stage.tiles[0].get_aabb().size.x,board.stage.tiles[0].get_aabb().size.z),"3D tiles are square in world space")
	check(is_zero_approx(board.stage.yaw),"default camera looks straight down the battle axis")
	check(board.stage.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"arena uses perspective, not a flat board projection")
	check(board.projection(0,7).distance_to(board.projection(5,7))>board.projection(0,0).distance_to(board.projection(5,0))*1.2,"near rank visibly wider than far rank")
	check(board.stage.scenery==null,"no camera-aligned scenery sheet behind the board")
	for zoom in [8.2,8.8,9.6]:
		board.stage.zoom_size=zoom
		board.stage._set_camera()
		check(absf(board.projection(0,3).y-board.projection(5,3).y)<0.1,"ranks remain horizontal")
		check(board.projection(2,7).y>board.projection(2,0).y,"friendly army is below opposing army")
		for row in 8:
			for col in 6:
				check(board.cell_at(board.projection(col,row))==Vector2i(col,row),"camera zoom preserves ray/grid alignment")
		for slot in 9:
			check(board.stage.bench_at(board.stage.bench_screen(slot))==slot,"all nine world bench slots align")
	board.stage.zoom_size=8.8
	board.stage._set_camera()
	for angle in [-14.0,14.0]:
		board.stage.yaw=angle
		board.stage._set_camera()
		for row in 8:
			for col in 6:
				check(board.cell_at(board.projection(col,row))==Vector2i(col,row),"inspection angle preserves ground picking")
	board.stage.yaw=0.0
	board.stage._set_camera()
	var fx = board.effects_layer
	var event := {"id":1,"born":0.0,"life":0.5,"ttl":0.5,"type":"impact","x":2,"y":3,"x2":2,"y2":3,"faction":"math"}
	var packet := {"matchKey":"test","round":1,"phase":"result","board":{"time":0.0,"done":true,"units":[],"effects":[event],"zones":[]}}
	packet.board.effects.append({"id":2,"born":0.0,"life":0.8,"ttl":0.8,"type":"number","numberType":"physical","amount":100,"targetUid":"victim","x":2,"y":3,"x2":2,"y2":3})
	fx.update_state(packet)
	for i in 30:
		fx.update_state(packet)
		fx._process(0.1)
	check(fx.active.is_empty(),"ended board cannot replay frozen event")
	check(fx.seen.size()==2,"same event admitted only once")
	check(fx.numbers.is_empty(),"damage numbers also expire on repeated final snapshots")
	packet.matchKey="new"
	packet.phase="battle"
	packet.paused=true
	packet.board.done=false
	fx.update_state(packet)
	var clock_before: float=fx.clock
	fx._process(0.3)
	check(fx.clock==clock_before,"pause freezes VFX timeline")
	packet.matchKey="interrupt"
	packet.paused=false
	packet.board.units=[{"uid":"caster","id":51,"star":1,"team":0,"x":2,"y":3,"alive":true,"buffs":["stun"]}]
	packet.board.effects=[{"id":3,"type":"gag_gavel","sourceUid":"caster","born":0.0,"life":0.5,"ttl":0.5,"x":2,"y":3,"x2":2,"y2":2,"faction":"law"}]
	fx.update_state(packet)
	fx._process(0.01)
	check(fx.active.is_empty(),"interrupted gavel removes its warning and flying prop")
	packet.board.units[0].buffs=[]
	fx.update_state(packet)
	check(fx.active.is_empty(),"old interrupted cue cannot restart after stun expires")
	var piece := ChessPiece.new()
	root.add_child(piece)
	var u := {"uid":"unit","id":0,"star":1,"team":0,"x":3.0,"y":4.0,"aimX":1.0,"aimY":4.0,"faction":"math","alive":true,"attackAt":0.0,"hitAt":-99,"castAt":-99}
	piece.update_unit(u,Vector2.ZERO)
	piece.visual_clock=0.05
	piece._process(0.01)
	check(piece.sprite.flip_h,"attack faces target to left")
	check(piece.animation_name=="attack","actual attack state")
	u.aimX=5.0
	piece.update_unit(u,Vector2.ZERO)
	piece._process(0.01)
	check(not piece.sprite.flip_h,"attack turns right with new target")
	piece.visual_clock=4.0
	piece._process(0.01)
	check(piece.animation_name=="idle","finished attack returns to idle without fresh snapshot")
	u.casting=true;u.castEnd=5.0
	piece.update_unit(u,Vector2.ZERO)
	piece._process(0.01)
	check(piece.animation_name=="cast","channel state")
	var codex := EvolutionCodex.new()
	root.add_child(codex)
	codex.selected_faction="math";codex._populate()
	check(codex.grid.get_child_count()==9,"math category has nine units")
	codex.selected_faction="wild";codex._populate()
	check(codex.grid.get_child_count()==9,"wild category has nine units")
	codex.selected_faction="all";codex.search.text="公理";codex._populate()
	check(codex.grid.get_child_count()==1,"search filters gallery")
	piece.queue_free();board.queue_free();codex.queue_free()
	await process_frame
	print("PRESENTATION_TEST "+("FAILED" if failed else "PASS: square geometry, full-cell hit mapping, no replay, pause, target facing, animation transitions, categorized gallery"))
	quit(1 if failed else 0)
