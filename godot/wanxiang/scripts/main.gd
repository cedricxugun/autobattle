extends Control

var bridge: SimulationBridge
var board: BattleBoard
var state: Dictionary = {}
var selected_uid := ""
var signature := ""
var slot_signature := ""
var last_event_id := 0
var faction_box: VBoxContainer
var players_box: VBoxContainer
var bench_row: HBoxContainer
var item_row: HBoxContainer
var shop_row: HBoxContainer
var round_label: Label
var health_label: Label
var gold_label: Label
var level_label: Label
var xp_label: Label
var odds_label: Label
var pairing_label: Label
var next_label: Label
var clock_label: Label
var status_label: Label
var begin_button: Button
var refresh_button: Button
var xp_button: Button
var lock_button: Button
var pause_button: Button
var speed_button: Button
var return_button: Button
var replay_button: Button
var popup: PanelContainer
var popup_box: VBoxContainer
var result_panel: PanelContainer
var result_box: VBoxContainer
var menu: PanelContainer
var menu_box: VBoxContainer
var help_panel: PanelContainer
var toast: Label
var toast_time := 0.0
var chosen_difficulty := "hard"
var first_state := true
var sound_enabled := true
var audio := AudioStreamPlayer.new()
var inspect_position := Vector2.ZERO
var qa_capture := ""
var qa_scene_angle := 0.0
var qa_sequence_frames: Array = []
var qa_recording := false
var qa_ticks := 0
var codex: EvolutionCodex
var qa_codex := false
var qa_battle := false
var qa_demo := -1
var qa_sequence := ""
var dock: PanelContainer
var players_panel: PanelContainer
var initial_demo := -1
var arrange_demo := false
var qa_capture_cue := ""
var qa_capturing := false

func _ready() -> void:
	DisplayServer.window_set_title("万象棋局 · 十人口与传说 0.6 预览")
	get_window().title = "万象棋局 · 知识嘉年华"
	get_window().min_size = Vector2i(1180, 740)
	var font := SystemFont.new()
	font.font_names = ["Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI"]
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 14
	var base := box_style(Color("172b35"), Color("45605c"), 5)
	var hover := box_style(Color("2b454c"), Color("b9ab79"), 5)
	skin.set_stylebox("normal", "Button", base)
	skin.set_stylebox("hover", "Button", hover)
	skin.set_stylebox("pressed", "Button", box_style(Color("405a57"), Color("dbc18b"), 5))
	skin.set_stylebox("disabled", "Button", box_style(Color("12212a"), Color("2e4349"), 5))
	skin.set_color("font_color", "Button", Color("e4e7d8"))
	skin.set_color("font_color", "Label", Color("dfE6da"))
	skin.set_color("font_disabled_color", "Button", Color("607c81"))
	skin.set_stylebox("panel", "PanelContainer", box_style(Color("132630"), Color("3e585b"), 7))
	theme = skin
	add_child(audio)
	_build_interface()
	bridge = SimulationBridge.new()
	bridge.state_received.connect(_on_state)
	bridge.connection_error.connect(func(message): status_label.text = message; _toast(message, true))
	add_child(bridge)
	resized.connect(_place_overlays)
	_place_overlays()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-cue="):
			qa_capture_cue = argument.trim_prefix("--capture-cue=")
		if argument == "--arrange-demo":
			arrange_demo = true
		if argument == "--capture-stress":
			qa_demo = -2
			qa_battle = true
		if argument.begins_with("--demo="):
			initial_demo = int(argument.trim_prefix("--demo="))
		if argument.begins_with("--capture-demo="):
			qa_demo = int(argument.trim_prefix("--capture-demo="))
			qa_battle = true
		if argument.begins_with("--capture-sequence="):
			qa_sequence = argument.trim_prefix("--capture-sequence=")
			DirAccess.make_dir_recursive_absolute(qa_sequence)
		if argument == "--capture-codex":
			qa_codex = true
		if argument == "--capture-battle":
			qa_battle = true
		if argument == "--codex":
			codex.show()
		if argument.begins_with("--capture="):
			qa_capture = argument.trim_prefix("--capture=")
		if argument.begins_with("--scene-angle="):
			qa_scene_angle=float(argument.trim_prefix("--scene-angle="))
	if not qa_capture.is_empty():
		menu.visible = false

func box_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func label(text: String, font_size: int = 14, color: Color = Color("dfe6da")) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.modulate = color
	return item

func button(text: String, callback: Callable, minimum: Vector2 = Vector2.ZERO) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = minimum
	item.pressed.connect(callback)
	return item

