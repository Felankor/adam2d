class_name Weapons
extends RefCounted

# The four weapon tiers. The same tier is used by the manual weapon and by
# every auto-weapon, so one upgrade improves both.
# Power order: Laser Gun > Rocket Launcher > Cannon > Machinegun.
const IDS := ["mg", "cannon", "rocket", "laser"]
const NAMES := ["Machinegun", "Cannon", "Rocket Launcher", "Laser Gun"]
const MAX_TIER := 3

# Manual fire
const DAMAGE := [3.0, 14.0, 32.0, 24.0]
const ENERGY_COST := [5.0, 20.0, 30.0, 18.0]
const INTERVAL := [0.1, 0.25, 0.6, 0.2]
# Auto-weapon damage per shot (they fire every auto_interval seconds)
const AUTO_DAMAGE := [3.0, 8.0, 18.0, 14.0]
# Gold price of the upgrade that leads TO tier index+1
const UPGRADE_PRICE := [100, 400, 1000]
# Projectile style per tier ("beam" = instant piercing laser)
const STYLE := ["bullet", "shell", "rocket", "beam"]
const SOUNDS := ["mg", "shoot", "rocket", "laser"]
const COLORS := [
	Color(1.0, 0.9, 0.35),
	Color(1.0, 0.6, 0.15),
	Color(1.0, 0.4, 0.2),
	Color(0.35, 0.95, 1.0),
]

static func name_of(tier: int) -> String:
	return NAMES[clampi(tier, 0, MAX_TIER)]

static func id_of(tier: int) -> String:
	return IDS[clampi(tier, 0, MAX_TIER)]
