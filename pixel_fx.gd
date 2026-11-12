class_name PixelFx
extends RefCounted

# Pixel-art versions of the drawing calls the effects use. Everything is built from 3 px squares (the same size
# as the sprites' pixels): discs and rings come from small cached pictures, lines from rows of squares.

const U := 3.0
static var _discs: Dictionary = {}
static var _rings: Dictionary = {}

static func _disc_tex(rc: int) -> Texture2D:
	if not _discs.has(rc):
		var n := rc * 2
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in n:
			for x in n:
				if Vector2(float(x) + 0.5 - float(rc), float(y) + 0.5 - float(rc)).length() <= float(rc):
					img.set_pixel(x, y, Color.WHITE)
		_discs[rc] = ImageTexture.create_from_image(img)
	return _discs[rc]

static func _ring_tex(rc: int, thick: int) -> Texture2D:
	var key := rc * 100 + thick
	if not _rings.has(key):
		var n := rc * 2
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in n:
			for x in n:
				var d := Vector2(float(x) + 0.5 - float(rc), float(y) + 0.5 - float(rc)).length()
				if d <= float(rc) and d > float(rc - thick):
					img.set_pixel(x, y, Color.WHITE)
		_rings[key] = ImageTexture.create_from_image(img)
	return _rings[key]

static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var rc := maxi(roundi(r / U), 1)
	if rc > 80:
		# too big for a cached picture: rows of squares
		for j in range(-rc, rc):
			var half := sqrt(maxf(float(rc * rc) - (float(j) + 0.5) * (float(j) + 0.5), 0.0))
			var w := floorf(half) * 2.0 * U
			ci.draw_rect(Rect2(Vector2(roundf(c.x / U) * U - w * 0.5, roundf(c.y / U) * U + float(j) * U), Vector2(w, U)), col)
		return
	ci.draw_texture_rect(_disc_tex(rc), Rect2(c - Vector2(rc, rc) * U, Vector2(rc, rc) * 2.0 * U), false, col)

# thick in px
static func ring(ci: CanvasItem, c: Vector2, r: float, col: Color, thick: float = 3.0) -> void:
	var rc := maxi(roundi(r / U), 2)
	if rc > 80:
		arc(ci, c, r, 0.0, TAU, col, thick)
		return
	ci.draw_texture_rect(_ring_tex(rc, maxi(roundi(thick / U), 1)), Rect2(c - Vector2(rc, rc) * U, Vector2(rc, rc) * 2.0 * U), false, col)

static func square(ci: CanvasItem, c: Vector2, size: float, col: Color) -> void:
	var s := maxf(roundf(size / U), 1.0) * U
	ci.draw_rect(Rect2(Vector2(roundf((c.x - s * 0.5) / U) * U, roundf((c.y - s * 0.5) / U) * U), Vector2(s, s)), col)

static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float = 3.0) -> void:
	var s := maxf(roundf(width / U), 1.0) * U
	var n := maxi(int(a.distance_to(b) / U), 1)
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		ci.draw_rect(Rect2(Vector2(roundf(p.x / U) * U - s * 0.5, roundf(p.y / U) * U - s * 0.5), Vector2(s, s)), col)

static func arc(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color, width: float = 3.0) -> void:
	var s := maxf(roundf(width / U), 1.0) * U
	var n := maxi(int(r * absf(a1 - a0) / U), 2)
	for i in n + 1:
		var p := c + Vector2.RIGHT.rotated(lerpf(a0, a1, float(i) / float(n))) * r
		ci.draw_rect(Rect2(Vector2(roundf(p.x / U) * U - s * 0.5, roundf(p.y / U) * U - s * 0.5), Vector2(s, s)), col)

static func polyline_colors(ci: CanvasItem, pts: PackedVector2Array, cols: PackedColorArray) -> void:
	for i in pts.size() - 1:
		line(ci, pts[i], pts[i + 1], cols[i], 3.0)
