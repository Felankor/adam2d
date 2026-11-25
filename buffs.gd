class_name Buffs
extends RefCounted

# The level-up buffs. Every level offers three different ones; you pick one. A buff is a few stat points
# (each point is +1% over the current value, see Base.spend_point), so it works with all the existing stat maths.
# Which stats are offered, and how often, depends on the castle class.

const NAMES := {
	"damage": ["Weapon damage", "damage"], "attack": ["Attack speed", "atkspeed"], "regen": ["Mana regen", "regen"],
	"energy": ["Max mana", "energy"], "health": ["Max health", "b_health"], "speed": ["Move speed", "speed"],
	"autorate": ["Auto fire rate", "autorate"], "armor": ["Armor", "b_armor"], "eshield": ["Energy Shield", "eshield"],
}
const RARITY := ["Common", "Rare", "Epic", "Legendary", "Relic"]
const RARITY_COL := [Color(0.78, 0.78, 0.84), Color(0.4, 0.7, 1.0), Color(0.82, 0.5, 1.0), Color(1.0, 0.65, 0.15), Color(1.0, 0.25, 0.3)]
const RARITY_W := [55.0, 28.0, 12.0, 4.0, 1.0]   # percent; Relic is rarer than Legendary
# points per rarity (common, rare, epic, legendary, relic)
const PTS := {
	"damage": [4, 8, 14, 24, 42], "attack": [4, 8, 14, 24, 42], "regen": [6, 12, 20, 35, 60], "energy": [6, 12, 20, 35, 60], "health": [6, 12, 20, 35, 60],
	"speed": [4, 8, 14, 24, 42], "autorate": [5, 10, 16, 28, 48], "armor": [4, 8, 14, 24, 42], "eshield": [6, 12, 20, 35, 60],
}
# how often a stat shows up for each class (0 = never)
const WEIGHTS := {
	"standard": {"damage": 3, "attack": 3, "regen": 0, "energy": 0, "health": 3, "speed": 3, "autorate": 2, "armor": 2, "eshield": 4},
	"scout": {"damage": 3, "attack": 4, "regen": 0, "energy": 0, "health": 1, "speed": 4, "autorate": 2, "armor": 1, "eshield": 3},
	"bulwark": {"damage": 3, "attack": 1, "regen": 0, "energy": 0, "health": 4, "speed": 1, "autorate": 4, "armor": 4, "eshield": 3},
}

static func name_of(stat: String) -> String:
	return str((NAMES[stat] as Array)[0])

static func icon_of(stat: String) -> String:
	return str((NAMES[stat] as Array)[1])

# Three different stats, each with its own random rarity: [{"stat", "pts", "rar"}].
static func offer(b: Base, n: int = 3) -> Array:
	var w: Dictionary = WEIGHTS.get(b.cls, WEIGHTS["standard"])
	var cand: Array = []
	var wsum := 0.0
	for k in w.keys():
		var sid := str(k)
		var wt := float(w[k])
		if wt <= 0.0:
			continue
		if sid == "autorate" and b.auto_rate_maxed():
			continue
		cand.append([sid, wt])
		wsum += wt
	var out: Array = []
	while out.size() < n and not cand.is_empty():
		var r := randf() * wsum
		var pick := 0
		for i in cand.size():
			r -= float((cand[i] as Array)[1])
			if r <= 0.0:
				pick = i
				break
		var chosen: Array = cand[pick]
		wsum -= float(chosen[1])
		cand.remove_at(pick)
		var rr := randf() * 100.0
		var rar := 0
		for ri in RARITY_W.size():
			rr -= float(RARITY_W[ri])
			if rr < 0.0:
				rar = ri
				break
		var pts_arr: Array = PTS[str(chosen[0])]
		out.append({"stat": str(chosen[0]), "pts": int(pts_arr[rar]), "rar": rar})
	return out

static func amount_text(o: Dictionary) -> String:
	var pts := int(o["pts"])
	if str(o["stat"]) == "armor":
		return "+%.1f %s" % [float(pts) * 0.5, Loc.t("armor")]
	return "+%d%%" % pts
