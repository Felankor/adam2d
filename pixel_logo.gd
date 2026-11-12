class_name PixelLogo
extends Control

# The game logo: chunky pixel letters with a stepped 3D extrusion, a gold face and a darker lower lip.
const LINES := ["CASTLE", "IN THE SKY"]
const SIZES := [80, 50]

func _init() -> void:
	custom_minimum_size = Vector2(700, 230)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var f := PixelUI.font()
	var y := 78.0
	for li in LINES.size():
		var txt: String = LINES[li]
		var sz: int = SIZES[li]
		var w := size.x
		var step := float(sz) / 10.0          # one font pixel
		var base := Vector2(0.0, y)
		# extrusion going down and to the right, darker the deeper it goes
		for i in range(5, 0, -1):
			var c := Color(0.10, 0.09, 0.30).lerp(Color(0.28, 0.30, 0.72), 1.0 - float(i) / 5.0)
			draw_string(f, base + Vector2(step * float(i), step * float(i)), txt, HORIZONTAL_ALIGNMENT_CENTER, w, sz, c)
		draw_string_outline(f, base + Vector2(step * 3.0, step * 3.0), txt, HORIZONTAL_ALIGNMENT_CENTER, w, sz, int(step * 2.0), PixelUI.OUTLINE)
		draw_string(f, base + Vector2(0.0, step), txt, HORIZONTAL_ALIGNMENT_CENTER, w, sz, Color(0.85, 0.5, 0.1))
		draw_string(f, base, txt, HORIZONTAL_ALIGNMENT_CENTER, w, sz, Color(1.0, 0.9, 0.45))
		# a few glints
		var gx := w * 0.5 + (-140.0 if li == 0 else 90.0)
		draw_rect(Rect2(gx, y - float(sz) * 0.62, step, step), Color(1, 1, 1, 0.9))
		draw_rect(Rect2(gx - step, y - float(sz) * 0.62 + step * 0.5, step * 3.0, step * 0.5 + 1.0), Color(1, 1, 1, 0.5))
		y += float(sz) * 1.15 + 14.0