func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	margin.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 15)
	root.add_child(header)
	header.add_child(label("万象棋局", 27, Color("e5cd98")))
	header.add_child(label("终局 · 0.6",11,Color("8ba8a6")))
	round_label = label("联赛连接中", 15)
	round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(round_label)
	health_label = label("生命 100", 20, Color("e3a899"))
	header.add_child(health_label)
	header.add_child(button("图鉴 / 升星", func(): codex.show()))
	header.add_child(button("玩法 / 公式", func(): help_panel.visible = not help_panel.visible))
	header.add_child(button("难度 / 新局", func(): menu.visible = true; _build_menu()))
	header.add_child(button("声音", func(): sound_enabled = not sound_enabled; _toast("声音开启" if sound_enabled else "声音关闭")))
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	var left := PanelContainer.new()
	left.custom_minimum_size.x = 230
	content.add_child(left)
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(left_scroll)
	faction_box = VBoxContainer.new()
	faction_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faction_box.add_theme_constant_override("separation", 8)
	left_scroll.add_child(faction_box)
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(middle)
	var controls := HBoxContainer.new()
	middle.add_child(controls)
	pairing_label = label("等待对局", 13)
	pairing_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(pairing_label)
	return_button = button("我的棋盘", func(): _send("watch", {"player": "you"}))
	controls.add_child(return_button)
	pause_button = button("暂停", func(): _send("pause"))
	controls.add_child(pause_button)
	speed_button = button("1×", func(): _send("speed", {"value": [0.5,1.0,2.0,3.0][([0.5,1.0,2.0,3.0].find(float(state.get("speed",1)))+1)%4]}))
	controls.add_child(speed_button)
	controls.add_child(button("视角复位",func(): board.stage.yaw=0.0; board.stage.zoom_size=8.8; board.stage._set_camera()))
	replay_button = button("重播演示",func(): _send("replay_preview"))
	replay_button.visible = false
	controls.add_child(replay_button)
	begin_button = button("开始战斗", func(): popup.hide(); _send("close_preview" if state.get("preview",false) else "start"), Vector2(112, 34))
	begin_button.add_theme_stylebox_override("normal", box_style(Color("a48b57"), Color("e4cd91"), 5))
	controls.add_child(begin_button)
	next_label = label("下一轮信息", 11, Color("9ebcb6"))
	middle.add_child(next_label)
	board = BattleBoard.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(600, 360)
	board.action.connect(_send)
	board.scenery_hint.connect(func(message): _toast(message); toast_time=5.0)
	board.selection_changed.connect(func(uid):
		selected_uid = uid
		popup.hide()
		if state.get("detail") != null:
			_send("close_inspect")
	)
	board.inspect_unit.connect(_inspect_board)
	middle.add_child(board)
	var bottom_status := HBoxContainer.new()
	middle.add_child(bottom_status)
	clock_label = label("准备阶段", 12, Color("cbb886"))
	bottom_status.add_child(clock_label)
	status_label = label("正在启动本地对局模块…", 11, Color("8eaaa9"))
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom_status.add_child(status_label)
	var right := PanelContainer.new()
	players_panel = right
	right.custom_minimum_size.x = 208
	content.add_child(right)
	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(right_scroll)
	players_box = VBoxContainer.new()
	players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	players_box.add_theme_constant_override("separation", 6)
	right_scroll.add_child(players_box)
	dock = PanelContainer.new()
	root.add_child(dock)
	var dock_box := VBoxContainer.new()
	dock_box.add_theme_constant_override("separation", 5)
	dock.add_child(dock_box)
	bench_row = HBoxContainer.new()
	bench_row.custom_minimum_size.y = 63
	dock_box.add_child(bench_row)
	bench_row.visible=false
	item_row = HBoxContainer.new()
	item_row.custom_minimum_size.y = 32
	dock_box.add_child(item_row)
	var market := HBoxContainer.new()
	market.add_theme_constant_override("separation", 8)
	dock_box.add_child(market)
	var wallet := VBoxContainer.new()
	wallet.custom_minimum_size.x = 155
	market.add_child(wallet)
	gold_label = label("金币 15", 23, Color("edcf8b"))
	wallet.add_child(gold_label)
	level_label = label("等级 3 · 上阵 0 / 3", 12)
	wallet.add_child(level_label)
	xp_label = label("经验 0 / 6", 10, Color("a1baba"))
	wallet.add_child(xp_label)
	xp_button = button("研习 +4经验 · 4金币 [F]", func(): _send("xp"))
	xp_button.add_theme_font_size_override("font_size", 12)
	wallet.add_child(xp_button)
	refresh_button = button("刷新 · 2金币 [D]", func(): _send("refresh"))
	refresh_button.add_theme_font_size_override("font_size", 12)
	wallet.add_child(refresh_button)
	var offers := VBoxContainer.new()
	offers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market.add_child(offers)
	var offer_header := HBoxContainer.new()
	offers.add_child(offer_header)
	odds_label = label("万象集市", 11, Color("b7c9c1"))
	odds_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offer_header.add_child(odds_label)
	lock_button = button("锁定", func(): _send("lock"))
	lock_button.add_theme_font_size_override("font_size", 11)
	offer_header.add_child(lock_button)
	shop_row = HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 7)
	shop_row.custom_minimum_size.y = 117
	offers.add_child(shop_row)
	popup = PanelContainer.new()
	popup.z_index = 100
	popup.custom_minimum_size = Vector2(335, 0)
	popup.visible = false
	add_child(popup)
	popup_box = VBoxContainer.new()
	popup_box.add_theme_constant_override("separation", 9)
	popup.add_child(popup_box)
	result_panel = PanelContainer.new()
	result_panel.z_index = 110
	result_panel.visible = false
	add_child(result_panel)
	result_box = VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 14)
	result_panel.add_child(result_box)
	menu = PanelContainer.new()
	menu.z_index = 150
	add_child(menu)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 15)
	menu.add_child(menu_box)
	_build_menu()
	help_panel = PanelContainer.new()
	help_panel.z_index = 160
	help_panel.visible = false
	add_child(help_panel)
	var help_box := VBoxContainer.new()
	help_box.add_theme_constant_override("separation", 13)
	help_panel.add_child(help_box)
	help_box.add_child(label("万象棋局 · 对局手册", 24, Color("e7cc91")))
	var help_text := RichTextLabel.new()
	help_text.custom_minimum_size = Vector2(660, 420)
	help_text.bbcode_enabled = true
	help_text.text = "[b]操作[/b]\n左键购买商店棋子；右键查看技能。拖拽场上棋子换位，拖回备战席撤下，拖到已有棋子上直接交换。装备可从背包拖给棋子。\n\n[b]升星与外观[/b]\n三个同名同星合成高一星。每星使用独立造型与动作帧。最高三星。\n\n[b]联赛与观战[/b]\n8人参赛，最高10级/10人口上阵，最多35轮。八个棋盘同时独立战斗。你面对来袭镜像，你的镜像也会挑战另一棋手。点击右侧列表切换观战。本人的棋盘失败才扣本人的生命。\n\n[b]野怪与掉落[/b]\n第1、2、3、8、13、18、23、28、33轮为野怪。首轮和精英轮战胜野怪后可从三件遗物中选一件。\n\n[b]卡池[/b]\n1至5费各角色共有35/30/25/18/12张。商店占用库存，刷新、出售和淘汰归还；二星占3张、三星占9张。5级开始出现4费，7级开始出现5费；7/8/9/10级传说概率为1%/6%/15%/25%。每系9角色包含2张普通、2张精良、2张稀有、2张史诗、1张传说。\n\n[b]伤害[/b]\n基础双抗=18+费用×3+羁绊+装备；5费英雄额外+12。实际伤害=面板伤害×增伤×100/(100+有效抗性)×减伤；护盾先吸收，剩余扣血。普攻走护甲，默认技能走法抗。100伤害打50抗性约造成66.7伤害。\n\n[b]经济[/b]\n每轮8基础金币，胜利额外3、失败额外1，每10存款+1利息，上限5。每轮+2经验，4金币研习+4经验。"
	help_box.add_child(help_text)
	help_box.add_child(button("返回棋局", func(): help_panel.hide()))
	toast = label("", 16, Color("f0d89d"))
	toast.z_index = 200
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.visible = false
	add_child(toast)
	codex = EvolutionCodex.new()
	codex.visible = false
	add_child(codex)
	codex.demonstrate.connect(func(id): menu.hide(); _send("preview_battle" if id<0 else "preview_skill", {"id":id}))

