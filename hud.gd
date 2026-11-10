class_name Hud
extends Control

var base: Base

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if base == null:
		return
	var s := get_viewport_rect().size
	var w := 320.0
	var h := 20.0
	var x := (s.x - w) * 0.5
	var hp_text := "Health %d / %d" % [base.hp, base.max_hp]
	var en_text := "Energy %d / %d" % [int(base.energy), int(base.max_energy)]
	_bar(Vector2(x, s.y - 34.0), Vector2(w, h), float(base.hp) / base.max_hp, Color.LIME_GREEN, hp_text)
	_bar(Vector2(x, s.y - 62.0), Vector2(w, h), base.energy / base.max_energy, Color.ORANGE, en_text)

func _bar(pos: Vector2, bar_size: Vector2, ratio: float, color: Color, text: String) -> void:
	draw_rect(Rect2(pos, bar_size), Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(pos, Vector2(bar_size.x * clampf(ratio, 0.0, 1.0), bar_size.y)), color)
	draw_rect(Rect2(pos, bar_size), Color(1, 1, 1, 0.6), false, 2.0)
	var font := ThemeDB.fallback_font
	var text_pos := pos + Vector2(8, bar_size.y - 5)
	draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
