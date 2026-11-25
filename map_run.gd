class_name MapRun
extends Node2D

# Phase 1 of the Hub & Maps overhaul: one handmade map. The castle flies around a bounded area that holds spawn zones.
# A zone sleeps until the castle comes near, then its pack wakes and charges. A boss arena sits at the far end.
# This node only keeps the state and draws the zone rings, the map edge and the arrow; Main spawns the mobs.

signal zone_woke(zone: Dictionary)
signal zone_cleared(zone: Dictionary)
signal danger_near(zone: Dictionary)

const WAKE_DIST := 640.0        # a zone wakes when the castle is this close (the nearest zones start ~890 away, so nothing wakes at the start)
const WARN_DIST := 1750.0       # a dangerous zone shows its warning at this distance
const BOSS_WAKE := 1500.0
const EDGE_MARGIN := 90.0

var map_id: String = "greenland"
var map_name: String = "Greenland Expedition"
var biome: int = 0              # the region whose backdrop, weather, mobs and boss this map uses
var bounds: Rect2
var zones: Array[Dictionary] = []
var boss: Dictionary = {}
var _player: Vector2 = Vector2.ZERO
var _t: float = 0.0

# The Greenland map. Offsets are from where the castle starts; the level (lvl) of the mobs grows with the distance.
static func greenland(origin: Vector2) -> MapRun:
	return _build("greenland", "Greenland Expedition", 0, origin, GREENLAND_ZONES, Vector2(2500, -1600), 8)

# Every expedition, in the order they unlock (each opens when the one before it is cleared).
const IDS := ["greenland", "mudland", "mountains", "hell"]
const NAMES := {"greenland": "Greenland Expedition", "mudland": "Mudland Expedition", "mountains": "High Mountains Expedition", "hell": "Hell Expedition"}
const DANGER := {"greenland": "Danger: Low", "mudland": "Danger: Medium", "mountains": "Danger: High", "hell": "Danger: Extreme"}
const REGION := {"greenland": 0, "mudland": 1, "mountains": 2, "hell": 6}
const BOSS_AT := {"greenland": Vector2(2500, -1600), "mudland": Vector2(-2500, -1700), "mountains": Vector2(2500, 1600), "hell": Vector2(-2500, 1600)}
const BOSS_LVL := {"greenland": 8, "mudland": 16, "mountains": 24, "hell": 32}

static func zones_of(id: String) -> Array:
	match id:
		"mudland":
			return MUDLAND_ZONES
		"mountains":
			return MOUNTAIN_ZONES
		"hell":
			return HELL_ZONES
	return GREENLAND_ZONES

# The mob kinds that live in an expedition, in the order they first show up.
static func mobs_of(id: String) -> Array:
	var out: Array = []
	for d: Dictionary in zones_of(id):
		for p: Array in d["pack"]:
			if not out.has(str(p[0])):
				out.append(str(p[0]))
	return out

static func region_of(id: String) -> int:
	return int(REGION.get(id, 0))

# The expedition that must be cleared before this one opens ("" = always open).
static func needs(id: String) -> String:
	var i := IDS.find(id)
	return "" if i <= 0 else IDS[i - 1]

static func make(id: String, origin: Vector2) -> MapRun:
	if not IDS.has(id):
		id = "greenland"
	var zones: Array = GREENLAND_ZONES
	match id:
		"mudland":
			zones = MUDLAND_ZONES
		"mountains":
			zones = MOUNTAIN_ZONES
		"hell":
			zones = HELL_ZONES
	return _build(id, str(NAMES[id]), region_of(id), origin, zones, BOSS_AT[id] as Vector2, int(BOSS_LVL[id]))

const GREENLAND_ZONES := [
		{"at": Vector2(-850, -250), "lvl": 1, "pack": [["soldier", 8]], "mult": 1.0},
		{"at": Vector2(900, 350), "lvl": 2, "pack": [["soldier", 6], ["mech", 1]], "mult": 1.0},
		{"at": Vector2(150, -1000), "lvl": 2, "pack": [["soldier", 10]], "mult": 1.0},
		{"at": Vector2(-1500, 900), "lvl": 3, "pack": [["soldier", 6], ["mech", 3]], "mult": 1.0},
		{"at": Vector2(1700, -700), "lvl": 3, "pack": [["soldier", 6], ["tank", 2]], "mult": 1.0},
		{"at": Vector2(-300, 1500), "lvl": 4, "pack": [["soldier", 6], ["mech", 5]], "mult": 1.0},
		{"at": Vector2(2200, 900), "lvl": 4, "pack": [["tank", 3], ["mech", 2]], "mult": 1.6},
		{"at": Vector2(-2300, -900), "lvl": 5, "pack": [["soldier", 14], ["medic", 2]], "mult": 1.0},
		{"at": Vector2(1200, -1700), "lvl": 5, "pack": [["heavytank", 1], ["soldier", 8]], "mult": 1.6},
		{"at": Vector2(-1800, 1700), "lvl": 6, "pack": [["aegis", 2], ["soldier", 10], ["mech", 3]], "mult": 1.0},
]

