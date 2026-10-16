extends Node2D

var source: Node2D
var board: BattleBoard
var data: Dictionary:
	get: return source.data
var active: Array:
	get: return source.active
var clock: float:
	get: return source.clock

func unit(uid: String) -> Dictionary:
	return source.unit(uid)

func _ready() -> void:
	board=BattleBoard.new()
	board.geometry_only=true
	board.size=Vector2(768,1024)
	add_child(board)
	var fields: Node2D = load("res://scripts/fields.gd").new()
	fields.manager=self
	add_child(fields)

func _process(_delta: float) -> void:
	board.selected_uid=source.board.selected_uid
	queue_redraw()
	for child in get_children():
		if child is Node2D:child.queue_redraw()
