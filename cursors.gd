class_name Cursors
extends RefCounted

# Mouse pointers are drawn in code: a small crosshair, and a more
# aggressive red one while hovering an enemy.
enum Mode { ARROW, CROSSHAIR, AGGRESSIVE }

static var _mode: int = -1
const FRAMES := 12
const FPS := 4.0          # each cursor swap costs several ms on Windows, so the animation is slow on purpose
static var _cross: Array = []        # animated frames (ImageTexture)
static var _aggr: Array = []
static var _frame: int = -1

static func set_mode(mode: int) -> void:
	if mode == _mode:
		return
	_mode = mode
	match mode:
		Mode.CROSSHAIR:
			if _cross.is_empty():
				for f in FRAMES:
					_cross.append(_make_crosshair(f))
			_frame = -1
			tick()
		Mode.AGGRESSIVE:
			if _aggr.is_empty():
				for f in FRAMES:
					_aggr.append(_make_aggressive(f))
			_frame = -1
			tick()
		_:
			Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

# Call every frame: plays the cursor animation (a swap of 12 prepared frames).
static func tick() -> void:
	if _mode != Mode.CROSSHAIR and _mode != Mode.AGGRESSIVE:
		return
	var f := int(Time.get_ticks_msec() / 1000.0 * FPS) % FRAMES
	if f == _frame:
		return
	_frame = f
	if _mode == Mode.CROSSHAIR:
		Input.set_custom_mouse_cursor(_cross[f], Input.CURSOR_ARROW, Vector2(33, 33))
	else:
		Input.set_custom_mouse_cursor(_aggr[f], Input.CURSOR_ARROW, Vector2(41, 41))

# Pixel cursors: painted on a grid and shown at 2x. Every pixel gets a dark ring; items are [Vector2i, Color].
static func _blit(img: Image, x: int, y: int, col: Color, s: int) -> void:
	for j in s:
		for i in s:
			var xx := x * s + i
			var yy := y * s + j
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, col)

static func _paint(items: Array, n: int, s: int) -> ImageTexture:
	var img := Image.create(n * s, n * s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := Color(0.04, 0.03, 0.08, 0.95)
	for it: Array in items:
		var p: Vector2i = it[0]
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			_blit(img, p.x + d.x, p.y + d.y, dark, s)
	for it: Array in items:
		_blit(img, (it[0] as Vector2i).x, (it[0] as Vector2i).y, it[1], s)
	return ImageTexture.create_from_image(img)

static func _dot(items: Array, x: int, y: int, col: Color, size: int = 1) -> void:
	for j in size:
		for i in size:
			items.append([Vector2i(x + i, y + j), col])

# 64x64 px: breathing arms, a bright centre and four orbiting beads (one quarter turn per loop).
static func _make_crosshair(f: int) -> ImageTexture:
	var items: Array = []
	var c := 16
	var p := float(f) / float(FRAMES)
	var pulse := 0.5 + 0.5 * sin(TAU * p)
	var r_in := 5 + roundi(3.0 * pulse)
	var arm := Color(0.85, 1.0, 0.85)
	for i in range(r_in, r_in + 7):
		var col := arm if i < r_in + 5 else Color(0.55, 0.9, 0.6)
		_dot(items, c + i, c, col)
		_dot(items, c - i, c, col)
		_dot(items, c, c + i, col)
		_dot(items, c, c - i, col)
	_dot(items, c - 1, c - 1, Color(1.0, 1.0, 0.7), 2)
	for k in 4:
		var ang := p * TAU * 0.25 + float(k) * TAU * 0.25
		_dot(items, c + roundi(cos(ang) * 13.0) - 1, c + roundi(sin(ang) * 13.0) - 1, Color(1.0, 0.9, 0.4), 2)
	return _paint(items, 32, 2)

# 80x80 px: a red ring that throbs, spinning chevrons, short inner ticks and a hot centre.
static func _make_aggressive(f: int) -> ImageTexture:
	var items: Array = []
	var c := 20
	var p := float(f) / float(FRAMES)
	var pulse := 0.5 + 0.5 * sin(TAU * p)
	var rad := 11.0 + 2.0 * pulse
	var ring := Color(1.0, 0.2, 0.12).lerp(Color(1.0, 0.45, 0.2), pulse)
	for a in 72:
		var ang := TAU * float(a) / 72.0
		_dot(items, c + roundi(cos(ang) * rad), c + roundi(sin(ang) * rad), ring)
	for i in range(4, 9):
		var col := Color(1.0, 0.3, 0.15)
		_dot(items, c + i, c, col)
		_dot(items, c - i, c, col)
		_dot(items, c, c + i, col)
		_dot(items, c, c - i, col)
	for k in 4:
		var base_ang := p * TAU * 0.25 + float(k) * TAU * 0.25
		for w in range(-2, 3):
			var ang := base_ang + float(w) * 0.13
			var rr := 17.0 - absf(float(w)) * 0.6
			_dot(items, c + roundi(cos(ang) * rr), c + roundi(sin(ang) * rr), Color(1.0, 0.8, 0.25))
	_dot(items, c - 1, c - 1, Color(1.0, 0.95, 0.7), 2)
	return _paint(items, 40, 2)