func _build_menu() -> void:
	clear(menu_box)
	menu_box.add_child(label("万象棋局", 34, Color("e9d097")))
	menu_box.add_child(label("知识嘉年华 · 阵容有门道，离谱也有理", 15, Color("a5c8bf")))
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	menu_box.add_child(choices)
	var modes := [["easy", "简单", "基础布阵\n较少刷新，适合熟悉角色"], ["hard", "困难", "经营利息与羁绊\n会合成、转阵和针对站位"], ["torment", "磨难", "评估多套候选阵容\n根据对手调整战术与装备"]]
	for info in modes:
		var b := button(str(info[1]) + "\n\n" + str(info[2]), func(): chosen_difficulty = info[0]; _build_menu(), Vector2(210, 125))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 14)
		if chosen_difficulty == info[0]:
			b.add_theme_stylebox_override("normal", box_style(Color("3c4e42"), Color("d8bd83"), 7))
		choices.add_child(b)
	menu_box.add_child(label("三个难度共用同样的金币、棋池与战斗规则。", 12, Color("8ea9a9")))
	menu_box.add_child(button("开始新联赛", func(): menu.hide(); _send("new", {"difficulty": chosen_difficulty,"starter":"carnival"}), Vector2(0, 42)))
	menu_box.add_child(button("先看角色 · 三星进化与动作图鉴", func(): codex.show()))
	if not state.is_empty():
		menu_box.add_child(button("继续当前棋局", func(): menu.hide()))

