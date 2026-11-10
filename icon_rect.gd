class_name IconRect
extends Control

# A Control that shows one icon from the Icons library.
var kind: String = ""
var with_bg: bool = true

func _init() -> void:
	custom_minimum_size = Vector2(72, 72)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_kind(k: String) -> void:
	kind = k
	queue_redraw()

func _draw() -> void:
	Icons.draw(self, kind, Vector2.ZERO, size.x / 64.0, with_bg)
