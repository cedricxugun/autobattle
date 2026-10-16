class_name EvolutionCodex
extends PanelContainer

signal demonstrate(id: int)
var action_selector := OptionButton.new()
var title := Label.new()
var description := Label.new()
var portraits: Array[TextureRect] = []
var grid := GridContainer.new()
var search := LineEdit.new()
var role_filter := OptionButton.new()
var cost_filter := OptionButton.new()
var genre_filter := OptionButton.new()
var knowledge := RichTextLabel.new()
var source_button := LinkButton.new()
var source_url := ""
var count_label := Label.new()
var selected_id := 0
var selected_faction := "all"
var elapsed := 0.0
var pose := "idle"
var sequence := {"idle":[0],"walk":[1,2,3,4],"attack":[5,5,6,7,0,0],"cast":[5,5,5,6,6,7,0,0],"hurt":[8,0,0],"death":[8]}

func text_label(text: String, font_size: int = 13) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",font_size)
	return node

func _ready() -> void:
	z_index = 170
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",12)
	add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var caption := text_label("万象图鉴 · 学科 / 职业 / 品质",24)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(caption)
	var close := Button.new()
	close.text = "返回棋局 ×"
	close.pressed.connect(hide)
	heading.add_child(close)
	var tabs := HBoxContainer.new()
	layout.add_child(tabs)
	var schools: Array = [{"id":"all","name":"全部"}]+ArtLibrary.data().factions+[{"id":"wild","name":"野怪"}]
	for f in schools:
		var tab := Button.new()
		tab.text = f.name
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func(): selected_faction=f.id; _populate())
		tabs.add_child(tab)
	var filters := HBoxContainer.new()
	layout.add_child(filters)
	search.placeholder_text = "搜索角色 / 技能"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_text): _populate())
	filters.add_child(search)
	role_filter.add_item("全部职业")
	for key in ArtLibrary.data().roles:
		role_filter.add_item(ArtLibrary.data().roles[key].name)
	role_filter.item_selected.connect(func(_i): _populate())
	filters.add_child(role_filter)
	cost_filter.add_item("全部品质")
	for i in range(1,6):
		cost_filter.add_item("%d费 · %s" % [i,ArtLibrary.data().quality[i]])
	cost_filter.item_selected.connect(func(_i): _populate())
	filters.add_child(cost_filter)
	for genre in ["全部题材","童话","戏剧","诗歌","传说","爱情","文字游戏"]:
		genre_filter.add_item(genre)
	genre_filter.tooltip_text = "题材标签用于查找角色，不是额外羁绊。"
	genre_filter.item_selected.connect(func(_i): _populate())
	filters.add_child(genre_filter)
	filters.add_child(count_label)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation",18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x = 490
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",7)
	grid.add_theme_constant_override("v_separation",7)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 490
	body.add_child(detail)
	title.add_theme_font_size_override("font_size",23)
	detail.add_child(title)
	var controls := HBoxContainer.new()
	detail.add_child(controls)
	for text in ["待机","移动","普攻","施法","受击","死亡"]:
		action_selector.add_item(text)
	action_selector.item_selected.connect(func(index): pose=["idle","walk","attack","cast","hurt","death"][index];elapsed=0)
	controls.add_child(action_selector)
	var demo := Button.new()
	demo.text = "技能实战演示 →"
	demo.pressed.connect(func(): demonstrate.emit(selected_id); hide())
	controls.add_child(demo)
	var stress := Button.new()
	stress.text = "8对8演练"
	stress.pressed.connect(func(): demonstrate.emit(-2); hide())
	controls.add_child(stress)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(row)
	for tier in 3:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		var portrait := TextureRect.new()
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(145,155)
		portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(portrait)
		portraits.append(portrait)
		var stars := text_label("★".repeat(tier+1)+" · "+["初生","觉醒","升华"][tier])
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(stars)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(490,125)
	var tabs_detail := TabContainer.new()
	tabs_detail.custom_minimum_size = Vector2(490,195)
	detail.add_child(tabs_detail)
	var skill_page := VBoxContainer.new()
	skill_page.name = "技能与性格"
	tabs_detail.add_child(skill_page)
	skill_page.add_child(description)
	var notes_page := VBoxContainer.new()
	notes_page.name = "为什么这样演"
	tabs_detail.add_child(notes_page)
	knowledge.bbcode_enabled = true
	knowledge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	knowledge.custom_minimum_size = Vector2(470,125)
	notes_page.add_child(knowledge)
	source_button.text = "阅读知识来源 ↗"
	source_button.pressed.connect(func():
		if source_url.begins_with("https://"):
			OS.shell_open(source_url)
	)
	notes_page.add_child(source_button)
	detail.add_child(text_label("3张一星 → 二星；3张二星 → 三星。
实战演示不消耗金币，不改变当前联赛。",12))
	_populate()
	show_character(0)

func _populate() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	var roles: Array = ArtLibrary.data().roles.keys()
	var characters: Array = ArtLibrary.data().characters+ArtLibrary.data().monsters
	var visible_count := 0
	for d in characters:
		if genre_filter.selected>0 and not d.get("genres",[]).has(genre_filter.get_item_text(genre_filter.selected)):
			continue
		if selected_faction!="all" and d.faction!=selected_faction:
			continue
		if role_filter.selected>0 and d.role!=roles[role_filter.selected-1]:
			continue
		if cost_filter.selected>0 and int(d.get("cost",0))!=cost_filter.selected:
			continue
		if not search.text.is_empty() and not (str(d.name)+str(d.skill)+str(d.get("concept",""))+str(d.get("genres",[]))).contains(search.text):
			continue
		visible_count += 1
		var card := Button.new()
		card.custom_minimum_size = Vector2(112,112)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = str(d.skill)+"
"+str(d.desc)
		card.pressed.connect(func(): show_character(int(d.id)))
		grid.add_child(card)
		var column := VBoxContainer.new()
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(column)
		var image := TextureRect.new()
		image.texture = ArtLibrary.actor_frame(int(d.id),1,0)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(90,76)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(image)
		var caption := text_label(str(d.name),12)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.modulate = ArtLibrary.faction_color(str(d.faction))
		column.add_child(caption)
		var sub := text_label(("野怪" if int(d.id)>=54 else "%d费" % int(d.cost))+" · "+str(ArtLibrary.data().roles[d.role].name),10)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(sub)
	count_label.text = "%d 个角色" % visible_count

func show_character(id: int) -> void:
	selected_id = clampi(id,0,62)
	elapsed = 0
	var d := ArtLibrary.character(selected_id)
	title.text = str(d.name)
	title.modulate = ArtLibrary.faction_color(str(d.faction))
	description.text = str(d.skill)+"\n\n"+str(d.desc)+("\n\n"+str(d.joke) if d.has("joke") else "")+("\n野怪没有合成升星。" if id>=54 else "")
	knowledge.text = "[b]"+str(d.get("concept","知识异变"))+"[/b]\n\n"+str(d.get("fact","野怪是本作虚构的关卡角色。"))+"\n\n[color=#baa98c]游戏改编：[/color]"+str(d.get("adaptation","技能与数值为游戏设计。"))
	source_url = str(d.get("source_url",""))
	source_button.visible = not source_url.is_empty()
	source_button.tooltip_text = str(d.get("source_title",""))
	_update_portraits()

func _update_portraits() -> void:
	var frames: Array = sequence[pose]
	var frame: int = frames[int(elapsed*8)%frames.size()]
	for tier in portraits.size():
		var portrait := portraits[tier]
		portrait.texture = ArtLibrary.actor_frame(selected_id,tier+1,frame)
		portrait.pivot_offset = portrait.size*Vector2(0.5,0.8)
		portrait.scale = Vector2(1,1+sin(elapsed*2.5)*0.014) if pose=="idle" else Vector2.ONE
		portrait.modulate.a = 1-clampf(fmod(elapsed,2)/1.0,0,1) if pose=="death" else 1.0

func _process(delta: float) -> void:
	if visible:
		elapsed += delta
		_update_portraits()
