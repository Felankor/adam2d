class_name Power
extends RefCounted

# PowerScore: one number that says "how strong is this?" for any mob, boss or the
# player's castle, so waves, random events and rival castles can be built from a
# power BUDGET instead of hand-tuned numbers.
#
#   power = SCALE * sqrt(effective_health * offense)
#
#   effective_health  health, raised by armor, damage absorption and dodging
#   offense (mob)     damage  x 3 if it shoots  x (1 + speed / 150)  x power_mult
#   offense (castle)  damage per second of the weapon (limited by energy regen),
#                     plus auto-weapons
#
# Doubling both health and offense doubles the score, so a "70% power" rival has
# 70% of the health AND 70% of the damage.
# Examples (Beginner): level-1 castle ~ 100, level-10 soldier ~ 40, level-10 tank ~ 130.

const SCALE := 6.5
const SPEED_REF := 150.0

static func score(ehp: float, offense: float) -> float:
	return SCALE * sqrt(maxf(ehp, 1.0) * maxf(offense, 0.05))

static func of_enemy(e: Enemy) -> float:
	var ehp := (e.hp + e.shield_max) * (Weapons.ARMOR_K + e.armor) / Weapons.ARMOR_K / maxf(e.dmg_taken_mult, 0.1)
	ehp *= 1.0 + 0.6 * e.dodge_chance
	var offense := e.damage * (3.0 if e.shoots else 1.0) * (1.0 + e.speed / SPEED_REF) * e.power_mult
	return score(ehp, offense)

# Damage per second of a castle with these stats (energy limits the fire rate).
static func castle_dps(weapon_tier: int, energy_regen: float, dmg_mult: float, autos: int, auto_interval: float, atk: float = 1.0) -> float:
	var interval: float = Weapons.INTERVAL[weapon_tier]
	var cost: float = Weapons.ENERGY_COST[weapon_tier]
	var dmg: float = Weapons.DAMAGE[weapon_tier]
	var shots := minf(atk / interval, energy_regen / cost)
	var dps := dmg * shots
	if autos > 0:
		var adm: float = Weapons.AUTO_DAMAGE[weapon_tier]
		dps += float(autos) * adm / auto_interval * atk
	return dps * dmg_mult

static func castle_ehp(max_hp: float) -> float:
	return max_hp * 1.3      # the Barrier skill makes the castle ~30% tougher

static func of_base(b: Base) -> float:
	var dps := castle_dps(b.weapon_tier, b.energy_regen, b.damage_mult, b.auto_cannons, b.auto_interval, b.attack_speed)
	return score(castle_ehp(b.max_hp), dps)

# Power of one freshly made enemy of this kind (handy for building wave budgets).
static func of_kind(kind: String, level: int) -> float:
	var e := Enemy.make(kind, level)
	var p := of_enemy(e)
	e.free()
	return p

# Total power of everything hostile that is alive right now.
static func field_power(tree: SceneTree) -> float:
	var total := 0.0
	for node in tree.get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and not e.dead:
			total += of_enemy(e)
	return total

static func kinds_for_biome(biome: int) -> Array[String]:
	var kinds: Array[String] = ["soldier", "tank", "mech"]
	match biome:
		1:
			kinds.append("worm")
		2:
			kinds.append("golem")
		3:
			kinds.append("demon")
		4:
			kinds.append("hunter")
	return kinds

# Picks random mob kinds until their combined power reaches the budget.
static func random_pack(biome: int, level: int, budget: float) -> Array[String]:
	var kinds := kinds_for_biome(biome)
	var pack: Array[String] = []
	var spent := 0.0
	var guard := 0
	while spent < budget and guard < 200:
		guard += 1
		var k: String = kinds[randi() % kinds.size()]
		var cost := of_kind(k, level)
		if spent + cost > budget * 1.15 and not pack.is_empty():
			continue
		pack.append(k)
		spent += cost
	return pack
