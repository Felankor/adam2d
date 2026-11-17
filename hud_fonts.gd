class_name HudFonts
extends RefCounted

# Fonts the HUD editor can give to a text element. All of them are pixel fonts; a size is always snapped to
# the font's own pixel grid so the letters keep square pixels.
const IDS := ["game", "pixelify", "silkscreen", "pressstart", "thinelectro", "errorstate", "halfpixel"]
const NAMES := {
	"game": "Classic", "pixelify": "Pixelify", "silkscreen": "Silkscreen", "pressstart": "Press Start",
	"thinelectro": "Thin Electro", "errorstate": "Error State", "halfpixel": "Gothic Halfpixel",
}
const UNIT := {"pixelify": 18, "silkscreen": 8, "pressstart": 8, "thinelectro": 14, "errorstate": 12, "halfpixel": 16}   # font size of one screen pixel per art pixel
const CAP := {"pixelify": 0.611, "silkscreen": 0.625, "pressstart": 0.875, "thinelectro": 0.7, "errorstate": 0.678, "halfpixel": 0.74}     # capital letter height / font size

static func data_of(id: String) -> String:
	match id:
		"pixelify": return HudFontsData.PIXELIFY
		"silkscreen": return HudFontsData.SILKSCREEN
		"pressstart": return HudFontsData.PRESSSTART
		"thinelectro": return HudFontsData.THINELECTRO
		"errorstate": return HudFontsData.ERRORSTATE
	return HudFontsData.HALFPIXEL

static var _fonts: Dictionary = {}

static func get_font(id: String) -> Font:
	if not UNIT.has(id):
		return PixelUI.font()
	if not _fonts.has(id):
		var ff := FontFile.new()
		ff.data = Marshalls.base64_to_raw(data_of(id))
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		ff.generate_mipmaps = false
		var fb: Array[Font] = [PixelUI.font()]        # letters the font lacks (Turkish ğ, ş, ı, İ, the digits of the Gothic demo ...)
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