func _send(command: String, arguments: Dictionary = {}) -> void:
	if bridge != null:
		bridge.send_command(command, arguments)
	if command in ["next", "new", "start", "watch"]:
		popup.hide()
	if command in ["next", "new", "start"]:
		status_label.text = "对局正在准备…"

func _on_state(value: Dictionary) -> void:
	state = value
	board.update_state(value)
	board.effects_layer.sound_enabled = sound_enabled
	clock_label.text = ("交战 %.1f 秒" % float(value.board.get("time", 0))) if value.phase == "battle" else "准备阶段：自由布阵"
	if value.phase == "battle" and value.board.get("done", false):
		clock_label.text += " · 本棋盘已结束，可观战其他棋手"
	var new_signature := JSON.stringify([value.phase, value.round, value.gold, value.health, value.level, value.xp, value.shop, value.ownUnits, value.bag, value.pendingLoot, value.players, value.watching, value.detail, value.result, value.locked, value.speed, value.paused, value.get("preview",false)])
	# Strip live board timers from HUD changes; the board is updated separately.
	var stable_players := []
	for p in value.players:
		stable_players.append([p.id, p.health, p.level, p.gold, p.rank])
	new_signature = JSON.stringify([value.phase, value.round, value.gold, value.health, value.level, value.xp, value.shop, value.ownUnits, value.bag, value.pendingLoot, stable_players, value.watching, value.detail, value.result, value.locked, value.speed, value.paused, value.get("preview",false)])
	if new_signature != signature:
		signature = new_signature
		_refresh_hud()
	for event in value.events:
		if int(event.id) > last_event_id:
			last_event_id = int(event.id)
			_toast(str(event.text), event.type == "error")
			_play_sound(str(event.type))
	if first_state:
		first_state = false
		_build_menu()
		if initial_demo != -1:
			menu.hide()
			_send("preview_battle" if initial_demo<0 else "preview_skill", {"id":initial_demo})
		elif arrange_demo:
			menu.hide()
			_send("new", {"difficulty":"easy"})
			for slot in [0,1,3,2]:
				_send("buy", {"slot":slot})
		if not qa_capture.is_empty():
			menu.hide()

func _refresh_hud() -> void:
	var preparing: bool = state.phase == "prepare"
	dock.visible = state.phase != "battle"
	players_panel.visible = not state.get("preview", false)
	var names := {"easy": "简单", "hard": "困难", "torment": "磨难"}
	round_label.text = "第 %d / %d 回合 · %s · %s" % [int(state.round), int(state.get("maxRounds",35)), "野怪" if state.roundType == "pve" else "棋手", names.get(state.difficulty, "困难")]
	if state.get("preview",false):
		round_label.text = "独立技能演示 · 不影响联赛"
	health_label.text = "生命 %d" % int(state.health)
	gold_label.text = "金币 %d" % int(state.gold)
	var deployed := 0
	for u in state.ownUnits:
		if u.c != null:
			deployed += 1
	level_label.text = "等级 %d · 上阵 %d / %d" % [int(state.level), deployed, int(state.level)]
	xp_label.text = "最高等级" if int(state.level) >= int(state.get("maxLevel",10)) else "经验 %d / %d" % [int(state.xp), int(state.xpNeed)]
	odds_label.text = "白 / 绿 / 蓝 / 紫 / 金 · %s" % " / ".join(state.odds.map(func(v): return str(int(v)) + "%"))
	begin_button.disabled = (not preparing or deployed == 0) and not state.get("preview",false)
	begin_button.text = "退出技能演示" if state.get("preview",false) else "开始战斗"
	refresh_button.disabled = not preparing or int(state.gold) < 2
	xp_button.disabled = not preparing or int(state.gold) < 4 or int(state.level) >= int(state.get("maxLevel",10))
	lock_button.disabled = not preparing
	lock_button.text = "已锁定" if state.locked else "锁定"
	pause_button.visible = state.phase == "battle"
	pause_button.text = "继续" if state.paused else "暂停"
	speed_button.text = "%s×" % str(float(state.speed))
	replay_button.visible = state.get("preview",false)
	return_button.visible = state.watching != "you"
	pairing_label.text = "%s  ←  %s" % [state.watchName, state.enemyName]
	next_label.text = str(state.nextHint) + ("  ·  你的镜像挑战：" + str(state.outgoingName) if state.outgoingName != null else "")
	if state.get("preview",false):next_label.text="橙色锁定敌方 · 绿色指向友方 · 圆弧闭合后命中；大范围圈显示落地区域"
	status_label.text = "技能演示 · 不影响当前联赛" if state.get("preview",false) else "左键拖动交换 / 上下场 · 右键看详情"
	_refresh_traits()
	_refresh_players()
	var slots_key := JSON.stringify([preparing,state.ownUnits,state.shop,state.bag,state.gold])
	if slots_key != slot_signature:
		slot_signature = slots_key
		_refresh_slots(preparing)
	_refresh_result()
	if state.detail != null:
		_show_detail(state.detail)
	else:
		popup.hide()

