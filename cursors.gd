class_name Cursors
extends RefCounted

# Mouse pointers are drawn in code: a small crosshair, and a more
# aggressive red one while hovering an enemy.
enum Mode { ARROW, CROSSHAIR, AGGRESSIVE }

static var _mode: int = -1
static var _cross: ImageTexture
static var _aggr: ImageTexture

static func set_mode(mode: int) -> void:
	if mode == _mode:
		return
	_mode = mode
	match mode:
		Mode.CROSSHAIR:
			if _cross == null:
				_cross = _make_crosshair()
			Input.set_custom_mouse_cursor(_cross, Input.CURSOR_ARROW, Vector2(16, 16))
		Mode.AGGRESSIVE:
			if _aggr == null:
				_aggr = _make_aggressive()
			Input.set_custom_mouse_cursor(_aggr, Input.CURSOR_ARROW, Vector2(24, 24))
		_:
			Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

# Pixel cursors: painted on a small grid and shown at 2x, with a dark outline.
static func _blit(img: Image, x: int, y: int, col: Color, s: int) -> void:
	for j in s:
		for i in s:
			var xx := x * s + i
			var yy := y * s + j
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, col)

static func _paint(grid: Array, n: int, s: int, fill: Color) -> ImageTexture:
	# grid = list of Vector2i pixels; every filled pixel gets a dark ring around it
	var img := Image.create(n * s, n * s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := Color(0.04, 0.03, 0.08, 0.95)
	for p: Vector2i in grid:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			_blit(img, p.x + d.x, p.y + d.y, dark, s)
	for p: Vector2i in grid:
		_blit(img, p.x, p.y, fill, s)
	return ImageTexture.create_from_image(img)

static func _make_crosshair() -> ImageTexture:
	var px: Array = []
	var c := 8
	for i in range(1, 4):
		px.append(Vector2i(c - 2 - i, c))
		px.append(Vector2i(c + 2 + i, c))
		px.append(Vector2i(c, c - 2 - i))
		px.append(Vector2i(c, c + 2 + i))
	px.append(Vector2i(c, c))
	return _paint(px, 16, 2, Color(0.85, 1.0, 0.85))

static func _make_aggressive() -> ImageTexture:
	var px: Array = []
	var c := 12
	for a in 48:
		var ang := TAU * float(a) / 48.0
		px.append(Vector2i(c + roundi(cos(ang) * 7.0), c + roundi(sin(ang) * 7.0)))
	for i in range(3, 6):
		px.append(Vector2i(c, c - 4 - i))
		px.append(Vector2i(c, c + 4 + i))
		px.append(Vector2i(c - 4 - i, c))
		px.append(Vector2i(c + 4 + i, c))
	px.append(Vector2i(c, c))
	px.append(Vector2i(c + 1, c))
	px.append(Vector2i(c, c + 1))
	px.append(Vector2i(c + 1, c + 1))
	return _paint(px, 24, 2, Color(1.0, 0.2, 0.12))
