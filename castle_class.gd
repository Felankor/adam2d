class_name CastleClass
extends RefCounted

# The three castle classes. Each one changes the castle's base health, armor and speed and brings one skill:
#   Standard - balanced, adaptable: one free reroll on every level-up
#   Scout    - fast and fragile, active skill Dash
#   Bulwark  - slow and tough, active skill Mob Push
# The class is chosen in the Castle window while you are in the hub.

const IDS := ["standard", "scout", "bulwark"]
const DATA := {
	"standard": {"name": "Standard", "hp": 1.0, "armor": 0.0, "speed": 1.0, "skill": "",
		"note": "Standard stats. Adaptable: one free reroll on every level-up."},
	"scout": {"name": "Scout", "hp": 0.7, "armor": -3.0, "speed": 1.35, "skill": "dash",
		"note": "Low health and armor, high speed. Active skill: Dash - a burst of speed, nothing can hurt you while it lasts."},
	"bulwark": {"name": "Bulwark", "hp": 1.5, "armor": 6.0, "speed": 0.7, "skill": "push",
		"note": "More health and armor, low speed. Active skill: Mob Push - a shockwave that throws nearby mobs back."},
}

static func info(id: String) -> Dictionary:
	return DATA.get(id, DATA["standard"]) as Dictionary

static func valid(id: String) -> bool:
	return DATA.has(id)

static func hp(id: String) -> float:
	return float(info(id)["hp"])

static func armor(id: String) -> float:
	return float(info(id)["armor"])

static func speed(id: String) -> float:
	return float(info(id)["speed"])

static func skill(id: String) -> String:
	return str(info(id)["skill"])

static func cname(id: String) -> String:
	return str(info(id)["name"])
