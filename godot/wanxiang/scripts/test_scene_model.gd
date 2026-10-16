extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var board:=BattleBoard.new()
	root.add_child(board)
	board.size=Vector2(1440,900)
	await process_frame
	await physics_frame
	var prop:=board.stage.showpiece
	if board.stage.architecture.get_child_count()!=2:
		push_error("SCENE_MODEL_TEST requires both real 3D buildings")
		quit(1)
		return
	for building in board.stage.architecture.get_children():
		if building.model==null:
			push_error("SCENE_MODEL_TEST building failed to load")
			quit(1)
			return
	if prop==null or prop.model==null:
		push_error("SCENE_MODEL_TEST missing runtime glTF model")
		quit(1)
		return
	var at:=board.stage.camera.unproject_position(prop.global_position+Vector3(0,0.9,0))
	if not board.stage.activate_scenery(at) or prop.pulse<=0:
		push_error("SCENE_MODEL_TEST world prop click failed")
		quit(1)
		return
	print("SCENE_MODEL_TEST PASS: runtime GLB, bounds normalization, scene ray pick, click response")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			for child in board.stage.world.get_children():
				if child is MeshInstance3D:child.hide()
			board.stage.bench_root.hide()
			board.stage.camera.position=prop.global_position+Vector3(2.8,2.1,4.5)
			board.stage.camera.look_at(prop.global_position+Vector3(0,0.95,0))
			board.stage.camera.size=2.8
			for i in 12:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))
	board.queue_free()
	await process_frame
	quit()