# Mudland: bloodworm swarms and tougher tanks; same size as Greenland, different corners for the boss.
const MUDLAND_ZONES := [
		{"at": Vector2(-900, -300), "lvl": 7, "pack": [["worm", 14], ["soldier", 4]], "mult": 1.0},
		{"at": Vector2(950, 300), "lvl": 7, "pack": [["worm", 12], ["mech", 2]], "mult": 1.0},
		{"at": Vector2(0, -1050), "lvl": 8, "pack": [["soldier", 10], ["tank", 2]], "mult": 1.0},
		{"at": Vector2(-1600, 850), "lvl": 8, "pack": [["worm", 16], ["mech", 3]], "mult": 1.0},
		{"at": Vector2(1750, -750), "lvl": 9, "pack": [["tank", 3], ["worm", 8]], "mult": 1.0},
		{"at": Vector2(-350, 1550), "lvl": 9, "pack": [["worm", 14], ["medic", 2], ["soldier", 6]], "mult": 1.0},
		{"at": Vector2(2250, 900), "lvl": 10, "pack": [["heavytank", 1], ["tank", 2], ["worm", 8]], "mult": 1.6},
		{"at": Vector2(-2350, -950), "lvl": 10, "pack": [["soldier", 12], ["medic", 3], ["mech", 4]], "mult": 1.0},
		{"at": Vector2(1250, -1750), "lvl": 11, "pack": [["heavytank", 2], ["worm", 10]], "mult": 1.6},
		{"at": Vector2(-1850, 1750), "lvl": 12, "pack": [["aegis", 3], ["worm", 12], ["mech", 4]], "mult": 1.0},
]

# High Mountains: golems (they split when destroyed) with soldiers and heavy armour.
const MOUNTAIN_ZONES := [
		{"at": Vector2(-900, -300), "lvl": 13, "pack": [["golem", 4], ["soldier", 8]], "mult": 1.0},
		{"at": Vector2(950, 300), "lvl": 13, "pack": [["golem", 3], ["mech", 4]], "mult": 1.0},
		{"at": Vector2(0, -1050), "lvl": 14, "pack": [["tank", 4], ["soldier", 10]], "mult": 1.0},
		{"at": Vector2(-1600, 850), "lvl": 14, "pack": [["golem", 5], ["medic", 2]], "mult": 1.0},
		{"at": Vector2(1750, -750), "lvl": 15, "pack": [["heavytank", 1], ["golem", 4]], "mult": 1.0},
		{"at": Vector2(-350, 1550), "lvl": 15, "pack": [["golem", 4], ["mech", 5], ["medic", 2]], "mult": 1.0},
		{"at": Vector2(2250, 900), "lvl": 16, "pack": [["heavytank", 2], ["golem", 4]], "mult": 1.6},
		{"at": Vector2(-2350, -950), "lvl": 16, "pack": [["aegis", 3], ["soldier", 12]], "mult": 1.0},
		{"at": Vector2(1250, -1750), "lvl": 17, "pack": [["golem", 7], ["heavytank", 2]], "mult": 1.6},
		{"at": Vector2(-1850, 1750), "lvl": 18, "pack": [["aegis", 3], ["golem", 5], ["mech", 4]], "mult": 1.0},
]

# Hell: demons that leap over lava, apocalypse tanks, fewer soldiers.
const HELL_ZONES := [
		{"at": Vector2(-900, -300), "lvl": 19, "pack": [["demon", 5], ["soldier", 6]], "mult": 1.0},
		{"at": Vector2(950, 300), "lvl": 19, "pack": [["demon", 6]], "mult": 1.0},
		{"at": Vector2(0, -1050), "lvl": 20, "pack": [["demon", 4], ["tank", 3]], "mult": 1.0},
		{"at": Vector2(-1600, 850), "lvl": 20, "pack": [["demon", 7], ["soldier", 6]], "mult": 1.0},
		{"at": Vector2(1750, -750), "lvl": 21, "pack": [["apoctank", 1], ["demon", 4]], "mult": 1.0},
		{"at": Vector2(-350, 1550), "lvl": 21, "pack": [["demon", 6], ["heavytank", 1]], "mult": 1.0},
		{"at": Vector2(2250, 900), "lvl": 22, "pack": [["apoctank", 2], ["demon", 4]], "mult": 1.6},
		{"at": Vector2(-2350, -950), "lvl": 22, "pack": [["demon", 8], ["medic", 3]], "mult": 1.0},
		{"at": Vector2(1250, -1750), "lvl": 23, "pack": [["apoctank", 2], ["heavytank", 2]], "mult": 1.6},
		{"at": Vector2(-1850, 1750), "lvl": 24, "pack": [["apoctank", 3], ["demon", 6]], "mult": 1.0},
]