func _trait_text(id: String, tier: int) -> String:
	var rows := {
		"math":["每6次数学技能后，下一次强化30%","每5次数学技能后，下一次强化30%","每4次强化30%，并获得6%生命护盾"],
		"physics":["每层动量提升8%技能效果","每层动量提升12%技能效果","每层提升16%；满层忽略25%抗性"],
		"chemistry":["两种标记反应：60伤害＋减速","两种标记反应：100伤害＋减速","反应150伤害＋减速，并向邻敌传递"],
		"history":["1个补给节点：近邻每秒恢复1%生命","2个补给节点：近邻每秒恢复1%生命","3个节点：近邻治疗，节点可传承一次"],
		"literature":["每3次语文技能后，下一次回响25%","每3次语文技能后，下一次回响40%","每2次语文技能后，下一次回响50%"],
		"law":["3层证据：追加60伤害＋禁足1秒","3层证据：追加100伤害＋禁足1.2秒","2层证据：追加140伤害＋禁足1.5秒"],
		"guard":["守卫护甲和法抗＋15","守卫护甲和法抗＋30","守卫护甲和法抗＋50"],
		"fighter":["斗士生命＋15%","斗士生命＋28%","斗士生命＋45%"],
		"shooter":["第三次普攻追加40%攻击伤害","第三次普攻追加65%攻击伤害","第三次普攻追加90%攻击伤害"],
		"mage":["术师技能伤害＋15%","术师技能伤害＋25%","术师技能伤害＋40%"],
		"raider":["攻击未瞄准自己的敌人：增伤15%","攻击未瞄准自己的敌人：增伤25%","攻击未瞄准自己的敌人：增伤40%"],
		"support":["治疗与护盾＋15%","治疗与护盾＋25%","治疗与护盾＋40%"]}
	return rows[id][clampi(tier-1,0,2)]

