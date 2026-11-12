class_name HudLayout
extends RefCounted

# Where every HUD element sits and how it looks. The Hud draws each element at its default place and the
# layout only adds an offset, a size, an opacity and a few per-element options on top.
# Saved in settings.cfg ([hud] layout, slot1, slot2) and edited in-game with the HUD editor.

const IDS := ["bars", "shield", "xp", "tag", "weapon", "skills", "minimap", "helpers", "gold", "fps", "info", "notifier", "bossbar", "bosswarn", "banner", "levelup"]
const NAMES := {
	"bars": "Health & Mana", "shield": "Shield", "xp": "XP bar", "tag": "Stat points tag", "weapon": "Weapon",
	"skills": "Skills", "minimap": "Minimap", "helpers": "Helpers", "gold": "Coins", "fps": "FPS counter",
	"info": "Wave info", "notifier": "Pop-ups", "bossbar": "Boss health bar", "bosswarn": "Boss warning", "banner": "Wave banner", "levelup": "Level-up burst",
}
# Elements that draw text: they also get a font and a text size.
const TEXT := ["bars", "shield", "xp", "tag", "skills", "helpers", "gold", "fps", "info", "notifier", "bossbar", "bosswarn", "banner", "levelup"]
const TEXT_ROWS := [
	["font", "Font", "enum", ["game", "pixelify", "silkscreen"]],
	["tsize", "Text size", "float", 0.5, 2.0, 0.25],
]
const PRESETS := ["Classic", "Wide", "Compact", "Minimal"]

# Option rows of the editor: [key, label, type, ...]. "float": min, max, step. "enum": the values.
const COMMON := [
	["vis", "Visible", "bool"],
	["scale", "Size", "float", 0.5, 2.0, 0.05],
	["alpha", "Opacity", "float", 0.2, 1.0, 0.05],
]
const EXTRA := {
	"bars": [
		["len", "Bar length", "float", -40.0, 120.0, 4.0],
		["nums", "Numbers", "enum", ["full", "value", "off"]],
		["numsize", "Number size", "enum", ["small", "normal", "large"]],
		["trail", "Damage trail", "bool"],
		["warn", "Low warning flash", "bool"],
		["crit", "Critical hit shards", "bool"],
	],
	"shield": [
		["style", "Style", "enum", ["layer", "own"]],
		["text", "Show number", "bool"],
	],
	"xp": [
		["len", "Bar length", "float", -60.0, 200.0, 4.0],
		["text", "Text", "enum", ["full", "level", "off"]],
		["glow", "Gain effects", "bool"],
	],
	"tag": [
		["bounce", "Bounce", "bool"],
	],
	"weapon": [
		["frame", "Frame", "bool"],
	],
	"skills": [
		["gap", "Gap", "float", 0.0, 30.0, 2.0],
		["keys", "Key labels", "bool"],
		["cdnum", "Cooldown numbers", "bool"],
	],
	"minimap": [
		["range", "Range", "float", 800.0, 3200.0, 100.0],
		["bossonly", "Bosses only", "bool"],
	],
	"helpers": [
		["layout", "Layout", "enum", ["row", "column"]],
		["hide_empty", "Hide empty ones", "bool"],
	],
	"gold": [],
	"fps": [
		["detail", "Detail", "enum", ["full", "fps"]],
	],
	"info": [], "notifier": [], "bossbar": [], "bosswarn": [], "banner": [], "levelup": [],
}
const EXTRA_DEF := {
	"bars": {"len": 0.0, "nums": "full", "numsize": "normal", "trail": true, "warn": true, "crit": true},
	"shield": {"style": "layer", "text": true},
	"xp": {"len": 0.0, "text": "full", "glow": true},
	"tag": {"bounce": true},
	"weapon": {"frame": true},
	"skills": {"gap": 10.0, "keys": true, "cdnum": true},
	"minimap": {"range": 1700.0, "bossonly": false},
	"helpers": {"layout": "row", "hide_empty": false},
	"gold": {},
	"fps": {"detail": "full"},
	"info": {}, "notifier": {}, "bossbar": {}, "bosswarn": {}, "banner": {}, "levelup": {},
}

static var cfg: Dictionary = {}      # id -> {key: value}; only what differs from the defaults
static var rev: int = 0              # grows on every change, the Hud re-places its parts when it sees a new one

static func default_of(id: String) -> Dictionary:
	var d := {"vis": true, "scale": 1.0, "alpha": 1.0, "ox": 0.0, "oy": 0.0}
	var ex: Dictionary = EXTRA_DEF.get(id, {})
	for k in ex:
		d[k] = ex[k]
	if TEXT.has(id):
		d["font"] = "game"
		d["tsize"] = 1.0
	return d

