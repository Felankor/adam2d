class_name HudFonts
extends RefCounted

# Fonts the HUD editor can give to a text element. All of them are pixel fonts; a size is always snapped to
# the font's own pixel grid so the letters keep square pixels.
const IDS := ["game", "pixelify", "silkscreen"]
const UNIT := {"pixelify": 18, "silkscreen": 8}           # font size of one screen pixel per art pixel
const CAP := {"pixelify": 0.611, "silkscreen": 0.625}     # capital letter height / font size

static var _fonts: Dictionary = {}

static func get_font(id: String) -> Font:
	if not UNIT.has(id):
		return PixelUI.font()
	if not _fonts.has(id):
		var ff := FontFile.new()
		ff.data = Marshalls.base64_to_raw(HudFontsData.PIXELIFY if id == "pixelify" else HudFontsData.SILKSCREEN)
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.generate_mipmaps = false
		var fb: Array[Font] = [PixelUI.font()]        # letters the font lacks (Silkscreen has no Turkish ğ, ş, ı, İ)
		ff.fallbacks = fb
		_fonts[id] = ff
	return _fonts[id]

# The font size to use for a text that the game font draws at `base` (times the element's text size).
static func size_for(id: String, base: float, mult: float = 1.0) -> int:
	var g := PixelUI.fs(roundi(base * mult))
	if not UNIT.has(id):
		return g
	var unit: int = UNIT[id]
	var n := maxi(1, roundi(float(g) * 0.7 / (float(CAP[id]) * float(unit))))
	return n * unit
