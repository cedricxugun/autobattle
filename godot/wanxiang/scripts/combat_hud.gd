extends Node2D
var manager: Node2D
func _draw() -> void:
	if manager != null:
		manager._draw_notices(self)
		manager._draw_focus(self)
		manager._draw_legendary_banner(self)
