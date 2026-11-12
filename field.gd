class_name Field
extends RefCounted

# A per-frame snapshot of the mobs, built once per frame no matter how many shots, beams and
# skills ask for it. Before this, every projectile scanned all mobs itself (and created a fresh
# array each time), which got slow in late waves. The coarse grid answers "which mobs are near
# this point" without looking at the rest. Entries can be up to a frame old: callers still
# check e.dead.

const CELL := 128.0

static var _frame: int = -1
static var _mobs: Array[Enemy] = []
static var _enemies: Array[Enemy] = []
static var _bolts: Array[Node2D] = []
static var _shots: Array[Projectile] = []
static var _grid: Dictionary = {}
static var _max_radius: float = 20.0

static func _sync() -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	_mobs.clear()
	_enemies.clear()
	_bolts.clear()
	_shots.clear()
	_grid.clear()
	_max_radius = 20.0
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group("mobs"):
		var e := n as Enemy
		if e == null or e.dead or e.is_queued_for_deletion():
			continue
		_mobs.append(e)
		if not e.is_ally:
			_enemies.append(e)
		_max_radius = maxf(_max_radius, e.radius)
		var key := Vector2i(floori(e.position.x / CELL), floori(e.position.y / CELL))
		if _grid.has(key):
			(_grid[key] as Array).append(e)
		else:
			_grid[key] = [e]
	for n in tree.get_nodes_in_group("bolts"):
		var b := n as Node2D
		if b != null and not b.is_queued_for_deletion():
			_bolts.append(b)
	for n in tree.get_nodes_in_group("shots"):
		var p := n as Projectile
		if p != null and not p.is_queued_for_deletion():
			_shots.append(p)

# Enemies and refugees (everything our shots can hit).
static func mobs() -> Array[Enemy]:
	_sync()
	return _mobs

# Hostile mobs only.
static func enemies() -> Array[Enemy]:
	_sync()
	return _enemies

# Enemy shells, orbs and rockets (they can be shot down).
static func bolts() -> Array[Node2D]:
	_sync()
	return _bolts

# Our own projectiles in flight.
static func shots() -> Array[Projectile]:
	_sync()
	return _shots

# Mobs that could be within r of pos (a superset: check the exact distance yourself).
static func near(pos: Vector2, r: float) -> Array[Enemy]:
	_sync()
	var reach := r + _max_radius + 16.0
	var x0 := floori((pos.x - reach) / CELL)
	var x1 := floori((pos.x + reach) / CELL)
	var y0 := floori((pos.y - reach) / CELL)
	var y1 := floori((pos.y + reach) / CELL)
	var out: Array[Enemy] = []
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var key := Vector2i(cx, cy)
			if _grid.has(key):
				out.append_array(_grid[key] as Array)
	return out
