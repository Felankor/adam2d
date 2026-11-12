class_name PixelUI
extends RefCounted

# One place for the pixel-art look of the interface: the font (art/pixel.ttf, a bitmap-style font built on a
# 10 px grid), windows and buttons drawn as 9-patch pixel frames, and helpers for the HUD.
# Call PixelUI.setup(get_tree()) once at the start of every scene.

const FONT_PATH := "res://art/pixel.ttf"
const GRID := 10                      # the font is drawn on a 10 px grid: sizes 10 / 20 / 30 / 40 stay crisp
const OUTLINE := Color(0.04, 0.03, 0.08)

static var _font: Font = null
static var _theme: Theme = null
static var _boxes: Dictionary = {}

static func font() -> Font:
	if _font == null:
		var res := load(FONT_PATH)
		if res is FontFile:
			var ff := res as FontFile
			ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			ff.hinting = TextServer.HINTING_NONE
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			ff.multichannel_signed_distance_field = false
			ff.generate_mipmaps = false
			_font = ff
		else:
			_font = ThemeDB.fallback_font
	return _font

# Snap a font size to the pixel grid so letters keep square pixels.
static func fs(n: int) -> int:
	if n <= 14:
		return GRID
	if n <= 23:
		return GRID * 2
	if n <= 33:
		return GRID * 3
	return int(roundf(float(n) / float(GRID))) * GRID

static func setup(tree: SceneTree) -> void:
	var root := tree.root
	root.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = font()
		_theme.default_font_size = GRID * 2
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			_theme.set_stylebox(state, "Button", _button_box(state))
		_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
		_theme.set_color("font_color", "Button", Color(0.95, 0.93, 0.85))
		_theme.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.6))
		_theme.set_color("font_pressed_color", "Button", Color(1.0, 0.85, 0.4))
		_theme.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
		_theme.set_color("font_outline_color", "Button", OUTLINE)
		_theme.set_constant("outline_size", "Button", 0)
		_theme.set_constant("h_separation", "Button", 12)
		_theme.set_stylebox("panel", "PanelContainer", box(Color(0.09, 0.10, 0.14, 0.97), Color(0.85, 0.65, 0.2)))
	ThemeDB.fallback_font = font()
	root.theme = _theme

static func _button_box(state: String, margin: int = 14) -> StyleBox:
	var bg := Color(0.20, 0.22, 0.32)
	var border := Color(0.62, 0.68, 0.85)
	var pressed := false
	match state:
		"hover":
			bg = Color(0.28, 0.31, 0.45)
			border = Color(1.0, 0.85, 0.4)
		"pressed":
			bg = Color(0.12, 0.13, 0.20)
			border = Color(1.0, 0.75, 0.25)
			pressed = true
		"disabled":
			bg = Color(0.13, 0.14, 0.18)
			border = Color(0.32, 0.34, 0.42)
	var sb := box(bg, border, 2, pressed)
	sb.content_margin_left = float(margin)
	sb.content_margin_right = float(margin)
	sb.content_margin_top = 6.0 + (2.0 if pressed else 0.0)
	sb.content_margin_bottom = 6.0 - (2.0 if pressed else 0.0)
	return sb

# A window / button frame: dark outline, a lit upper-left edge and a shaded lower-right edge, notched corners.
# `unit` is how many screen pixels one art pixel takes (3 matches the sprites).
static func box(bg: Color, border: Color, unit: int = 3, inverted: bool = false) -> StyleBoxTexture:
	var key := "%s|%s|%d|%s" % [bg.to_html(true), border.to_html(true), unit, str(inverted)]
	if not _boxes.has(key):
		var art := 9
		var img := Image.create(art * unit, art * unit, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var lit := border.lightened(0.35)
		var shade := border.darkened(0.45)
		if inverted:
			var tmp := lit
			lit = shade
			shade = tmp
		for y in art:
			for x in art:
				var d := mini(mini(x, y), mini(art - 1 - x, art - 1 - y))
				var c := bg
				if (x == 0 or x == art - 1) and (y == 0 or y == art - 1):
					continue
				if d == 0:
					c = OUTLINE
				elif d == 1:
					c = lit if x + y < art - 1 else shade
					if (x == 1 and y == art - 2) or (x == art - 2 and y == 1):
						c = border
				elif d == 2:
					c = bg.darkened(0.12) if (x + y < art - 1) else bg.lightened(0.05)
				for j in unit:
					for i in unit:
						img.set_pixel(x * unit + i, y * unit + j, c)
		var sb := StyleBoxTexture.new()
		sb.texture = ImageTexture.create_from_image(img)
		sb.set_texture_margin_all(float(3 * unit))
		sb.set_content_margin_all(float(3 * unit))
		_boxes[key] = sb
	return (_boxes[key] as StyleBoxTexture).duplicate() as StyleBoxTexture

# Draw `text` with a hard pixel outline (no blur) on any CanvasItem.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, outline: int = 0) -> void:
	var f := font()
	var sz := fs(size)
	if outline > 0:
		ci.draw_string_outline(f, pos, s, align, width, sz, outline, OUTLINE)
	ci.draw_string(f, pos, s, align, width, sz, col)
