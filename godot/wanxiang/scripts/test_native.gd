extends SceneTree

var main: Control
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAILED: " + message)
		failed = true

func until(predicate: Callable) -> bool:
	var start := Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec() - start < 15000:
		await process_frame
	return predicate.call()

func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	check(await until(func(): return not main.state.is_empty()), "bridge connects")
	if failed:
		quit(1)
		return
	main._send("new", {"difficulty": "easy"})
	check(await until(func(): return main.state.difficulty == "easy" and main.state.ownUnits.is_empty()), "new game")
	main.menu.hide()
	for slot in [0, 2, 4]:
		main._send("buy", {"slot": slot})
	check(await until(func(): return main.state.ownUnits.size() == 1 and int(main.state.ownUnits[0].star) == 2), "real two-star merge")
	var unit: Dictionary = main.state.ownUnits[0]
	var piece: ChessPiece = main.board.pieces[str(unit.uid)]
	check(piece.star == 2, "board switches star")
	check(piece.sprite.sprite_frames == ArtLibrary.sprite_frames(0, 2), "board switches full animation set")
	check(piece.upgrade_age < 1, "upgrade effect triggers")
	for id in 54:
		var previous_y := -1.0
		for star in [1, 2, 3]:
			var texture := ArtLibrary.actor_frame(id, star, 0)
			check(texture != null and texture.region.position.y > previous_y, "independent star artwork %d" % id)
			previous_y = texture.region.position.y
			check(ArtLibrary.sprite_frames(id, star).get_frame_count("walk") == 4, "walk frames")
	main.codex.show_character(53)
	main.codex.show()
	await process_frame
	check(main.codex.portraits.size() == 3, "three-star gallery")
	main.codex.hide()
	var empty_slot: UnitSlot = main.bench_row.get_child(1)
	var payload := {"kind": "unit", "uid": str(unit.uid), "id": 0, "star": 2}
	check(empty_slot._can_drop_data(Vector2.ZERO, payload), "bench accepts unit drag")
	empty_slot._drop_data(Vector2.ZERO, payload)
	check(await until(func(): return main.state.ownUnits[0].c == null), "drop removes from board")
	var at: Vector2 = main.board.projection(2, 5)
	check(main.board._can_drop_data(at, payload), "board accepts bench unit")
	main.board._drop_data(at, payload)
	check(await until(func(): return main.state.ownUnits[0].c != null), "drop redeploys")
	main._send("inspect", {"uid": unit.uid, "player": "you"})
	check(await until(func(): return main.popup.visible), "native detail popup")
	main._send("close_inspect")
	main._send("start")
	check(await until(func(): return main.state.phase == "battle"), "start native battle")
	main._send("watch", {"player": "ai0"})
	check(await until(func(): return main.state.watching == "ai0"), "native spectator switches")
	check(not main.board._can_drop_data(at, payload), "spectator prohibits unit drag")
	print("NATIVE_UI_TEST " + ("FAILED" if failed else "PASS: bridge, real merge, 162 star appearances, animation switch, gallery, bench/board drop handlers, detail popup, spectator"))
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)