static func font_id(id: String) -> String:
	return text(id, "font") if TEXT.has(id) else "game"

static func tmult(id: String) -> float:
	return num(id, "tsize") if TEXT.has(id) else 1.0

static func get_v(id: String, key: String) -> Variant:
	var c: Dictionary = cfg.get(id, {})
	if c.has(key):
		return c[key]
	return default_of(id)[key]

static func flag(id: String, key: String) -> bool:
	return bool(get_v(id, key))

static func num(id: String, key: String) -> float:
	return float(get_v(id, key))

static func text(id: String, key: String) -> String:
	return str(get_v(id, key))

static func set_v(id: String, key: String, v: Variant) -> void:
	var c: Dictionary = cfg.get(id, {})
	if default_of(id)[key] == v:
		c.erase(key)
	else:
		c[key] = v
	if c.is_empty():
		cfg.erase(id)
	else:
		cfg[id] = c
	rev += 1

static func reset_element(id: String) -> void:
	cfg.erase(id)
	rev += 1

static func reset_all() -> void:
	cfg = {}
	rev += 1

static func is_default(id: String) -> bool:
	return not cfg.has(id)

# The extra bar length in art pixels per side, kept even (the art is dithered in 2 px steps).
static func bar_extra() -> int:
	return int(roundf(num("bars", "len") / 2.0)) * 2

static func xp_extra() -> int:
	return int(roundf(num("xp", "len") / 2.0)) * 2

# ---------- presets ----------

static func preset(name: String) -> Dictionary:
	match name:
		"Wide":
			return {
				"bars": {"len": 40.0},
				"shield": {"style": "own"},
				"xp": {"len": 80.0},
			}
		"Compact":
			return {
				"bars": {"scale": 0.85, "numsize": "small"},
				"xp": {"scale": 0.85, "text": "level"},
				"tag": {"scale": 0.85},
				"weapon": {"scale": 0.85},
				"skills": {"scale": 0.8, "gap": 6.0},
				"minimap": {"scale": 0.8},
				"helpers": {"scale": 0.75},
				"gold": {"scale": 0.85},
				"fps": {"scale": 0.85, "detail": "fps"},
				"info": {"scale": 0.85},
				"notifier": {"scale": 0.85},
			}
		"Minimal":
			return {
				"bars": {"scale": 0.9, "nums": "value", "numsize": "small", "crit": false},
				"xp": {"len": -40.0, "text": "off", "glow": false},
				"skills": {"scale": 0.85, "cdnum": true},
				"minimap": {"scale": 0.7, "alpha": 0.8},
				"helpers": {"vis": false},
				"fps": {"vis": false},
			}
	return {}

static func apply_preset(name: String) -> void:
	cfg = preset(name).duplicate(true)
	rev += 1

# ---------- snapshots and saving ----------

static func snapshot() -> Dictionary:
	return cfg.duplicate(true)

static func restore(snap: Dictionary) -> void:
	cfg = snap.duplicate(true)
	rev += 1

static func _to_text(d: Dictionary) -> String:
	return JSON.stringify(d)

static func _from_text(s: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(s)
	var out := {}
	if parsed is Dictionary:
		for id in parsed:
			if not IDS.has(id) or not (parsed[id] is Dictionary):
				continue
			var d := default_of(id)
			var clean := {}
			for k in parsed[id]:
				if d.has(k) and typeof(parsed[id][k]) == typeof(d[k]):
					clean[k] = parsed[id][k]
				elif d.has(k) and d[k] is float and (parsed[id][k] is int):
					clean[k] = float(parsed[id][k])
			if not clean.is_empty():
				out[id] = clean
	return out

# The layout travels inside every saved game as a plain dictionary.
static func load_dict(d: Dictionary) -> void:
	cfg = _from_text(JSON.stringify(d))
	rev += 1

static func load_from(c: ConfigFile) -> void:
	cfg = _from_text(str(c.get_value("hud", "layout", "{}")))
	rev += 1

static func save_to(c: ConfigFile) -> void:
	c.set_value("hud", "layout", _to_text(cfg))

# The two "Mine" slots live in the same file.
static func slot_has(n: int) -> bool:
	var c := ConfigFile.new()
	return c.load(Settings.PATH) == OK and c.has_section_key("hud", "slot%d" % n)

static func slot_save(n: int) -> void:
	var c := ConfigFile.new()
	c.load(Settings.PATH)
	c.set_value("hud", "slot%d" % n, _to_text(cfg))
	c.save(Settings.PATH)

static func slot_load(n: int) -> bool:
	var c := ConfigFile.new()
	if c.load(Settings.PATH) != OK or not c.has_section_key("hud", "slot%d" % n):
		return false
	cfg = _from_text(str(c.get_value("hud", "slot%d" % n, "{}")))
	rev += 1
	return true