func _wrapped(text: String, color: Color, font_size: int = 11) -> Label:
	var node := label(text,font_size,color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size.x = 190
	return node

func _refresh_traits() -> void:
	clear(faction_box)
	var entries: Array[Dictionary] = []
	var total_active := 0
	for f in ArtLibrary.data().factions:
		entries.append({"id":f.id,"name":f.name+" · "+f.title,"color":Color(f.color),"desc":f.desc})
	for id in ArtLibrary.data().roles:
		var d: Dictionary = ArtLibrary.data().roles[id]
		entries.append({"id":id,"name":d.name,"color":Color("c7d9c5"),"desc":d.desc})
	for e in entries:
		e.count = int(state.traits.get(e.id,0))
		e.tier = mini(3,int(e.count/2))
		if e.tier>0:
			total_active += 1
	entries.sort_custom(func(a,b): return a.tier>b.tier if a.tier!=b.tier else a.count>b.count)
	faction_box.add_child(label("已激活羁绊 · %d" % total_active,17,Color("dec58e")))
	faction_box.add_child(_wrapped("只计算上阵的不同角色；同名棋子不重复计数。",Color("8faeae"),10))
	if total_active==0:
		faction_box.add_child(_wrapped("尚未激活。上阵2种同学科或同职业角色可触发首档。",Color("c5d4c9")))
	for e in entries:
		if e.count==0:
			continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel",box_style(Color("263e39") if e.tier>0 else Color("152932"),e.color.darkened(0.4) if e.tier>0 else Color("32474f"),5))
		faction_box.add_child(panel)
		var v := VBoxContainer.new()
		panel.add_child(v)
		v.add_child(label(("● " if e.tier>0 else "○ ")+e.name+"  "+str(e.count),13,e.color))
		var stages: Array[String] = []
		for threshold in [2,4,6]:
			stages.append(("✓" if e.count>=threshold else "·")+str(threshold))
		v.add_child(label("  ".join(stages),11,Color("e6cf96") if e.tier>0 else Color("8fa7aa")))
		v.add_child(_wrapped(_trait_text(e.id,e.tier) if e.tier>0 else "未激活："+_trait_text(e.id,1),e.color if e.tier>0 else Color("91a7a8")))
		if e.tier<3:
			v.add_child(label("再上阵%d种 → %d档" % [(e.tier+1)*2-e.count,(e.tier+1)*2],10,Color("a4b5ac")))
		panel.tooltip_text = e.desc
	var has_dragon: bool = state.ownUnits.any(func(u): return int(u.id)==8 and u.c!=null)
	if int(state.traits.get("law",0))>=2:
		faction_box.add_child(label("法律羁绊 · 举证条件",13,Color("e8cf80")))
		faction_box.add_child(_wrapped("选择敌人做什么会累积证据；满层后由法律攻击触发裁决。",Color("b4c9c4")))
		var rule := OptionButton.new()
		for text in ["敌人施法时＋1证据","敌人每3次普攻＋1证据","敌人每移动2格＋1证据"]:
			rule.add_item(text)
		rule.select(["cast","attack","move"].find(state.rule))
		rule.disabled = state.phase!="prepare"
		rule.item_selected.connect(func(i): _send("strategy",{"rule":["cast","attack","move"][i]}))
		faction_box.add_child(rule)
	if has_dragon:
		faction_box.add_child(label("公理之龙 · 技能模式",13,Color("72d8db")))
		faction_box.add_child(_wrapped("只影响公理之龙施法：为全体数学角色选择一种效果。",Color("b4c9c4")))
		var axiom := OptionButton.new()
		for text in ["护盾：获得180基础护盾","成长：6秒内施法强化","净化：清除负面并治疗"]:
			axiom.add_item(text)
		axiom.select(["shield","growth","heal"].find(state.axiom))
		axiom.disabled = state.phase!="prepare"
		axiom.item_selected.connect(func(i): _send("strategy",{"axiom":["shield","growth","heal"][i]}))
		faction_box.add_child(axiom)

func _refresh_players() -> void:
	clear(players_box)
	players_box.add_child(label("八棋手 · 点击观战", 16, Color("dec58e")))
	for p in state.players:
		var b := button("%s    %d\nLv.%d · 金币%d" % [p.name, int(p.health), int(p.level), int(p.gold)], func(): _send("watch", {"player": p.id}), Vector2(180, 47))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 12)
		b.tooltip_text = str(p.intent)
		if state.watching == p.id:
			b.add_theme_stylebox_override("normal", box_style(Color("365347"), Color("d0bc80"), 5))
		if not p.alive:
			b.modulate.a = 0.45
		players_box.add_child(b)

func _make_slot(mode: String, value: Dictionary, editable: bool) -> UnitSlot:
	var slot := UnitSlot.new()
	slot.mode = mode
	slot.info = value
	slot.editable = editable
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.command_requested.connect(_send)
	slot.inspected.connect(func(info, at): inspect_position = at; _send("inspect", {"id": int(info.get("id", 0)), "uid": info.get("uid", ""), "player": "you"}))
	return slot

func _refresh_slots(preparing: bool) -> void:
	clear(bench_row)
	var caption := VBoxContainer.new()
	caption.custom_minimum_size.x = 146
	bench_row.add_child(caption)
	caption.add_child(label("备战席", 14, Color("d9c28d")))
	caption.add_child(label("拖回撤下 / 拖到棋子上交换", 10, Color("8ca7a9")))
	var bench: Array = state.ownUnits.filter(func(u): return u.c == null)
	for i in 9:
		bench_row.add_child(_make_slot("bench", bench[i] if i < bench.size() else {}, preparing))
	clear(item_row)
	var text := label("装备  → 拖给棋子", 12, Color("d6c38d"))
	text.custom_minimum_size.x = 146
	item_row.add_child(text)
	if state.bag.is_empty():
		item_row.add_child(label("战胜野怪后选择遗物；右键棋子可卸下装备。", 11, Color("88a6a8")))
	for i in state.bag.size():
		var id = state.bag[i]
		var item: Dictionary = ArtLibrary.data().items.filter(func(v): return v.id == id)[0].duplicate()
		item.index = i
		item_row.add_child(_make_slot("item", item, preparing))
	clear(shop_row)
	for offer in state.shop:
		shop_row.add_child(_make_slot("shop", offer, preparing and not offer.get("sold", false) and int(state.gold) >= int(offer.get("cost", 0))))

func _inspect_board(unit: Dictionary, at: Vector2) -> void:
	inspect_position = at
	var player_id: String = str(state.watching)
	var uid := str(unit.uid)
	if int(unit.team) == 1:
		player_id = str(state.get("enemyId", "enemy"))
	_send("inspect", {"id": int(unit.id), "uid": uid, "star": int(unit.star), "player": player_id})

