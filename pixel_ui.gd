class_name PixelUI
extends RefCounted

# One place for the pixel-art look of the interface: the font (art/pixel.ttf, a bitmap-style font built on a
# 10 px grid), windows and buttons drawn as 9-patch pixel frames, and helpers for the HUD.
# Call PixelUI.setup(get_tree()) once at the start of every scene.

const GRID := 10                      # the font is drawn on a 10 px grid: sizes 10 / 20 / 30 / 40 stay crisp
const OUTLINE := Color(0.04, 0.03, 0.08)
const WIN_BG := Color(0.085, 0.063, 0.045, 0.97)    # warm dark window fill (matches the HUD)
const BRONZE := Color(0.85, 0.65, 0.2)
const GOLD := Color(1.0, 0.85, 0.35)
const CREAM := Color(0.93, 0.88, 0.76)
const DIM := Color(0.62, 0.55, 0.45)
const GOOD := Color(0.62, 0.9, 0.45)
const BAD := Color(0.95, 0.38, 0.28)

static var _font: Font = null
static var _theme: Theme = null
static var _boxes: Dictionary = {}

static func font() -> Font:
	if _font == null:
		var ff := FontFile.new()
		ff.data = Marshalls.base64_to_raw(PixelFontData.B64)
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.multichannel_signed_distance_field = false
		ff.generate_mipmaps = false
		_font = ff
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
		var sep := StyleBoxLine.new()
		sep.color = Color(0.55, 0.36, 0.17)
		sep.thickness = 3
		_theme.set_stylebox("separator", "HSeparator", sep)
		var vsep := StyleBoxLine.new()
		vsep.color = Color(0.55, 0.36, 0.17)
		vsep.thickness = 3
		vsep.vertical = true
		_theme.set_stylebox("separator", "VSeparator", vsep)
		_theme.set_stylebox("panel", "PanelContainer", frame(WIN_BG, BRONZE))
		_theme.set_color("font_color", "Label", CREAM)
		_theme.set_color("font_outline_color", "Label", OUTLINE)
		_theme.set_constant("outline_size", "Label", 0)
		_style_controls(_theme)
	ThemeDB.fallback_font = font()
	root.theme = _theme

