class_name Weapons
extends RefCounted

# The six weapon tiers. The manual weapon uses the current tier; Gunner auto-weapons use the same tier
# but never go past the Gatling Gun (AUTO_MAX_TIER).
# Order: Automatic Rifle < Machinegun < Gatling Gun < Rocket Launcher < Laser Gun < Void Gun.
const IDS := ["mg", "mgun", "gatling", "rocket", "laser", "void"]
const NAMES := ["Automatic Rifle", "Machinegun", "Gatling Gun", "Rocket Launcher", "Laser Gun", "Void Gun"]
const MAX_TIER := 5
const AUTO_MAX_TIER := 2             # Gunners can use up to the Gatling Gun

# Manual fire
const DAMAGE := [3.0, 8.0, 12.0, 32.0, 24.0, 40.0]
const ENERGY_COST := [5.0, 20.0, 7.0, 30.0, 18.0, 36.0]
const INTERVAL := [0.1, 0.25, 0.07, 0.6, 0.2, 0.5]
# Auto-weapon damage per shot for Rifle / Machinegun / Gatling (they fire every auto_interval seconds)
const AUTO_DAMAGE := [3.0, 6.0, 9.0]
# Gold price of the upgrade that leads TO tier index+1
const UPGRADE_PRICE := [1000, 3000, 6000, 12000, 25000]
# Projectile style per tier ("beam" = instant piercing laser)
const STYLE := ["bullet", "bullet", "bullet", "rocket", "beam", "void"]
const SOUNDS := ["rifle", "carbine", "gatling", "rocket", "laser", "void"]
const COLORS := [
	Color(1.0, 0.9, 0.35),
	Color(1.0, 0.65, 0.2),
	Color(1.0, 0.8, 0.45),
	Color(1.0, 0.4, 0.2),
	Color(0.35, 0.95, 1.0),
	Color(0.55, 0.15, 0.95),
]

# Armor: a hit is multiplied by ARMOR_K / (ARMOR_K + max(armor - penetration, 0)).
# 50 armor halves a hit, 25 armor takes a third off. Armor penetration cancels armor point for point.
const ARMOR_K := 50.0
# Armor penetration of each weapon: the Automatic Rifle is useless against heavy armor, the Laser and Void Guns cut through it.
# TRUE_PEN (the Void Gun) is TRUE DAMAGE: it ignores armor and Energy Shields completely.
const TRUE_PEN := 1000.0
const PEN := [0.0, 5.0, 9.0, 12.0, 25.0, TRUE_PEN]
# Void Gun: splash radius of its blast (the Rocket Launcher has 110)
const VOID_SPLASH := 200.0

static func armor_mult(armor: float, pen: float = 0.0) -> float:
	return ARMOR_K / (ARMOR_K + maxf(armor - pen, 0.0))

static func is_true(pen: float) -> bool:
	return pen >= TRUE_PEN

static func name_of(tier: int) -> String:
	return NAMES[clampi(tier, 0, MAX_TIER)]

static func id_of(tier: int) -> String:
	return IDS[clampi(tier, 0, MAX_TIER)]
