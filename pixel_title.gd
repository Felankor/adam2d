class_name PixelTitle
extends Control

# A menu heading in the HUD's style: gold pixel lettering with a hard outline, flanked by bronze rails that end in rivets,
# with a small diamond next to the text.
var text: String = ""
var font_px: int = 40
var color: Color = PixelUI.GOLD

static func make(t: String, px: int = 40, col: Color = PixelUI.GOLD) -> PixelTitle:
	var p := PixelTitle.new()
	p.text = t
	p.font_px = px
	p.color = col
	var tw := PixelUI.ui_font().get_string_size(Loc.t(t), HORIZONTAL_ALIGNMENT_LEFT, -1, PixelUI.mfs(px)).x
	p.custom_minimum_size = Vector2(tw + 170.0, float(PixelUI.mfs(px)) + 30.0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _draw() -> void:
	var w := size.x
	var h := size.y
	var shown := Loc.t(text)
	var fsz := PixelUI.mfs(font_px)
	var tw := PixelUI.ui_font().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
	var cy := h * 0.5
	PixelUI.text(self, Vector2(0.0, cy + float(fsz) * 0.35), shown, font_px, color, HORIZONTAL_ALIGNMENT_CENTER, w, 6)
	var gap := tw * 0.5 + 34.0
	for sgn in [-1.0, 1.0]:
		var x0: float = w * 0.5 + sgn * gap
		var x1: float = w * 0.5 + sgn * (w * 0.5 - 10.0)
		var a := minf(x0, x1)
		var b := maxf(x0, x1)
		if b - a > 14.0:
			draw_rect(Rect2(a, cy - 5.0, b - a, 2.0), Color(0.08, 0.04, 0.03))
			draw_rect(Rect2(a, cy - 3.0, b - a, 3.0), Color(0.92, 0.78, 0.47))
			draw_rect(Rect2(a, cy, b - a, 3.0), Color(0.5, 0.31, 0.14))
			draw_rect(Rect2(a, cy + 3.0, b - a, 2.0), Color(0.08, 0.04, 0.03))
			# rivet on the far end
			var rx: float = x1 - (6.0 if sgn > 0.0 else 0.0)
			draw_rect(Rect2(rx - 3.0, cy - 6.0, 12.0, 12.0), Color(0.08, 0.04, 0.03))
			draw_rect(Rect2(rx - 1.0, cy - 4.0, 8.0, 8.0), Color(0.33, 0.2, 0.1))
			draw_rect(Rect2(rx - 1.0, cy - 4.0, 4.0, 4.0), Color(0.92, 0.78, 0.47))
		# diamond beside the text
		var dx: float = w * 0.5 + sgn * (gap - 14.0)
		var d := PackedVector2Array([Vector2(dx - 9.0, cy), Vector2(dx, cy - 9.0), Vector2(dx + 9.0, cy), Vector2(dx, cy + 9.0)])
		draw_colored_polygon(d, Color(0.08, 0.04, 0.03))
		var d2 := PackedVector2Array([Vector2(dx - 6.0, cy), Vector2(dx, cy - 6.0), Vector2(dx + 6.0, cy), Vector2(dx, cy + 6.0)])
		draw_colored_polygon(d2, Color(0.85, 0.65, 0.2))