func _show_detail(d: Dictionary) -> void:
	clear(popup_box)
	var head := HBoxContainer.new()
	popup_box.add_child(head)
	var title := label("棋子档案", 13, Color("dec58e"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(button("×", func(): popup.hide(); _send("close_inspect")))
	var hero := HBoxContainer.new()
	popup_box.add_child(hero)
	var image := TextureRect.new()
	image.texture = ArtLibrary.actor_frame(int(d.id), int(d.star))
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(125, 125)
	hero.add_child(image)
	var info := VBoxContainer.new()
	hero.add_child(info)
	info.add_child(label(str(d.name), 22,ArtLibrary.quality_color(int(d.cost))))
	info.add_child(label("%s · %d费"%[ArtLibrary.data().quality[int(d.cost)],int(d.cost)],12,ArtLibrary.quality_color(int(d.cost))))
	info.add_child(label("★".repeat(int(d.star)), 17, Color("ead08b")))
	info.add_child(label("生命 %d\n攻击 %d\n护甲 %d / 法抗 %d" % [int(d.stats.hp), int(d.stats.atk), int(d.stats.def), int(d.stats.mr)], 12))
	popup_box.add_child(label(str(d.skill), 16, Color("dec58e")))
	var description := label(str(d.desc), 13)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 305
	popup_box.add_child(description)
	if int(d.id) < 54:
		popup_box.add_child(button("查看三种星级外观与动作", func(): codex.show_character(int(d.id)); codex.show(); popup.hide(); _send("close_inspect")))
		popup_box.add_child(label("卡池剩余：%d 张" % int(d.pool), 11, Color("96b9b3")))
	if d.get("uid") != null and d.player == "you":
		var actions := HBoxContainer.new()
		popup_box.add_child(actions)
		actions.add_child(button("出售", func(): popup.hide(); _send("sell", {"uid": d.uid}); _send("close_inspect")))
		if d.item != null:
			popup_box.add_child(button("卸下装备", func(): _send("unequip", {"uid": d.uid}); _send("close_inspect")))
	popup.reset_size()
	popup.visible = true
	popup.position = Vector2(clampf(inspect_position.x + 15, 10, size.x - 355), clampf(inspect_position.y - 100, 55, size.y - 450))

func _refresh_result() -> void:
	var show_result: bool = state.phase in ["result", "victory", "defeat"] and state.watching == "you"
	result_panel.visible = show_result
	if not show_result:
		return
	clear(result_box)
	var result: Dictionary = state.result if state.result != null else {}
	var end: bool = state.phase in ["victory", "defeat"]
	var title := "本轮胜利" if result.get("won", false) else "调整阵容，再战一局"
	if end:
		title = "联赛结束 · 第 %d 名" % int(result.get("rank", 8))
	var headline := label(title, 28, Color("e4c98e"))
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_box.add_child(headline)
	result_box.add_child(label("金币 +%d    经验 +2    损失生命 %d" % [int(result.get("reward", 0)), int(result.get("damage", 0))], 15))
	if result.get("mvp",[]).size()>0:
		var learned := ArtLibrary.character(int(result.mvp[0].id))
		if learned.has("fact"):
			var snippet := label("这一局顺便知道了 · "+str(learned.concept)+"\n"+str(learned.fact),12,Color("a9cdb9"))
			snippet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			snippet.custom_minimum_size.x = 490
			result_box.add_child(snippet)

	if not state.pendingLoot.is_empty():
		result_box.add_child(label("野怪掉落 · 选择一件遗物", 18, Color("a9d6bd")))
		var items := HBoxContainer.new()
		items.add_theme_constant_override("separation", 10)
		result_box.add_child(items)
		for id in state.pendingLoot:
			var item: Dictionary = ArtLibrary.data().items.filter(func(v): return v.id == id)[0]
			var choice := VBoxContainer.new()
			choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			items.add_child(choice)
			var icon := TextureRect.new()
			icon.texture = ArtLibrary.item_frame(str(id))
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(90, 90)
			choice.add_child(icon)
			choice.add_child(button(str(item.name) + "\n" + str(item.desc), func(): _send("loot", {"item": id}), Vector2(155, 70)))
	else:
		result_box.add_child(button("选择难度，开始新联赛" if end else "进入下一轮", func():
			if end:
				result_panel.hide()
				menu.show()
				_build_menu()
			else:
				_send("next")
		, Vector2(0, 42)))
	_place_overlays()

func _place_overlays() -> void:
	if codex != null:
		codex.size = Vector2(minf(1190, size.x - 50), minf(740, size.y - 70))
		codex.position = (size - codex.size) * 0.5
	if menu != null:
		menu.size = Vector2(700, 340)
		menu.position = (size - menu.size) * 0.5
	if help_panel != null:
		help_panel.size = Vector2(700, 500)
		help_panel.position = (size - help_panel.size) * 0.5
	if result_panel != null:
		result_panel.size = Vector2(540, 240)
		result_panel.position = Vector2((size.x - 540) * 0.5, maxf(90, (size.y - 420) * 0.5))
	if toast != null:
		toast.position = Vector2(100, size.y - 310)
		toast.size = Vector2(size.x - 200, 35)

func _toast(text: String, error: bool = false) -> void:
	if toast == null:
		return
	toast.text = text
	toast.modulate = Color("edb2a4") if error else Color("eed7a0")
	toast.visible = true
	toast_time = 2.8

func _play_sound(kind: String) -> void:
	if not sound_enabled:
		return
	var frequencies := {"buy": 520.0, "merge": 880.0, "level": 740.0, "win": 660.0, "lose": 180.0, "loot": 960.0, "equip": 620.0, "legendary": 1174.0, "roll": 330.0, "move": 400.0}
	if not frequencies.has(kind):
		return
	var hz: float = frequencies[kind]
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var samples := PackedByteArray()
	var count := 4400 if kind in ["merge", "win", "loot"] else 1800
	samples.resize(count * 2)
	for i in count:
		var t := float(i) / 22050.0
		var envelope := sin(PI * float(i) / count) * (1.0 - float(i) / count)
		var value := int(sin(TAU * hz * t) * envelope * 3800)
		samples.encode_s16(i * 2, value)
	wav.data = samples
	audio.stream = wav
	audio.play()

func _process(delta: float) -> void:
	toast_time -= delta
	if toast != null and toast_time <= 0:
		toast.hide()
	if not qa_capture.is_empty() and not state.is_empty() and not qa_capturing:
		qa_ticks += 1
		if qa_ticks == 5:
			_send("new", {"difficulty": "hard"})
		elif qa_ticks == 20:
			for slot in [0, 1, 3, 2]:
				_send("buy", {"slot": slot})
		elif qa_ticks == 40:
			board.stage.yaw=qa_scene_angle
			board.stage._set_camera()
			_send("refresh")
			if qa_demo != -1:
				_send("preview_battle" if qa_demo<0 else "preview_skill", {"id":qa_demo})
			elif qa_battle:
				_send("start")
		elif qa_ticks == 90 and qa_codex:
			codex.show_character(0)
			codex.show()
		elif (qa_capture_cue.is_empty() and qa_ticks == (300 if qa_battle else 120)) or (not qa_capture_cue.is_empty() and qa_ticks>50 and state.board.effects.any(func(e): return e.type==qa_capture_cue and float(state.board.time)-float(e.born)>float(e.life)*0.45)) or qa_ticks==600:
			qa_capturing = true
			toast.hide()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(qa_capture)
			if board.stage!=null and board.stage.field_view!=null:
				board.stage.field_view.get_texture().get_image().save_png(qa_capture.get_basename()+"-fields.png")
			print("CAPTURE_SAVED " + qa_capture)
			print("RENDER_FPS " + str(Engine.get_frames_per_second()))
			if not qa_sequence.is_empty():
				while qa_recording:await get_tree().process_frame
				var recording:=FileAccess.open(qa_sequence.path_join("frames.json"),FileAccess.WRITE)
				recording.store_string(JSON.stringify(qa_sequence_frames))
			get_tree().quit()
		if not qa_sequence.is_empty() and qa_ticks >= 60 and qa_ticks < 300 and qa_ticks % 2 == 0 and not qa_recording:
			qa_recording=true
			var frame_name:="frame-%03d.jpg"%qa_sequence_frames.size()
			await RenderingServer.frame_post_draw
			qa_sequence_frames.append({"file":frame_name,"time":Time.get_ticks_msec()/1000.0})
			get_viewport().get_texture().get_image().save_jpg(qa_sequence.path_join(frame_name),0.90)
			qa_recording=false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and popup.visible:
		if not popup.get_global_rect().has_point(get_global_mouse_position()):
			popup.hide()
			_send("close_inspect")
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if get_viewport().gui_is_dragging():
				get_viewport().gui_cancel_drag()
			codex.hide()
			popup.hide()
			help_panel.hide()
			if not first_state:
				menu.hide()
		elif not menu.visible and not help_panel.visible and not codex.visible:
			if event.keycode == KEY_D:
				_send("refresh")
			elif event.keycode == KEY_F:
				_send("xp")
			elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
				_send("buy", {"slot": event.keycode - KEY_1})