static func _build(id: String, mname: String, region: int, origin: Vector2, defs: Array, boss_at: Vector2, boss_lvl: int) -> MapRun:
	var m := MapRun.new()
	m.map_id = id
	m.map_name = mname
	m.biome = region
	m.bounds = Rect2(origin - Vector2(3300, 2400), Vector2(6600, 4800))
	for d: Dictionary in defs:
		m.zones.append({
			"pos": origin + (d["at"] as Vector2), "lvl": int(d["lvl"]), "pack": d["pack"], "mult": float(d["mult"]),
			"strong": float(d["mult"]) > 1.0, "awake": false, "warned": false, "cleared": false, "mobs": [],
		})
	m.boss = {"pos": origin + boss_at, "lvl": boss_lvl, "awake": false, "done": false}
	return m

func zones_total() -> int:
	return zones.size()

func zones_cleared() -> int:
	var n := 0
	for z in zones:
		if z["cleared"]:
			n += 1
	return n

# The castle may not leave the map.
func clamp_pos(p: Vector2) -> Vector2:
	var lo := bounds.position + Vector2(EDGE_MARGIN, EDGE_MARGIN)
	var hi := bounds.end - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	return Vector2(clampf(p.x, lo.x, hi.x), clampf(p.y, lo.y, hi.y))

# Where the arrow points: the nearest zone that is still asleep or fighting, otherwise the boss.
func target_pos() -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for z in zones:
		if z["cleared"]:
			continue
		var d := _player.distance_to(z["pos"] as Vector2)
		if d < best_d:
			best_d = d
			best = z["pos"]
	if best != Vector2.INF:
		return best
	if not bool(boss["done"]):
		return boss["pos"]
	return Vector2.INF

func tick(player: Vector2, delta: float) -> void:
	_player = player
	_t += delta
	for z in zones:
		if z["cleared"]:
			continue
		var d := player.distance_to(z["pos"] as Vector2)
		if not z["awake"]:
			if bool(z["strong"]) and not z["warned"] and d < WARN_DIST:
				z["warned"] = true
				danger_near.emit(z)
			if d < WAKE_DIST:
				z["awake"] = true
				zone_woke.emit(z)
		else:
			var alive := false
			for e in z["mobs"]:
				if not is_instance_valid(e):          # a dead mob is already freed: never cast it
					continue
				var en := e as Enemy
				if not en.dead and not en.is_queued_for_deletion():
					alive = true
					break
			if not alive:
				z["cleared"] = true
				zone_cleared.emit(z)
	queue_redraw()

func boss_ready() -> bool:
	return not bool(boss["awake"]) and not bool(boss["done"]) and _player.distance_to(boss["pos"] as Vector2) < BOSS_WAKE

func _draw() -> void:
	# the map edge
	draw_rect(bounds, Color(0.85, 0.2, 0.15, 0.55), false, 14.0)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	for z in zones:
		var c: Vector2 = z["pos"]
		if z["cleared"]:
			PixelFx.ring(self, c, 150.0, Color(0.4, 0.9, 0.4, 0.28), 4.0)
			continue
		var col := Color(1.0, 0.35, 0.25) if bool(z["strong"]) else Color(1.0, 0.85, 0.35)
		PixelFx.ring(self, c, 260.0, Color(col.r, col.g, col.b, 0.22 + 0.18 * pulse), 6.0)
		PixelFx.ring(self, c, 120.0, Color(col.r, col.g, col.b, 0.14), 4.0)
	if not bool(boss["done"]):
		var bc: Vector2 = boss["pos"]
		PixelFx.ring(self, bc, 420.0, Color(0.75, 0.3, 1.0, 0.25 + 0.2 * pulse), 8.0)
		PixelFx.ring(self, bc, 220.0, Color(0.75, 0.3, 1.0, 0.18), 6.0)
	# the arrow that circles the castle and points to the next place to go
	var tp := target_pos()
	if tp != Vector2.INF and _player.distance_to(tp) > 500.0:
		var dir := (tp - _player).normalized()
		var tip := _player + dir * 215.0
		var side := dir.orthogonal()
		var pts := PackedVector2Array([tip, tip - dir * 34.0 + side * 17.0, tip - dir * 34.0 - side * 17.0])
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.3, 0.85))
