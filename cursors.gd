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

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func _make_crosshair() -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(15.5, 15.5)
	var segs: Array = [
		[Vector2(2.5, 15.5), Vector2(11.0, 15.5)],
		[Vector2(20.0, 15.5), Vector2(28.5, 15.5)],
		[Vector2(15.5, 2.5), Vector2(15.5, 11.0)],
		[Vector2(15.5, 20.0), Vector2(15.5, 28.5)],
	]
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c) - 1.4
			for seg in segs:
				d = minf(d, _seg_dist(p, seg[0], seg[1]) - 0.5)
			if d <= 0.9:
				img.set_pixel(x, y, Color(0.85, 1.0, 0.85))
			elif d <= 2.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.85))
	return ImageTexture.create_from_image(img)

static func _make_aggressive() -> ImageTexture:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(23.5, 23.5)
	var segs: Array = [
		[c + Vector2(0, -8), c + Vector2(0, -22)],
		[c + Vector2(0, 8), c + Vector2(0, 22)],
		[c + Vector2(-8, 0), c + Vector2(-22, 0)],
		[c + Vector2(8, 0), c + Vector2(22, 0)],
		[c + Vector2(-13, -13), c + Vector2(-19, -19)],
		[c + Vector2(13, -13), c + Vector2(19, -19)],
		[c + Vector2(-13, 13), c + Vector2(-19, 19)],
		[c + Vector2(13, 13), c + Vector2(19, 19)],
	]
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := absf(p.distance_to(c) - 14.0) - 0.6
			d = minf(d, p.distance_to(c) - 2.4)
			for seg in segs:
				d = minf(d, _seg_dist(p, seg[0], seg[1]) - 0.8)
			if d <= 0.9:
				img.set_pixel(x, y, Color(1.0, 0.15, 0.1))
			elif d <= 2.2:
				img.set_pixel(x, y, Color(0, 0, 0, 0.85))
	return ImageTexture.create_from_image(img)
