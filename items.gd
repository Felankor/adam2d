class_name Items
extends RefCounted

# Phase 2: the things mobs drop on the maps. The Trader buys them for gold; the Stash keeps them safe.
# Order = the order they are listed in the inventory pages.
const ORDER := ["shard", "resin", "heart", "sigil"]
const DATA := {
	"shard": {"name": "Floatstone Shard", "price": 6, "col": Color(0.4, 0.85, 1.0),
		"desc": "A chip of floatstone, the rock that keeps your castle in the sky. Spent in the Shipyard to grow your castle.",
		"drop": "Dropped by big mobs, Rogue castles and bosses."},
	"resin": {"name": "Sky Resin", "price": 20, "col": Color(1.0, 0.7, 0.2),
		"desc": "Sticky sap that glues the heavy stone blocks of a bigger castle together. Needed for the Shipyard from the third castle stage on.",
		"drop": "Dropped by tanks, golems, demons and other big mobs."},
	"heart": {"name": "Rogue Heart", "price": 90, "col": Color(1.0, 0.3, 0.35),
		"desc": "The beating core of a Rogue castle. The largest castle stages are built around one.",
		"drop": "Dropped by Rogue castles (2 per boss)."},
	"sigil": {"name": "Warden Sigil", "price": 400, "col": Color(0.85, 0.5, 1.0),
		"desc": "A seal of the Wardens. It opens the Dungeon: one Sigil is used up for every run.",
		"drop": "Dropped by every boss the first time you beat it, and now and then after that."},
}

static func desc_of(id: String) -> String:
	return Loc.t(str((DATA.get(id, {}) as Dictionary).get("desc", "")))

static func drop_of(id: String) -> String:
	return Loc.t(str((DATA.get(id, {}) as Dictionary).get("drop", "")))

static func color_of(id: String) -> Color:
	return (DATA.get(id, {}) as Dictionary).get("col", Color(0.7, 0.7, 0.7)) as Color

static func name_of(id: String) -> String:
	return Loc.t(str((DATA.get(id, {}) as Dictionary).get("name", id)))

static func price_of(id: String) -> int:
	return int((DATA.get(id, {}) as Dictionary).get("price", 1))

# Phase 3: what the Shipyard asks to grow the castle from stage t to stage t+1.
# Returns {"gold": n, "shard": n, "resin": n, "heart": n} (zero entries are left out of the lists the window shows).
static func tier_cost(t: int) -> Dictionary:
	return {
		"gold": 200 * (t + 1) * (t + 1),
		"shard": 8 * (t + 1),
		"resin": 0 if t < 2 else 3 * (t - 1),
		"heart": 0 if t < 3 else t - 2,
	}

# What a dead mob leaves behind on a map: Array of [id, count].
static func roll_drops(kind: String, is_small: bool, first_clear: bool = false) -> Array:
	var out: Array = []
	if kind == "boss":
		if first_clear or randf() < 0.25:
			out.append(["sigil", 1])      # the first kill always drops it, later kills only sometimes
		out.append(["heart", 2])
		out.append(["shard", randi_range(6, 10)])
	elif kind == "minicastle":
		out.append(["heart", 1])
		out.append(["shard", randi_range(2, 4)])
	elif is_small:
		return out
	elif kind in ["tank", "heavytank", "mech", "aegis", "golem", "demon"]:
		if randf() < 0.30:
			out.append(["resin", 1])
		if randf() < 0.45:
			out.append(["shard", randi_range(1, 2)])
	elif randf() < 0.07:
		out.append(["shard", 1])
	return out
