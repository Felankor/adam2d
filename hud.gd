class_name Hud
extends Control

var base: Base
var coins: int = 0

const SLOT := 64.0
const GAP := 10.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if base == null:
		return
	var s := Settings.WORLD_SIZE
	_draw_coins(s)
	var w := 440.0
	var h := 28.0
	var x := (s.x - w) * 0.5
	var hp_text := "Health %d / %d" % [ceili(base.hp), ceili(base.max_hp)]
	var en_text := "Energy %d / %d" % [int(base.energy), int(base.max_energy)]
	_bar(Vector2(x, s.y - 160.0), Vector2(w, h), base.energy / base.max_energy, Color.ORANGE, en_text)
	_bar(Vector2(x, s.y - 126.0), Vector2(w, h), base.hp / base.max_hp, Color.LIME_GREEN, hp_text)
	_draw_skills(s)

func _text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _bar(pos: Vector2, bar_size: Vector2, ratio: float, color: Color, text: String) -> void:
	draw_rect(Rect2(pos, bar_size), Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(pos, Vector2(bar_size.x * clampf(ratio, 0.0, 1.0), bar_size.y)), color)
	draw_rect(Rect2(pos, bar_size), Color(1, 1, 1, 0.7), false, 2.0)
	_text(pos + Vector2(10, bar_size.y - 8), text, 18, Color.WHITE)

func _draw_coins(s: Vector2) -> void:
	var pos := Vector2(s.x - 230.0, 24.0)
	draw_texture_rect(CoinTex.get_texture(), Rect2(pos, Vector2(42, 42)), false)
	_text(pos + Vector2(56, 33), "x %d" % coins, 32, Color(1.0, 0.9, 0.3))

func _draw_skills(s: Vector2) -> void:
	var total := SLOT * 4.0 + GAP * 3.0
	var x0 := (s.x - total) * 0.5
	var y := s.y - 92.0
	for i in 4:
		var r := Rect2(x0 + i * (SLOT + GAP), y, SLOT, SLOT)
		var id := base.skill_slots[i]
		var active := id == "barrier" and base.barrier_time > 0.0
		draw_rect(r, Color(0.08, 0.09, 0.13, 0.9))
		if id != "":
			_draw_skill_icon(id, r)
			var cd := base.skill_cd[i]
			if cd > 0.0:
				draw_rect(r, Color(0, 0, 0, 0.6))
				var fill_h := SLOT * (1.0 - cd / base.skill_cd_max[i])
				draw_rect(Rect2(r.position.x, r.end.y - fill_h, SLOT, fill_h), Color(1, 1, 1, 0.12))
				_text(r.get_center() + Vector2(-8, 10), str(ceili(cd)), 26, Color.WHITE)
			if active:
				_text(r.position + Vector2(8, SLOT - 6), "%.1f" % base.barrier_time, 18, Color(0.5, 1.0, 1.0))
		var border := Color(1, 1, 1, 0.2)
		if active:
			border = Color(0.3, 1.0, 1.0)
		elif id != "":
			border = Color(1, 1, 1, 0.6)
		draw_rect(r, border, false, 3.0 if active else 2.0)
		_text(r.position + Vector2(6, 18), Keybinds.key_text("skill_%d" % (i + 1)), 16, Color(1.0, 0.9, 0.5))

func _draw_skill_icon(id: String, r: Rect2) -> void:
	var c := r.get_center()
	var h := r.size.y
	match id:
		"barrier":
			var pts := PackedVector2Array([
				c + Vector2(-0.30, -0.28) * h, c + Vector2(0.30, -0.28) * h,
				c + Vector2(0.32, 0.04) * h, c + Vector2(0.0, 0.36) * h,
				c + Vector2(-0.32, 0.04) * h,
			])
			draw_colored_polygon(pts, Color(0.25, 0.75, 1.0))
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(c + (p - c) * 0.6)
			draw_colored_polygon(inner, Color(0.6, 0.92, 1.0))
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, Color.WHITE, 2.5)
