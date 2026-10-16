extends SceneTree
var failed:=false
func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	failed=failed or not ok
func run() -> void:
	var board:=BattleBoard.new()
	root.add_child(board)
	board.size=Vector2(1440,900)
	board.effects_layer.sound_enabled=false
	var fx:Node3D=board.stage.world_effects
	check(fx.templates.has("magnet-car") and fx.templates.has("verdict-gavel"),"both real 3D skill assets loaded")
	var unit:Dictionary={"uid":"caster","id":10,"star":1,"team":0,"faction":"physics","x":2,"y":5,"alive":true,"hp":100,"maxhp":100,"buffs":[]}
	var target:Dictionary=unit.duplicate(true)
	target.uid="victim";target.team=1;target.y=3
	var event:Dictionary={"id":9,"type":"gag_magnet","sourceUid":"caster","targetUid":"victim","born":0.0,"life":0.7,"ttl":0.35,"x":2,"y":5,"x2":2,"y2":3,"faction":"physics"}
	var packet:Dictionary={"matchKey":"world-vfx","round":1,"phase":"battle","watching":"you","paused":true,"board":{"time":0.35,"done":false,"units":[unit,target],"effects":[event],"zones":[]}}
	board.update_state(packet)
	fx._process(0)
	check(fx.live.has(9),"flight event creates a world node")
	var flight:Node3D=fx.live[9]
	var location:=flight.position
	check(location.y>1.5,"car follows an elevated 3D arc")
	var instance:=flight.get_instance_id()
	board.effects_layer._process(0.25)
	fx._process(0.25)
	check(flight.position.is_equal_approx(location),"pause freezes 3D flight")
	board.update_state(packet)
	fx._process(0)
	check(fx.live[9].get_instance_id()==instance,"same snapshot does not respawn the prop")
	packet.paused=false;packet.phase="result";packet.board.done=true
	board.update_state(packet)
	board.effects_layer._process(1.0)
	fx._process(1.0)
	check(fx.live.is_empty(),"finished battle clears 3D props and particles")
	check(is_zero_approx(board.stage.camera.h_offset),"camera feedback settles back to zero")
	packet.matchKey="other-board";packet.board.time=0;packet.board.effects=[]
	board.update_state(packet);fx._process(0)
	check(fx.live.is_empty(),"switching boards clears visual state")
	for code in [8,17,26,35,44,53]:
		packet.matchKey="legend-"+str(code);packet.paused=true;packet.phase="battle";packet.board.done=false;packet.board.time=.5
		packet.board.effects=[{"id":code,"type":"legendary_release","legend":code,"sourceUid":"caster","targetUid":"victim","born":0.0,"life":1.8,"ttl":1.3,"x":2,"y":5,"x2":4,"y2":1,"r":2.8 if code==17 else 2.6,"faction":"literature" if code==44 else "math"}]
		board.update_state(packet);fx._process(0)
		check(fx.live.has(code),"legendary world effect "+str(code))
		if fx.live.has(code):
			check(fx.live[code].position.is_equal_approx(Vector3(1.5,.21,-2.5)),"legendary locks to real target cell "+str(code))
			check(is_equal_approx(fx.live[code].radius,2.8 if code==17 else 2.6),"visual radius equals simulation "+str(code))
		packet.paused=false;packet.phase="result";packet.board.done=true
		board.update_state(packet);board.effects_layer._process(2.5);fx._process(2.5)
		check(fx.live.is_empty(),"legendary expires "+str(code))
	board.queue_free()
	await process_frame
	quit(1 if failed else 0)
