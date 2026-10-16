extends SceneTree

var main: Control
var failed := false
var cursor := Vector2.ZERO

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	print(("PASS " if value else "FAIL ")+message)
	if not value:
		failed = true

func until(predicate: Callable) -> bool:
	var started := Time.get_ticks_msec()
	while not predicate.call() and Time.get_ticks_msec()-started<5000:
		await process_frame
	return predicate.call()

func motion(to: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to-cursor
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	cursor = to
	root.push_input(event,true)
	await process_frame

func mouse(pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = cursor
	event.global_position = cursor
	event.button_index = button
	event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button==MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	event.pressed = pressed
	root.push_input(event,true)
	await process_frame

func click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await motion(at)
	await mouse(true,button)
	await mouse(false,button)

func drag(from: Vector2, to: Vector2) -> void:
	await motion(from)
	await mouse(true)
	await motion(from+Vector2(15,0),true)
	check(root.gui_is_dragging(),"native drag starts from visible piece")
	for i in range(1,9):
		await motion(from.lerp(to,float(i)/8),true)
	await mouse(false)
	check(root.gui_is_drag_successful(),"native viewport accepts drop")
	await create_timer(0.25).timeout
	check(not main.popup.visible,"drag never opens detail popup")

func owned(uid: String) -> Dictionary:
	for unit in main.state.ownUnits:
		if str(unit.uid)==uid:
			return unit
	return {}

func board_point(unit: Dictionary) -> Vector2:
	return main.board.global_position+main.board.projection(float(unit.c),float(unit.r))

func run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	root.notify_mouse_entered()
	if not await until(func(): return not main.state.is_empty()):
		check(false,"local service connected")
		quit(1)
		return
	var revision := int(main.state.revision)
	main._send("new",{"difficulty":"easy"})
	await until(func(): return int(main.state.revision)>revision and main.state.difficulty=="easy" and main.state.ownUnits.is_empty())
	main.menu.hide()
	await process_frame
	await process_frame
	var count := 0
	for slot in [0,1,3,2]:
		var card: Control = main.shop_row.get_child(slot)
		await click(card.get_global_rect().get_center())
		count += 1
		check(await until(func(): return main.state.ownUnits.size()==count),"shop pointer purchase %d" % count)
		if failed:
			print("STATE ", main.state.events, " units ",main.state.ownUnits.size())
			break
	if failed:
		main.queue_free();await process_frame;quit(1);return
	var a := str(main.state.ownUnits[0].uid)
	var b := str(main.state.ownUnits[1].uid)
	var bench := str(main.state.ownUnits[3].uid)
	var old_a := Vector2(owned(a).c,owned(a).r)
	var old_b := Vector2(owned(b).c,owned(b).r)
	await click(board_point(owned(a)),MOUSE_BUTTON_RIGHT)
	check(await until(func(): return main.popup.visible),"inspect before starting drag")
	await click(board_point(owned(a)))
	check(not main.popup.visible,"left-click only selects; no panel")
	await drag(board_point(owned(a)),board_point(owned(b)))
	check(Vector2(owned(a).c,owned(a).r)==old_b and Vector2(owned(b).c,owned(b).r)==old_a,"board to board swaps both pieces")
	var bench_slot: Control = main.bench_row.get_child(1)
	await drag(board_point(owned(a)),bench_slot.get_global_rect().get_center())
	check(owned(a).c==null and owned(bench).c!=null,"board to occupied bench swaps directly")
	bench_slot = main.bench_row.get_child(1)
	await drag(bench_slot.get_global_rect().get_center(),board_point(owned(b)))
	check(owned(a).c!=null and owned(b).c==null,"bench to occupied board replaces at full capacity")
	var empty_bench: Control = main.bench_row.get_child(2)
	await drag(board_point(owned(a)),empty_bench.get_global_rect().get_center())
	check(owned(a).c==null,"board to empty bench withdraws")
	var unchanged := JSON.stringify(main.state.ownUnits)
	await motion(board_point(owned(bench)))
	await mouse(true)
	await motion(cursor+Vector2(20,0),true)
	check(root.gui_is_dragging(),"cancel test enters native drag")
	var escape := InputEventKey.new()
	escape.keycode=KEY_ESCAPE
	escape.pressed=true
	root.push_input(escape,true)
	await process_frame
	check(not root.gui_is_dragging(),"Escape cancels held piece")
	await mouse(false)
	await create_timer(0.25).timeout
	check(JSON.stringify(main.state.ownUnits)==unchanged,"cancelled drag preserves roster")
	await click(board_point(owned(bench)),MOUSE_BUTTON_RIGHT)
	check(await until(func(): return main.popup.visible),"right-click still opens details")
	print("POINTER_DRAG_SUITE "+("FAILED" if failed else "PASS"))
	main.queue_free()
	await process_frame
	quit(1 if failed else 0)