# Bronze look for sliders, check buttons and drop-down lists (so no default blue widgets remain).
static func _flat(col: Color, border: Color, bw: int = 2, r: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(r)
	sb.anti_aliasing = false
	return sb

static func _tex(w: int, h: int, painter: Callable) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var c: Variant = painter.call(x, y)
			if c is Color:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

static func _style_controls(th: Theme) -> void:
	var gold := Color(0.85, 0.65, 0.2)
	var hi := Color(1.0, 0.88, 0.5)
	var base := Color(0.72, 0.5, 0.18)
	var mid := Color(0.45, 0.3, 0.12)
	var dark := Color(0.2, 0.12, 0.05)
	# sliders: dark groove, bronze filled part, round brass knob
	th.set_stylebox("slider", "HSlider", _flat(Color(0.08, 0.05, 0.03), Color(0.35, 0.22, 0.1), 2))
	th.set_stylebox("grabber_area", "HSlider", _flat(base, mid, 2))
	th.set_stylebox("grabber_area_highlight", "HSlider", _flat(gold, mid, 2))
	var knob := _tex(22, 22, func(x: int, y: int) -> Variant:
		var d := Vector2(float(x) - 10.5, float(y) - 10.5).length()
		if d > 10.5:
			return null
		if d > 8.8:
			return Color(0.06, 0.04, 0.02)
		return hi if (x + y) < 20 and d < 6.0 else (gold if d < 7.5 else base))
	for n in ["grabber", "grabber_highlight", "grabber_disabled"]:
		th.set_icon(n, "HSlider", knob)
	# check buttons: a bronze toggle plate
	var off := _tex(40, 22, func(x: int, y: int) -> Variant:
		if x < 1 or y < 1 or x > 38 or y > 20:
			return null
		var e := x < 2 or y < 2 or x > 37 or y > 19
		if e:
			return Color(0.06, 0.04, 0.02)
		var kx := x >= 3 and x <= 17 and y >= 3 and y <= 18
		if kx:
			return base if y > 10 else gold
		return Color(0.12, 0.08, 0.05))
	var on := _tex(40, 22, func(x: int, y: int) -> Variant:
		if x < 1 or y < 1 or x > 38 or y > 20:
			return null
		var e := x < 2 or y < 2 or x > 37 or y > 19
		if e:
			return Color(0.06, 0.04, 0.02)
		var kx := x >= 22 and x <= 36 and y >= 3 and y <= 18
		if kx:
			return hi if y < 8 else gold
		return Color(0.55, 0.36, 0.12))
	for n in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		th.set_icon(n, "CheckButton", on if n.begins_with("checked") else off)
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
		var eb := StyleBoxEmpty.new()
		eb.content_margin_left = 6.0
		eb.content_margin_right = 6.0
		eb.content_margin_top = 8.0
		eb.content_margin_bottom = 8.0
		th.set_stylebox(state, "CheckButton", eb)
	th.set_constant("h_separation", "CheckButton", 16)
	th.set_color("font_color", "CheckButton", Color(0.95, 0.93, 0.85))
	th.set_color("font_hover_color", "CheckButton", Color(1.0, 0.95, 0.6))
	th.set_color("font_pressed_color", "CheckButton", Color(1.0, 0.9, 0.5))
	# drop-down lists reuse the button plates, their pop-up gets a bronze panel
	for state in ["normal", "hover", "pressed", "disabled"]:
		th.set_stylebox(state, "OptionButton", _button_box(state, 10))
	th.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	th.set_color("font_color", "OptionButton", Color(0.95, 0.93, 0.85))
	th.set_color("font_hover_color", "OptionButton", Color(1.0, 0.95, 0.6))
	var pp := _flat(Color(0.09, 0.06, 0.04, 0.98), gold, 3)
	pp.set_content_margin_all(6)
	th.set_stylebox("panel", "PopupMenu", pp)
	th.set_stylebox("hover", "PopupMenu", _flat(Color(0.45, 0.3, 0.12), gold, 1))
	th.set_color("font_color", "PopupMenu", Color(0.95, 0.93, 0.85))
	th.set_color("font_hover_color", "PopupMenu", Color(1.0, 0.95, 0.6))
	th.set_color("font_separator_color", "PopupMenu", gold)
	# scroll bars
	var sbg := _flat(Color(0.08, 0.05, 0.03), Color(0.3, 0.2, 0.09), 1)
	th.set_stylebox("scroll", "VScrollBar", sbg)
	th.set_stylebox("grabber", "VScrollBar", _flat(base, dark, 2))
	th.set_stylebox("grabber_highlight", "VScrollBar", _flat(gold, dark, 2))
	th.set_stylebox("grabber_pressed", "VScrollBar", _flat(hi, dark, 2))

static func _button_box(state: String, margin: int = 14) -> StyleBox:
	var bg := Color(0.14, 0.10, 0.08)
	var border := Color(0.85, 0.65, 0.2)
	var pressed := false
	match state:
		"hover":
			bg = Color(0.25, 0.17, 0.09)
			border = Color(1.0, 0.85, 0.45)
		"pressed":
			bg = Color(0.08, 0.05, 0.04)
			border = Color(1.0, 0.74, 0.28)
			pressed = true
		"disabled":
			bg = Color(0.10, 0.10, 0.12)
			border = Color(0.4, 0.4, 0.46)
	var sb := frame(bg, border, 2, pressed)
	sb.content_margin_left = float(margin)
	sb.content_margin_right = float(margin)
	sb.content_margin_top = 8.0 + (2.0 if pressed else 0.0)
	sb.content_margin_bottom = 8.0 - (2.0 if pressed else 0.0)
	return sb

# The game's signature window / button frame: a riveted bronze plate with a lit upper-left edge, brushed
# (dithered) metal bands, a dark inner lip and corner rivets. `border` tints the metal (gold = plain bronze).
static func frame(bg: Color, border: Color, unit: int = 3, inverted: bool = false) -> StyleBoxTexture:
	var key := "F|%s|%s|%d|%s" % [bg.to_html(true), border.to_html(true), unit, str(inverted)]
	if not _boxes.has(key):
		var art := 20
		var m := 7
		var metal := border.lerp(Color(0.59, 0.39, 0.18), 0.55)
		var hi := metal.lightened(0.7)
		var light := metal.lightened(0.32)
		var base := metal.darkened(0.1)
		var mid := metal.darkened(0.3)
		var dark := metal.darkened(0.55)
		if inverted:
			var t_hi := hi
			var t_light := light
			hi = dark
			light = mid
			mid = t_light
			dark = t_hi
		var px := {}
		for y in art:
			for x in art:
				var d := mini(mini(x, y), mini(art - 1 - x, art - 1 - y))
				var tl := (x + y) < (art - 1)
				var ck := (x + y) % 2 == 0
				var c := bg
				match d:
					0: c = OUTLINE
					1: c = hi if tl else mid
					2: c = light if tl else base
					3: c = (light if ck else base) if tl else (base if ck else mid)
					4: c = (base if ck else mid) if tl else (mid if ck else dark)
					5: c = mid if tl else dark
					6: c = bg.darkened(0.55)
					7: c = bg.darkened(0.3)
					_: c = bg
				px[Vector2i(x, y)] = c
		# corner rivets: small 3x3 domes
		for cc: Vector2i in [Vector2i(4, 4), Vector2i(art - 5, 4), Vector2i(4, art - 5), Vector2i(art - 5, art - 5)]:
			for j in range(-1, 2):
				for i in range(-1, 2):
					if absi(i) + absi(j) == 2:
						continue
					var rc := dark if (i > 0 or j > 0) else light
					if i == 0 and j == 0:
						rc = hi
					px[cc + Vector2i(i, j)] = rc if not inverted else base
		# soft, rounded corners
		for cc: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(art - 1, 0), Vector2i(art - 2, 0), Vector2i(art - 1, 1), Vector2i(0, art - 1), Vector2i(1, art - 1), Vector2i(0, art - 2), Vector2i(art - 1, art - 1), Vector2i(art - 2, art - 1), Vector2i(art - 1, art - 2)]:
			px.erase(cc)
		for cc: Vector2i in [Vector2i(1, 1), Vector2i(art - 2, 1), Vector2i(1, art - 2), Vector2i(art - 2, art - 2)]:
			px[cc] = OUTLINE
		var img := Image.create(art * unit, art * unit, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for k: Vector2i in px:
			var col: Color = px[k]
			for j in unit:
				for i in unit:
					img.set_pixel(k.x * unit + i, k.y * unit + j, col)
		var sb := StyleBoxTexture.new()
		sb.texture = ImageTexture.create_from_image(img)
		sb.set_texture_margin_all(float(m * unit))
		sb.set_content_margin_all(float(m * unit))
		_boxes[key] = sb
	return (_boxes[key] as StyleBoxTexture).duplicate() as StyleBoxTexture

# A slim bronze plate for small things (pop-ups, skill slots): outline, lit edge, brushed band, dark lip.
# The centre is filled with `bg` (may be transparent). `accent` tints the metal.
static func plate(bg: Color, accent: Color, unit: int = 2) -> StyleBoxTexture:
	var key := "P|%s|%s|%d" % [bg.to_html(true), accent.to_html(true), unit]
	if not _boxes.has(key):
		var art := 14
		var m := 4
		var metal := accent.lerp(Color(0.59, 0.39, 0.18), 0.6)
		var hi := metal.lightened(0.7)
		var light := metal.lightened(0.3)
		var base := metal.darkened(0.12)
		var mid := metal.darkened(0.35)
		var dark := metal.darkened(0.6)
		var img := Image.create(art * unit, art * unit, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in art:
			for x in art:
				var d := mini(mini(x, y), mini(art - 1 - x, art - 1 - y))
				var tl := (x + y) < (art - 1)
				var ck := (x + y) % 2 == 0
				if (x == 0 or x == art - 1) and (y == 0 or y == art - 1):
					continue
				var c := bg
				match d:
					0: c = OUTLINE
					1: c = hi if tl else mid
					2: c = (light if ck else base) if tl else (base if ck else mid)
					3: c = Color(0, 0, 0, 0.55)
				for j in unit:
					for i in unit:
						img.set_pixel(x * unit + i, y * unit + j, c)
		var sb := StyleBoxTexture.new()
		sb.texture = ImageTexture.create_from_image(img)
		sb.set_texture_margin_all(float(m * unit))
		sb.set_content_margin_all(float(m * unit))
		_boxes[key] = sb
	return (_boxes[key] as StyleBoxTexture).duplicate() as StyleBoxTexture

# A window / button frame: dark outline, a lit upper-left edge and a shaded lower-right edge, notched corners.
# `unit` is how many screen pixels one art pixel takes (3 matches the sprites).
static func box(bg: Color, border: Color, unit: int = 3, inverted: bool = false) -> StyleBoxTexture:
	if unit >= 3:
		return frame(bg, border, unit, inverted)
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


# Window title style: gold lettering with a hard dark outline, like the HUD medallion text.
static func style_title(l: Label, col: Color = GOLD) -> void:
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 4)
