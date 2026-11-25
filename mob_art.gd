class_name MobArt
extends RefCounted

# Pixel-art sprites for the ordinary mobs, painted in code (no image files). Same look as the map props:
# shaded volumes lit from the upper left, a dark 1-pixel outline, a few walk frames. Rotating units
# (tanks, ships, worms...) are shaded symmetrically and drawn facing right, the game rotates them.
# One art pixel = PX world pixels. Textures are built once per kind and cached.

const PX := 3.0
const ROTATING := []
const FLIPPING := []
# seen from above like the map: painted for 16 headings so the light always comes from the upper left
const DIRECTIONAL := ["soldier", "ally", "medic", "guard", "crew", "bee", "golem", "mudgolem", "demon", "stalker", "b_dark", "herald", "b_seraph", "thornling", "angler", "b_leviathan", "destroyer", "cruiser", "missilecruiser", "carrier", "fighter", "soul", "fallen", "wisp", "phantom", "falcon", "warthog", "stealth", "pillar", "troll", "trollwarrior", "trollcaptain", "trollking", "titan", "ant", "antwarden", "antspitter", "antflyer", "antking", "antqueen", "cursed", "crpg", "cmini", "cgren", "aatruck", "tank", "heavytank", "apoctank", "sinner", "earthworm", "mech", "aegis", "worm", "hunter", "drone", "starship", "corvette", "b_hell", "b_garden", "b_mud", "b_titan", "b_void"]
const DIRS := 16
# frames, and how many frames per unit of the mob's walk phase (see Enemy._walk)
const INFO := {
	"soldier": [4, 0.64], "ally": [4, 0.64], "medic": [4, 0.64], "guard": [4, 0.64], "crew": [4, 0.64], "bee": [2, 3.0],
	"tank": [3, 0.6], "heavytank": [3, 0.6], "apoctank": [3, 0.6], "sinner": [4, 0.5], "earthworm": [4, 0.22], "mech": [2, 0.6], "aegis": [1, 1.0], "worm": [4, 0.22],
	"golem": [4, 0.95], "mudgolem": [4, 0.95], "demon": [4, 0.45], "stalker": [4, 0.8], "b_dark": [4, 0.7], "herald": [2, 2.4], "b_seraph": [2, 2.0], "thornling": [4, 0.8], "b_queen": [4, 0.8], "angler": [4, 0.8], "b_leviathan": [4, 0.7], "destroyer": [1, 1.0], "cruiser": [1, 1.0], "missilecruiser": [1, 1.0], "carrier": [1, 1.0], "fighter": [2, 3.0], "troll": [4, 0.5], "trollwarrior": [4, 0.5], "trollcaptain": [4, 0.5], "trollking": [4, 0.5], "titan": [4, 0.4], "pillar": [1, 1.0], "ant": [4, 0.4], "antwarden": [4, 0.4], "antspitter": [4, 0.4], "antflyer": [4, 1.2], "antking": [4, 0.4], "antqueen": [4, 0.4], "cursed": [4, 0.64], "crpg": [4, 0.64], "cmini": [4, 0.64], "cgren": [4, 0.64], "aatruck": [3, 0.6], "soul": [4, 0.5], "fallen": [4, 2.0], "wisp": [2, 3.0], "phantom": [2, 3.0], "falcon": [2, 3.0], "warthog": [2, 3.0], "stealth": [2, 3.0], "hunter": [2, 1.5], "drone": [2, 1.5],
	"starship": [2, 1.5], "corvette": [2, 1.5], "void": [2, 0.25],
	"b_garden": [1, 1.0], "b_leaves": [10, 1.0], "b_mud": [1, 1.0], "b_titan": [1, 1.0],
	"b_void": [2, 1.0], "b_hell": [4, 1.0],
	"castle0": [1, 1.0], "castle1": [1, 1.0], "castle2": [1, 1.0], "castle3": [1, 1.0], "castle4": [1, 1.0],
}
# Procedural motion on top of the frames (no extra textures): 1 walkers bob and squash with every step,
# 2 vehicles rumble, 3 flyers and ghosts hover.
const WALKERS := ["soldier", "ally", "medic", "guard", "crew", "sinner", "golem", "mudgolem", "demon", "stalker", "thornling", "fallen", "troll", "trollwarrior", "trollcaptain", "trollking", "titan", "ant", "antwarden", "antspitter", "antking", "antqueen", "cursed", "crpg", "cmini", "cgren"]
const RUMBLERS := ["tank", "heavytank", "apoctank", "mech", "aatruck", "aegis"]
const SHIPS := ["destroyer", "cruiser", "missilecruiser", "carrier"]
const HOVERERS := ["bee", "herald", "wisp", "antflyer", "drone", "starship", "corvette", "hunter", "void", "soul"]

static func gait_of(key: String) -> int:
	if WALKERS.has(key):
		return 1
	if RUMBLERS.has(key):
		return 2
	if HOVERERS.has(key):
		return 3
	if SHIPS.has(key):
		return 4
	return 0

const GROUND_SQUASH := 0.82      # sin(ELEV): how much a circle on the ground is flattened by the camera tilt
const BOSS_R := 16.0      # body radius of the boss sprites, in art pixels

static var _cache: Dictionary = {}      # key -> {"n": int, "tex": Array, "flash": Array}

static func key_for(kind: String, space: bool, ally: bool) -> String:
	if ally:
		return "ally"
	match kind:
		"boss":
			return ""
		"tank":
			return "starship" if space else "tank"
		"heavytank":
			return "starship" if space else "heavytank"
		"apoctank":
			return "starship" if space else "apoctank"
		"mech":
			return "corvette" if space else "mech"
		"soldier":
			return "drone" if space else "soldier"
		"worm", "earthworm", "sinner", "golem", "demon", "stalker", "herald", "thornling", "angler", "destroyer", "cruiser", "missilecruiser", "carrier", "fighter", "pillar", "troll", "trollwarrior", "trollcaptain", "trollking", "titan", "ant", "antwarden", "antspitter", "antflyer", "antking", "antqueen", "cursed", "crpg", "cmini", "cgren", "aatruck", "soul", "fallen", "wisp", "phantom", "falcon", "warthog", "stealth", "hunter", "void", "bee", "medic", "aegis":
			return kind
	return "soldier"

static func boss_key(ability: String) -> String:
	match ability:
		"speed":
			return "b_garden"
		"regen":
			return "b_mud"
		"titan":
			return "b_titan"
		"void":
			return "b_void"
		"dark":
			return "b_dark"
		"seraph":
			return "b_seraph"
		"queen":
			return "b_queen"
		"leviathan":
			return "b_leviathan"
	return "b_hell"

# infantry is drawn smaller than the vehicles so tanks and mechs look big next to it
static func scale_for(key: String) -> float:
	match key:
		"soldier", "ally", "medic", "guard", "crew", "sinner", "soul", "cursed", "crpg", "cmini", "cgren":
			return 0.62
		"bee":
			return 0.7
		"golem", "mudgolem":
			return 0.9
		"demon":
			return 0.72
		"stalker":
			return 0.85
		"herald":
			return 0.8
		"thornling":
			return 0.85
		"angler":
			return 0.85
		"destroyer":
			return 1.0
		"cruiser":
			return 0.6
		"missilecruiser":
			return 1.2
		"carrier":
			return 1.5
		"fighter":
			return 0.8
		"ant":
			return 0.7
		"troll", "trollwarrior", "trollcaptain", "trollking", "titan":
			return 0.8
		"pillar":
			return 0.9
		"antwarden", "antspitter", "antflyer":
			return 0.62
		"antking", "antqueen":
			return 0.6
		"soul":
			return 1.0
		"fallen":
			return 1.0
		"wisp":
			return 0.9
		"phantom", "falcon", "warthog", "stealth":
			return 0.8
		"aegis":
			return 0.9
	return 1.0

static func rotates(key: String) -> bool:
	return ROTATING.has(key)

static func flips(key: String) -> bool:
	return FLIPPING.has(key)

static func frame_count(key: String) -> int:
	return int((INFO[key] as Array)[0])

static func frame_rate(key: String) -> float:
	return float((INFO[key] as Array)[1])

static func directional(key: String) -> bool:
	return DIRECTIONAL.has(key)

static func dir_of(heading: float) -> int:
	return posmod(roundi(heading / TAU * float(DIRS)), DIRS)

# ---- sprite cache -------------------------------------------------------------------------------------------
# Painting a 3D unit takes a moment, so only the first picture of a kind is painted at once; the other headings
# are painted on a background thread and used as soon as they are ready (until then the nearest ready heading
# is shown). prewarm() paints the common kinds while the menu is open.

static var _mutex := Mutex.new()
static var _done: Array = []        # [key, dir, result]
static var _pending: Dictionary = {}
static var _drain_frame: int = -1

static func _ck(key: String, dir: int) -> String:
	return "%s#%d" % [key, dir] if DIRECTIONAL.has(key) else key

# Paints every frame of one kind/heading into Images. Safe to run on a thread.
static func _build(key: String, dir: int) -> Dictionary:
	if ShipPng.has(key):                 # ships are baked offline: painting them at runtime caused hitches
		return ShipPng.build(key, dir)
	var ang := TAU * float(dir) / float(DIRS) if DIRECTIONAL.has(key) else 0.0
	var imgs: Array = []
	var fimgs: Array = []
	var off := Vector2.ZERO
	for f in frame_count(key):
		var cv := _paint(key, f, ang)
		cv.outline()
		if cv.anchor_y >= 0.0:
			off = Vector2(0.0, float(cv.h) * 0.5 - (cv.anchor_y - 3.0))      # feet stand on the unit's position
		imgs.append(cv.img)
		var fi := cv.img.duplicate() as Image
		for y in fi.get_height():
			for x in fi.get_width():
				var c := fi.get_pixel(x, y)
				if c.a > 0.5:
					fi.set_pixel(x, y, c.lerp(Color.WHITE, 0.75))
		fimgs.append(fi)
	return {"imgs": imgs, "fimgs": fimgs, "off": off}

static func _to_entry(res: Dictionary) -> Dictionary:
	var tex: Array = []
	var flash: Array = []
	for im: Image in (res["imgs"] as Array):
		tex.append(ImageTexture.create_from_image(im))
	for im: Image in (res["fimgs"] as Array):
		flash.append(ImageTexture.create_from_image(im))
	return {"n": tex.size(), "tex": tex, "flash": flash, "off": res["off"]}

# One sprite per task, spread over every CPU core by the engine's thread pool.
static func _job(key: String, dir: int) -> void:
	var res := _build(key, dir)
	_mutex.lock()
	_done.append([key, dir, res])
	_mutex.unlock()

static func _request(key: String, dir: int) -> void:
	var ck := _ck(key, dir)
	if _pending.has(ck) or _cache.has(ck):
		return
	_pending[ck] = true
	WorkerThreadPool.add_task(_job.bind(key, dir), false, "mob sprite")

static func _drain() -> void:
	var fr := Engine.get_frames_drawn()
	if fr == _drain_frame:
		return
	_drain_frame = fr
	for i in 3:
		_mutex.lock()
		var item: Array = [] if _done.is_empty() else _done.pop_front()
		_mutex.unlock()
		if item.is_empty():
			return
		var ck := _ck(item[0], int(item[1]))
		_cache[ck] = _to_entry(item[2])
		_pending.erase(ck)

# Paint the common kinds in the background (call while a menu is showing).
static func prewarm() -> void:
	CastleArt._pals()                  # fill the palettes here, not from the worker thread
	for key in ["soldier", "ally", "medic", "guard", "crew", "tank", "mech", "bee", "golem", "mudgolem", "worm", "aegis", "sinner", "earthworm", "heavytank", "apoctank"]:
		for d in [0, 4, 8, 12]:
			_request(key, d)

static func frames(key: String, dir: int = 0) -> Dictionary:
	_drain()
	var ck := _ck(key, dir)
	if _cache.has(ck):
		return _cache[ck]
	if not DIRECTIONAL.has(key):
		_cache[ck] = _to_entry(_build(key, 0))
		return _cache[ck]
	# a heading that is not painted yet: ask for it, and show the nearest one that is ready
	_request(key, dir)
	for step in range(1, DIRS / 2 + 1):
		for sgn in [-1, 1]:
			var nk := _ck(key, posmod(dir + sgn * step, DIRS))
			if _cache.has(nk):
				return _cache[nk]
	var entry := _to_entry(_build(key, dir))        # the very first picture of this kind is painted right away
	_cache[ck] = entry
	return entry

# ---------- a tiny pixel canvas; (0, 0) is the middle ----------

class Cv extends RefCounted:
	var w: int
	var h: int
	var ox: int
	var oy: int
	var anchor_y: float = -1.0     # picture row of the ground point under a 3D unit (see Scene3)
	var img: Image

	func _init(wd: int, ht: int) -> void:
		w = wd
		h = ht
		ox = int(wd * 0.5)
		oy = int(ht * 0.5)
		img = Image.create(wd, ht, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))

	func px(x: int, y: int, c: Color) -> void:
		var xx := x + ox
		var yy := y + oy
		if xx >= 0 and yy >= 0 and xx < w and yy < h:
			img.set_pixel(xx, yy, c)

	# a ball lit from the upper left; pixels below row `clip` are skipped
	func sph(cx: int, cy: int, rx: float, ry: float, pal: Array, clip: int = 1000) -> void:
		for dy in range(-int(ry), int(ry) + 1):
			for dx in range(-int(rx), int(rx) + 1):
				var e := float(dx * dx) / (rx * rx) + float(dy * dy) / (ry * ry)
				if e <= 1.0:
					if cy + dy > clip:
						continue
					var nz := sqrt(1.0 - e)
					var nx := float(dx) / rx
					var ny := float(dy) / ry
					var l := clampf(0.5 - (nx * 0.55 + ny * 0.7) * 0.5 + nz * 0.22, 0.0, 0.999)
					px(cx + dx, cy + dy, pal[mini(int(l * float(pal.size() - 1) + 0.5), pal.size() - 1)])

	# symmetric shading: bright in the middle (for sprites that rotate)
	func dome(cx: int, cy: int, rx: float, ry: float, pal: Array) -> void:
		for dy in range(-int(ry), int(ry) + 1):
			for dx in range(-int(rx), int(rx) + 1):
				var e := float(dx * dx) / (rx * rx) + float(dy * dy) / (ry * ry)
				if e <= 1.0:
					var l := clampf(1.0 - e * 0.9, 0.0, 0.999)
					px(cx + dx, cy + dy, pal[mini(int(l * float(pal.size() - 1) + 0.5), pal.size() - 1)])

	# a box lit from the upper left: light top/left edges, dark bottom/right
	func box(x: int, y: int, bw: int, bh: int, pal: Array) -> void:
		for j in bh:
			for i in bw:
				var c: Color = pal[2]
				if j == 0 or i == 0:
					c = pal[3]
				if i == bw - 1 or j == bh - 1:
					c = pal[0] if (i == bw - 1 and j == bh - 1) else pal[1]
				px(x + i, y + j, c)

	# a box with a bright middle and a dark rim (for sprites that rotate)
	func sbox(x: int, y: int, bw: int, bh: int, pal: Array) -> void:
		for j in bh:
			for i in bw:
				var edge := mini(mini(i, j), mini(bw - 1 - i, bh - 1 - j))
				px(x + i, y + j, pal[3] if edge >= 2 else (pal[2] if edge == 1 else pal[1]))

	var ang: float = 0.0       # heading the sprite is painted for (parts are rotated, the light stays upper left)

	func rp(x: float, y: float) -> Vector2:
		var c := cos(ang)
		var s := sin(ang)
		return Vector2(x * c - y * s, x * s + y * c)

	# an ellipse seen from above, centre (cx, cy) in the unit's own frame (x = forward), shaded by the fixed light
	func ell(cx: float, cy: float, ax: float, ay: float, pal: Array, ra: float = 0.0) -> void:
		var p := rp(cx, cy)
		var a := ang + ra
		var ca := cos(a)
		var sa := sin(a)
		var rr := int(maxf(ax, ay)) + 1
		var pcx := roundf(p.x)
		var pcy := roundf(p.y)
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				var wx := float(dx) + (pcx - p.x)
				var wy := float(dy) + (pcy - p.y)
				var u := wx * ca + wy * sa
				var v := -wx * sa + wy * ca
				var e := (u * u) / (ax * ax) + (v * v) / (ay * ay)
				if e > 1.0:
					continue
				var nz := sqrt(1.0 - e)
				var nx := u / ax
				var ny := v / ay
				var wnx := nx * ca - ny * sa
				var wny := nx * sa + ny * ca
				var l := clampf(0.5 - (wnx * 0.55 + wny * 0.7) * 0.5 + nz * 0.22, 0.0, 0.999)
				px(int(pcx) + dx, int(pcy) + dy, pal[mini(int(l * float(pal.size() - 1) + 0.5), pal.size() - 1)])

	# a rounded bar between two points of the unit's frame
	func cap(x0: float, y0: float, x1: float, y1: float, wd: float, pal: Array) -> void:
		var a := Vector2(x0, y0)
		var b := Vector2(x1, y1)
		var mid := (a + b) * 0.5
		var d := b - a
		ell(mid.x, mid.y, d.length() * 0.5 + wd * 0.5, wd * 0.5, pal, d.angle())

	func polyr(pts: Array, pal: Array) -> void:
		var out: Array = []
		for q: Vector2 in pts:
			out.append(rp(q.x, q.y))
		poly(out, pal)

	func liner(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
		var a := rp(x0, y0)
		var b := rp(x1, y1)
		line(roundi(a.x), roundi(a.y), roundi(b.x), roundi(b.y), c)

	func pxr(x: float, y: float, c: Color) -> void:
		var a := rp(x, y)
		px(roundi(a.x), roundi(a.y), c)

	func _inside(x: float, y: float, pts: Array) -> bool:
		var ins := false
		var j := pts.size() - 1
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[j]
			if (a.y > y) != (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y + 0.000001) + a.x:
				ins = not ins
			j = i
		return ins

	func polyc(pts: Array, c: Color) -> void:
		poly(pts, [], false, c)

	func poly(pts: Array, pal: Array, sym: bool = false, c: Color = Color(0, 0, 0, 0)) -> void:
		var x0 := 100000
		var x1 := -100000
		var y0 := 100000
		var y1 := -100000
		for p: Vector2 in pts:
			x0 = mini(x0, int(p.x))
			x1 = maxi(x1, int(p.x))
			y0 = mini(y0, int(p.y))
			y1 = maxi(y1, int(p.y))
		var cx := float(x0 + x1) * 0.5
		var cy := float(y0 + y1) * 0.5
		var rr := maxf(float(maxi(x1 - x0, y1 - y0)), 1.0) * 0.5
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if _inside(float(x) + 0.5, float(y) + 0.5, pts):
					if pal.is_empty():
						px(x, y, c)
						continue
					var l: float
					if sym:
						l = 1.0 - 0.8 * minf(Vector2(float(x) - cx, float(y) - cy).length() / rr, 1.0)
					else:
						l = 0.5 - ((float(x) - cx) * 0.55 + (float(y) - cy) * 0.7) / rr * 0.5
					px(x, y, pal[clampi(int(l * float(pal.size() - 1) + 0.5), 0, pal.size() - 1)])

	func line(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		var n := maxi(absi(x1 - x0), absi(y1 - y0)) + 1
		for i in n + 1:
			var t := float(i) / float(maxi(n, 1))
			px(roundi(float(x0) + float(x1 - x0) * t), roundi(float(y0) + float(y1 - y0) * t), c)

	func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
		for j in rh:
			for i in rw:
				px(x + i, y + j, c)

	# a dark 1-pixel outline around everything painted
	func outline() -> void:
		var edge: Array = []
		for y in h:
			for x in w:
				if img.get_pixel(x, y).a > 0.5:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var xx: int = x + (d as Vector2i).x
					var yy: int = y + (d as Vector2i).y
					if xx >= 0 and yy >= 0 and xx < w and yy < h and img.get_pixel(xx, yy).a > 0.5:
						edge.append(Vector2i(x, y))
						break
		for e: Vector2i in edge:
			img.set_pixel(e.x, e.y, Color(0.05, 0.04, 0.09))


# ---------- a tiny 3D painter: ellipsoids seen from the same tilted camera as the map ----------
# Units are built from a few ellipsoids (x = forward, y = sideways, z = up), turned to the unit's heading and
# shaded per pixel by the same light as the map (upper left), then banded into a pixel palette.

const ELEV := 55.0        # camera elevation in degrees: 90 = straight down, 0 = side view. Match it to the map.

class Scene3 extends RefCounted:
	var rot: Basis
	var lt := Vector3(-0.55, -0.5, 0.75).normalized()      # direction towards the light
	var prims: Array = []     # [centre Vector3, radii Vector3, Basis, palette Array]
	var us: float = 1.0       # unit scale: every size and position below is multiplied by it (finer pixels for big models)

	func _init(a: float) -> void:
		rot = Basis(Vector3(0, 0, 1), a)

	func ell(c: Vector3, r: Vector3, pal: Array, tilt: Basis = Basis.IDENTITY) -> void:
		prims.append([rot * (c * us), r * us, rot * tilt, pal, 0])

	# a box with half sizes h (hard edges: hulls, treads, bodies)
	func box(c: Vector3, h: Vector3, pal: Array, tilt: Basis = Basis.IDENTITY) -> void:
		prims.append([rot * (c * us), h * us, rot * tilt, pal, 1])

	# an upright cylinder: c = middle of the cylinder, r = radius, hh = half height (flat top: towers, drums)
	func cyl(c: Vector3, r: float, hh: float, pal: Array) -> void:
		prims.append([rot * (c * us), Vector3(r, r, hh) * us, rot, pal, 3])

	# an upright cone: c = middle of the cone, r = radius at the bottom, hh = half height (roofs, spires)
	func cone(c: Vector3, r: float, hh: float, pal: Array) -> void:
		prims.append([rot * (c * us), Vector3(r, r, hh) * us, rot, pal, 2])

	# a rounded bar between two points
	func cap(a: Vector3, b: Vector3, r: float, pal: Array) -> void:
		a *= us
		b *= us
		r *= us
		var d := b - a
		var ln := d.length()
		var x := d / ln
		var z0 := Vector3(0, 0, 1)
		if absf(x.dot(z0)) > 0.95:
			z0 = Vector3(0, 1, 0)
		var y := z0.cross(x).normalized()
		var z := x.cross(y)
		prims.append([rot * ((a + b) * 0.5), Vector3(ln * 0.5 + r, r, r), rot * Basis(x, y, z), pal, 0])

	# gy = the row of the picture where the ground point under the unit's centre lands
	func render(w: int, h: int, gy: float) -> MobArt.Cv:
		var cv := MobArt.Cv.new(w, h)
		cv.anchor_y = gy
		var ph := deg_to_rad(MobArt.ELEV)
		var cam := Vector3(0, cos(ph), sin(ph))
		var up := Vector3(0, -sin(ph), cos(ph))
		var light := lt
		var n := prims.size()
		var cs: Array = []
		var rs: Array = []
		var mts: Array = []
		var ds: Array = []
		var d2s: Array = []
		var aas: Array = []
		var kinds: Array = []
		var invs: Array = []
		for i in n:
			var pr: Array = prims[i]
			var r: Vector3 = pr[1]
			var mt: Basis = (pr[2] as Basis).transposed()
			var d: Vector3 = mt * cam
			var d2: Vector3 = d / r
			cs.append(pr[0])
			rs.append(r)
			mts.append(mt)
			ds.append(d)
			d2s.append(d2)
			aas.append(d2.dot(d2))
			kinds.append(pr[4])
			invs.append(Vector3(1.0 / (d.x if absf(d.x) > 1.0e-9 else 1.0e-9), 1.0 / (d.y if absf(d.y) > 1.0e-9 else 1.0e-9), 1.0 / (d.z if absf(d.z) > 1.0e-9 else 1.0e-9)))
		# screen-space bounds of every part, so a pixel only tests the parts that can cover it
		var bx: Array = []
		var by: Array = []
		var br: Array = []
		for i in n:
			var c3: Vector3 = cs[i]
			var rr: Vector3 = rs[i]
			bx.append(c3.x)
			by.append(c3.y * sin(ph) - c3.z * cos(ph) + gy)
			br.append(maxf(rr.x, maxf(rr.y, rr.z)) * 1.75 + 1.0)
		for py in h:
			for pxx in w:
				var sx := float(pxx) + 0.5 - float(w) * 0.5
				var sy := float(py) + 0.5 - gy
				var p0 := Vector3(sx, 0, 0) + up * (-sy)
				var best := -1.0e9
				var hit := -1
				var hl := Vector3.ZERO
				var hn := Vector3.ZERO
				var spx := float(pxx) + 0.5
				var spy := float(py) + 0.5
				for i in n:
					var brr: float = br[i]
					if absf(spx - float(w) * 0.5 - float(bx[i])) > brr or absf(spy - float(by[i])) > brr:
						continue
					var r: Vector3 = rs[i]
					var mt: Basis = mts[i]
					var o: Vector3 = mt * (p0 - (cs[i] as Vector3))
					if int(kinds[i]) == 1:
						var iv: Vector3 = invs[i]
						var t1 := (-r - o) * iv
						var t2 := (r - o) * iv
						var lo := Vector3(minf(t1.x, t2.x), minf(t1.y, t2.y), minf(t1.z, t2.z))
						var hi := Vector3(maxf(t1.x, t2.x), maxf(t1.y, t2.y), maxf(t1.z, t2.z))
						var tmin := maxf(lo.x, maxf(lo.y, lo.z))
						var tmax := minf(hi.x, minf(hi.y, hi.z))
						if tmax < tmin or tmax <= best:
							continue
						var ax := 0
						if hi.y < hi.x and hi.y <= hi.z:
							ax = 1
						elif hi.z < hi.x and hi.z < hi.y:
							ax = 2
						var dv: Vector3 = ds[i]
						var nl := Vector3.ZERO
						nl[ax] = 1.0 if dv[ax] > 0.0 else -1.0
						best = tmax
						hit = i
						hl = o + dv * tmax
						hn = nl
						continue
					if int(kinds[i]) >= 2:
						var oc: Vector3 = o / r
						var dc: Vector3 = d2s[i]
						var tt := -1.0e9
						var nl2 := Vector3.ZERO
						if int(kinds[i]) == 3:
							if absf(dc.z) > 1.0e-9:
								var tc := (1.0 - oc.z) / dc.z
								var qx := oc.x + dc.x * tc
								var qy := oc.y + dc.y * tc
								if qx * qx + qy * qy <= 1.0:
									tt = tc
									nl2 = Vector3(0, 0, 1)
							var a3 := dc.x * dc.x + dc.y * dc.y
							if a3 > 1.0e-9:
								var b3 := oc.x * dc.x + oc.y * dc.y
								var c3 := oc.x * oc.x + oc.y * oc.y - 1.0
								var dd := b3 * b3 - a3 * c3
								if dd >= 0.0:
									var sq := sqrt(dd)
									for sg: float in [1.0, -1.0]:
										var ts := (-b3 + sg * sq) / a3
										var zz := oc.z + dc.z * ts
										if zz >= -1.0 and zz <= 1.0 and ts > tt:
											tt = ts
											nl2 = Vector3((oc.x + dc.x * ts) / r.x, (oc.y + dc.y * ts) / r.y, 0.0)
						else:
							var ac := dc.x * dc.x + dc.y * dc.y - dc.z * dc.z * 0.25
							var bc := oc.x * dc.x + oc.y * dc.y + (1.0 - oc.z) * dc.z * 0.25
							var cc := oc.x * oc.x + oc.y * oc.y - (1.0 - oc.z) * (1.0 - oc.z) * 0.25
							if absf(ac) > 1.0e-9:
								var dd2 := bc * bc - ac * cc
								if dd2 >= 0.0:
									var sq2 := sqrt(dd2)
									for sg2: float in [1.0, -1.0]:
										var ts2 := (-bc + sg2 * sq2) / ac
										var zz2 := oc.z + dc.z * ts2
										if zz2 >= -1.0 and zz2 <= 1.0 and ts2 > tt:
											tt = ts2
											var gx := oc.x + dc.x * ts2
											var gy2 := oc.y + dc.y * ts2
											nl2 = Vector3(2.0 * gx / r.x, 2.0 * gy2 / r.y, (1.0 - zz2) * 0.5 / r.z)
						if tt > best and tt > -1.0e8:
							best = tt
							hit = i
							hn = nl2
						continue
					var o2: Vector3 = o / r
					var d2: Vector3 = d2s[i]
					var a: float = aas[i]
					var b := o2.dot(d2)
					var disc := b * b - a * (o2.dot(o2) - 1.0)
					if disc < 0.0:
						continue
					var t := (-b + sqrt(disc)) / a
					if t > best:
						best = t
						hit = i
						hl = o + (ds[i] as Vector3) * t
						hn = Vector3.ZERO
				if hit >= 0:
					var pr: Array = prims[hit]
					var r: Vector3 = pr[1]
					var nrm: Vector3 = ((pr[2] as Basis) * (hl / (r * r))).normalized()
					if int(pr[4]) >= 1:
						nrm = ((pr[2] as Basis) * hn).normalized()
					var lv := clampf(0.04 + 0.80 * maxf(nrm.dot(light), 0.0) + 0.16 * maxf(nrm.dot(cam), 0.0), 0.0, 0.999)
					var pal: Array = pr[3]
					cv.img.set_pixel(pxx, py, pal[mini(int(lv * float(pal.size())), pal.size() - 1)])
		return cv

static func _rz(a: float) -> Basis:
	return Basis(Vector3(0, 0, 1), a)

static func _rx(a: float) -> Basis:
	return Basis(Vector3(1, 0, 0), a)

# ---------- helpers ----------

static func _hx(s: String) -> Color:
	return Color.html(s)

static func _P(list: Array) -> Array:
	var out: Array = []
	for s in list:
		out.append(Color.html(str(s)))
	return out

static func _paint(key: String, f: int, ang: float = 0.0) -> Cv:
	if key.begins_with("castle"):
		return CastleArt.paint(int(key.substr(6)))
	match key:
		"soldier":
			return _soldier(f, ang, 0)
		"troll":
			return _troll(f, ang, 0)
		"trollwarrior":
			return _troll(f, ang, 1)
		"trollcaptain":
			return _troll(f, ang, 2)
		"trollking":
			return _troll(f, ang, 3)
		"titan":
			return _troll(f, ang, 4)
		"ant":
			return _ant(f, ang, 0)
		"antwarden":
			return _ant(f, ang, 1)
		"antspitter":
			return _ant(f, ang, 2)
		"antflyer":
			return _ant(f, ang, 3)
		"antking":
			return _ant(f, ang, 4)
		"antqueen":
			return _ant(f, ang, 5)
		"cursed":
			return _soldier(f, ang, 7)
		"crpg":
			return _soldier(f, ang, 8)
		"cmini":
			return _soldier(f, ang, 9)
		"cgren":
			return _soldier(f, ang, 10)
		"aatruck":
			return _aatruck(f, ang)
		"ally":
			return _soldier(f, ang, 1)
		"medic":
			return _soldier(f, ang, 2)
		"guard":
			return _soldier(f, ang, 4)
		"crew":
			return _soldier(f, ang, 5)
		"bee":
			return _bee(f, ang)
		"tank":
			return _tank(f, ang)
		"heavytank":
			return _tank(f, ang, 1)
		"apoctank":
			return _tank(f, ang, 2)
		"sinner":
			return _soldier(f, ang, 3)
		"earthworm":
			return _worm(f, ang, true)
		"mech":
			return _mech(f, ang)
		"aegis":
			return _aegis(ang)
		"worm":
			return _worm(f, ang)
		"golem":
			return _golem(f, ang)
		"mudgolem":
			return _golem(f, ang, true)
		"demon":
			return _demon(f, ang)
		"stalker":
			return _stalker(f, ang)
		"b_dark":
			return _troll(f, ang, 5)
		"pillar":
			return _pillar(f, ang)
		"herald":
			return _herald(f, ang)
		"thornling":
			return _thornling(f, ang)
		"angler":
			return _angler(f, ang)
		"destroyer":
			return _destroyer(f, ang)
		"cruiser":
			return _cruiser(f, ang)
		"missilecruiser":
			return _missilecruiser(f, ang)
		"carrier":
			return _carrier(f, ang)
		"fighter":
			return _fighter(f, ang)
		"soul":
			return _soldier(f, ang, 6)
		"fallen":
			return _fallen(f, ang)
		"wisp":
			return _wisp(f, ang)
		"phantom":
			return _phantom(f, ang)
		"falcon":
			return _falcon(f, ang)
		"warthog":
			return _warthog(f, ang)
		"stealth":
			return _stealth(f, ang)
		"b_leviathan":
			return _b_leviathan(f, ang)
		"b_queen":
			return _b_queen(f, ang)
		"b_seraph":
			return _b_seraph(f, ang)
		"hunter":
			return _hunter(f, ang)
		"drone":
			return _drone(f, ang)
		"starship":
			return _starship(f, ang)
		"corvette":
			return _corvette(f, ang)
		"b_garden":
			return _b_garden(ang)
		"b_leaves":
			return _b_leaves(f)
		"b_mud":
			return _b_mud(ang)
		"b_titan":
			return _b_titan(ang)
		"b_void":
			return _b_void(f, ang)
		"b_hell":
			return _b_hell(f, ang)
	return _void(f)

# ---------- the mobs ----------

static func _soldier(f: int, ang: float, role: int) -> Cv:
	# role 0 soldier, 1 refugee (ally), 2 medic
	var s := Scene3.new(ang)
	var sw: float = [0.0, 2.2, 0.0, -2.2][f % 4]
	var skin := _P(["6a4a38", "a87a5a", "d8a880", "f0c8a0"])
	var jac: Array
	var hel: Array
	var pants: Array
	match role:
		1:
			jac = _P(["2a1418", "7a2a2a", "b04040", "d86060"])
			hel = _P(["3a0c12", "6a1820", "a02a34", "c8505a"])
			pants = _P(["14160f", "22261a", "343a28", "47503a"])
		2:
			jac = _P(["9aa89a", "c8d4c8", "e8f0e8", "ffffff"])
			hel = _P(["a8b4a8", "d0dcd0", "f0f8f0", "ffffff"])
			pants = _P(["2a382a", "3a4a3a", "4a5c4a", "5e7260"])
		4:   # Skyhold guard: blue coat, gold helmet
			jac = _P(["0e1632", "1a2a5e", "2c4896", "486cc4"])
			hel = _P(["4a2e06", "86580a", "c08c18", "e8b82a"])
			pants = _P(["12121a", "22222e", "383848", "50505e"])
		5:   # deck engineer: orange overalls, yellow hard hat
			jac = _P(["3a1606", "7a3410", "c0601c", "ec8c30"])
			hel = _P(["4a3406", "8a6a0c", "d0a020", "f8d048"])
			pants = _P(["1a120a", "2e2214", "453620", "5c4a2c"])
		6:   # Lesser Soul: the grey-white cousin of the Sinner
			jac = _P(["70707e", "a0a0b0", "d0d0de", "f2f2fa"])
			hel = _P(["686876", "9898a8", "c8c8d8", "ececf6"])
			pants = _P(["606070", "8a8a9a", "b4b4c4", "d8d8e6"])
			skin = _P(["8a8a9a", "b0b0c0", "d6d6e4", "f0f0fa"])
			sw *= 0.6
		7, 8, 9, 10:   # Cursed Soldiers: the default soldier in a dark violet tone with sickly green skin
			jac = _P(["1a1428", "2e2244", "4a3a6a", "6a5496"])
			hel = _P(["100c1c", "1e1832", "32284c", "4a3e6c"])
			pants = _P(["0e0a18", "1a1428", "2a2040", "3a3058"])
			skin = _P(["2a382a", "44583f", "6a8668", "8aa888"])
		3:   # Sinner: all black, unarmed
			jac = _P(["030303", "0c0c0e", "18181c", "282830"])
			hel = _P(["020202", "08080a", "101014", "1c1c22"])
			pants = _P(["020202", "0a0a0c", "141418", "202026"])
			skin = _P(["0a0a0c", "16161c", "26262e", "3a3a46"])
			sw *= 0.6
		_:
			jac = _P(["1f2a14", "2f4020", "47602f", "6a8a45"])
			hel = _P(["1c2614", "2c3a1e", "3e5229", "567338"])
			pants = _P(["14160f", "22261a", "343a28", "47503a"])
	s.cap(Vector3(sw, -1.8, 1.5), Vector3(sw * 0.5, -1.8, 6.5), 1.6, pants)
	s.cap(Vector3(-sw, 1.8, 1.5), Vector3(-sw * 0.5, 1.8, 6.5), 1.6, pants)
	s.ell(Vector3(0, 0, 9.5), Vector3(2.6, 4.0, 4.4), jac)
	if role == 0 or role == 4:
		s.ell(Vector3(-2.8, 0, 10), Vector3(1.6, 2.6, 3.0), _P(["0e1409", "1a2310", "2a3a1a", "3a5024"]))
	elif role >= 7:
		s.ell(Vector3(-2.8, 0, 10), Vector3(1.6, 2.6, 3.0), _P(["0a0814", "16102a", "241a3e", "342a52"]))
	if role == 3 or role == 6:       # zombie walk: both arms stretched out in front, swaying
		var sway := sw * 0.5
		s.cap(Vector3(0, -4.0, 11.5), Vector3(9.0, -3.2 + sway, 11.0), 1.5, jac)
		s.cap(Vector3(0, 4.0, 11.5), Vector3(9.0, 3.2 + sway, 11.4), 1.5, jac)
		s.ell(Vector3(10.0, -3.2 + sway, 11.0), Vector3(1.2, 1.2, 1.2), skin)
		s.ell(Vector3(10.0, 3.2 + sway, 11.4), Vector3(1.2, 1.2, 1.2), skin)
	else:
		s.cap(Vector3(0, -4.0, 11.5), Vector3(3.5, -3.5, 8.5), 1.5, jac)
		s.cap(Vector3(0, 4.0, 11.5), Vector3(4.5, 3.0, 9.0), 1.5, jac)
		s.ell(Vector3(4.2, -3.4, 8.4), Vector3(1.2, 1.2, 1.2), skin)
		s.ell(Vector3(5.2, 3.0, 9.0), Vector3(1.2, 1.2, 1.2), skin)
	var metal := _P(["14141e", "2a2a3a", "44445a", "64647e"])
	if role == 0 or role == 4:
		s.cap(Vector3(-2, 3.0, 9.4), Vector3(9.5, 3.0, 9.4), 0.9, _P(["0a0b08", "1c1e18", "2e3126", "444838"]))
	if role == 7:                                        # cursed rifleman
		s.cap(Vector3(-2, 3.0, 9.4), Vector3(9.5, 3.0, 9.4), 0.9, metal)
	if role == 8:                                        # RPG on the shoulder
		s.cap(Vector3(-7, 3.2, 13.6), Vector3(9, 3.2, 13.6), 1.7, metal)
		s.cap(Vector3(8, 3.2, 13.6), Vector3(10, 3.2, 13.6), 2.1, _P(["1a1a24", "30303e"]))
		s.ell(Vector3(12, 3.2, 13.6), Vector3(2.2, 1.8, 1.8), _P(["50186e", "a040e0", "e090ff"]))
		s.cap(Vector3(1, 3.2, 11.8), Vector3(1, 3.2, 13.6), 0.7, metal)
	if role == 9:                                        # minigun: a bundle of barrels and an ammo drum
		var bar := [[0.0, 0.0], [1.0, 0.9], [-1.0, 0.9], [1.0, -0.9], [-1.0, -0.9]]
		for bo: Array in bar:
			s.cap(Vector3(2, 3.0 + float(bo[0]), 9.4 + float(bo[1])), Vector3(11.5, 3.0 + float(bo[0]), 9.4 + float(bo[1])), 0.55, metal)
		s.cap(Vector3(10, 3.0, 9.4), Vector3(12, 3.0, 9.4), 1.5, _P(["1a1a24", "30303e"]))
		s.ell(Vector3(0.5, 5.2, 8.2), Vector3(2.0, 2.0, 2.4), _P(["3a2a10", "7a5a20", "c09030"]))
	if role == 10:                                       # grenadier: a grenade in hand and a bandolier
		s.ell(Vector3(6.0, 3.0, 10.6), Vector3(1.5, 1.5, 1.5), _P(["142410", "24441c", "3c6a2c"]))
		s.ell(Vector3(6.6, 3.0, 12.2), Vector3(0.5, 0.5, 0.8), _P(["c0b0a0"]))
		for k in 4:
			s.ell(Vector3(2.4, -3.0 + float(k) * 2.0, 11.2), Vector3(0.9, 0.9, 0.9), _P(["142410", "24441c", "3c6a2c"]))
	s.ell(Vector3(0.4, 0, 15.2), Vector3(3.1, 3.1, 3.2), skin)
	s.ell(Vector3(0.0, 0, 16.9), Vector3(3.7, 3.7, 2.3), hel)
	var eye := _hx("d060ff") if role >= 7 else _hx("a8d8ff") if role == 6 else _hx("ff2020") if role == 3 else _hx("0a0a0a")
	s.ell(Vector3(3.2, -1.2, 15.4), Vector3(0.5, 0.5, 0.5), [eye])
	s.ell(Vector3(3.2, 1.2, 15.4), Vector3(0.5, 0.5, 0.5), [eye])
	if role == 4:       # gold shoulder boards and a bronze belt
		for sy: float in [-4.0, 4.0]:
			s.ell(Vector3(0.0, sy, 12.6), Vector3(1.4, 1.5, 0.7), _P(["4a2e06", "86580a", "c08c18", "e8b82a"]))
		s.ell(Vector3(0.0, 0.0, 7.4), Vector3(2.8, 4.2, 0.6), _P(["2a1808", "7a4c1c", "d4a850"]))
	if role == 5:       # wrench in one hand, goggles on the hat, bronze toolbelt
		s.cap(Vector3(5.2, 3.0, 9.0), Vector3(8.0, 3.0, 13.4), 0.7, _P(["2a1808", "7a4c1c", "d4a850"]))
		s.ell(Vector3(8.2, 3.0, 14.0), Vector3(1.3, 1.3, 1.0), _P(["2a1808", "7a4c1c", "d4a850"]))
		s.ell(Vector3(3.4, 0.0, 16.6), Vector3(0.9, 3.0, 0.9), _P(["2a1808", "7a4c1c", "d4a850", "90e8ff"]))
		s.ell(Vector3(0.0, 0.0, 7.6), Vector3(2.8, 4.2, 0.6), _P(["2a1808", "7a4c1c", "d4a850"]))
	if role == 2:
		s.ell(Vector3(-2.8, 0, 10.0), Vector3(0.6, 2.2, 0.6), _P(["1f7a30", "2fcb4a", "6aee80", "9af0a8"]))
	if role == 1:
		s.cap(Vector3(2.0, -5.0, 10.0), Vector3(2.0, -5.0, 19.0), 0.5, _P(["3a2a18", "5a4a30", "7a6a48"]))
		s.ell(Vector3(0.5, -5.0, 17.5), Vector3(0.8, 3.0, 2.0), _P(["b8b8c0", "e8e8ee", "ffffff", "ffffff"]))
	return s.render(26, 34, 26.0)

static func _bee(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var fl: float = [0.0, 0.5][f % 2]
	var wing := _P(["8ab4d8", "b8dcf4", "dff2ff", "ffffff"])
	s.ell(Vector3(-0.5, -5.2, 11.5), Vector3(3.6, 2.2, 0.6), wing, _rz(-0.4) * _rx(0.5 + fl))
	s.ell(Vector3(-0.5, 5.2, 11.5), Vector3(3.6, 2.2, 0.6), wing, _rz(0.4) * _rx(-0.5 - fl))
	s.ell(Vector3(-0.5, 0, 9.5), Vector3(5.4, 3.5, 3.4), _P(["a07008", "d8a010", "ffcc20", "ffe870"]))
	for tx: float in [-2.6, 0.6]:
		s.ell(Vector3(tx, 0, 9.5), Vector3(0.7, 3.7, 3.6), _P(["1a1006", "2a1a08"]))
	s.ell(Vector3(5.2, 0, 9.8), Vector3(2.4, 2.4, 2.4), _P(["0c0803", "1c1408", "2a1e0c", "46341a"]))
	s.ell(Vector3(6.8, -1.3, 10.4), Vector3(0.6, 0.6, 0.6), [Color.WHITE])
	s.ell(Vector3(6.8, 1.3, 10.4), Vector3(0.6, 0.6, 0.6), [Color.WHITE])
	s.ell(Vector3(-6.0, 0, 9.0), Vector3(1.4, 0.8, 0.8), _P(["2a1e0c"]))
	return s.render(26, 30, 24.0)

static func _tank(f: int, ang: float, variant: int = 0) -> Cv:
	# variant 0 tank (green), 1 Heavy Tank (grey, double barrel), 2 Apocalypse Tank (dark, double barrel + missile launcher)
	var s := Scene3.new(ang)
	var trd := _P(["0c0d0a", "1c1d18", "2c2d26", "3e3f36"])
	var hull := _P(["1c2a14", "2f4222", "47602f", "6a8a45"])
	var tur := _P(["1c2a14", "2f4222", "47602f", "6a8a45", "88ab5c"])
	var gun := _P(["0c0e08", "1c2014", "2e3424"])
	if variant == 1:
		hull = _P(["202328", "383d45", "59606b", "8a929e"])
		tur = _P(["202328", "383d45", "59606b", "8a929e", "b0b8c4"])
		gun = _P(["0a0b0d", "181a1f", "2c3038"])
	elif variant == 2:
		trd = _P(["050506", "0e0f12", "1a1c20", "2a2d34"])
		hull = _P(["07080a", "121419", "1f222a", "323744"])
		tur = _P(["07080a", "121419", "1f222a", "323744", "4a5160"])
		gun = _P(["030304", "0c0d10", "1a1c22"])
	for sy: float in [-7.5, 7.5]:
		s.box(Vector3(0, sy, 3), Vector3(9, 2.4, 3), trd)
		for i in range(0, 18, 3):
			s.box(Vector3(float(-8 + ((i + f) % 18)), sy, 5.9), Vector3(0.7, 2.5, 0.5), [_hx("5a5b50") if variant == 0 else _hx("45484f")])
	s.box(Vector3(0, 0, 6.5), Vector3(8.5, 5.2, 2.6), hull)
	s.box(Vector3(-7.5, 0, 7.2), Vector3(1.2, 4.5, 1.2), _P(["14200e", "24361a"]) if variant == 0 else _P(["0c0d10", "1c1e24"]))
	s.ell(Vector3(1, 0, 10.5), Vector3(5, 4.6, 2.6), tur)
	if variant == 0:
		s.cap(Vector3(4, 0, 10.8), Vector3(15, 0, 10.8), 1.1, gun)
		s.ell(Vector3(15.5, 0, 10.8), Vector3(1.4, 1.6, 1.6), _P(["0c0e08", "1c2014"]))
	else:
		for sy: float in [-2.1, 2.1]:        # double barrel
			s.cap(Vector3(4, sy, 10.8), Vector3(16, sy, 10.8), 1.0, gun)
			s.ell(Vector3(16.5, sy, 10.8), Vector3(1.3, 1.5, 1.5), _P(["0c0d10", "1c1e24"]))
	s.ell(Vector3(0, 2.2, 12.5), Vector3(1.5, 1.5, 0.8), tur)
	if variant == 2:
		# anti-air missile launcher on the back deck: a box with four upward-slanting tubes and red warheads
		s.box(Vector3(-5.2, 0, 9.4), Vector3(3.0, 4.4, 1.5), _P(["07080a", "181a20", "2a2e38"]))
		for ty: float in [-3.0, -1.0, 1.0, 3.0]:
			s.cap(Vector3(-6.2, ty, 10.4), Vector3(-2.4, ty, 14.8), 0.9, _P(["0a0b0e", "1c1f26", "343a46"]))
			s.ell(Vector3(-2.2, ty, 15.0), Vector3(0.8, 0.8, 0.8), [_hx("e02020")])
		s.ell(Vector3(1.5, -3.6, 12.6), Vector3(0.6, 0.6, 0.6), [_hx("ff3030")])
		s.ell(Vector3(1.5, 3.6, 12.6), Vector3(0.6, 0.6, 0.6), [_hx("ff3030")])
	return s.render(44, 44, 34.0)

static func _aatruck(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var trd := _P(["0a0810", "181420", "28222e", "3a3444"])
	var hull := _P(["10101a", "1e1e2c", "34344a", "505070"])
	var acc := _P(["3a1a52", "7a38aa", "b868f0"])
	var gun := _P(["06060a", "12121c", "242434"])
	for sy: float in [-7.5, 7.5]:
		s.box(Vector3(0, sy, 3), Vector3(9, 2.4, 3), trd)
		for i in range(0, 18, 3):
			s.box(Vector3(float(-8 + ((i + f) % 18)), sy, 5.9), Vector3(0.7, 2.5, 0.5), [_hx("3a3444")])
	s.box(Vector3(-1, 0, 6.5), Vector3(8.5, 5.2, 2.6), hull)
	s.box(Vector3(6.5, 0, 8.2), Vector3(3.0, 4.6, 2.4), hull)                      # armored cab with violet glass
	s.box(Vector3(8.6, 0, 8.8), Vector3(1.1, 3.6, 1.5), _P(["1a0828", "6a2aa0", "c070ff"]))
	s.box(Vector3(-6.5, 0, 9.2), Vector3(2.2, 4.4, 1.5), acc)                      # rear stowage
	s.cyl(Vector3(-1.5, 0, 10.2), 4.4, 1.0, hull)                                  # turret ring
	s.ell(Vector3(-1.5, 0, 12.2), Vector3(4.0, 4.4, 2.2), hull)
	for sy: float in [-1.8, 1.8]:                                                  # twin anti-air barrels
		s.cap(Vector3(-0.5, sy, 13), Vector3(8.5, sy, 18.5), 0.9, gun)
		s.ell(Vector3(9, sy, 18.8), Vector3(1.0, 1.0, 1.0), _P(["7a38aa", "d090ff"]))
	s.cap(Vector3(-4, 0, 13), Vector3(-4, 0, 16), 0.5, gun)                        # radar dish
	s.ell(Vector3(-4, 0, 16.6), Vector3(0.8, 3.2, 2.4), _P(["28222e", "50486a"]))
	s.ell(Vector3(6.2, -3.4, 10.8), Vector3(0.6, 0.6, 0.6), [_hx("d060ff")])
	s.ell(Vector3(6.2, 3.4, 10.8), Vector3(0.6, 0.6, 0.6), [_hx("d060ff")])
	return s.render(48, 48, 36.0)

# ---- Dark Continent ants (seen from above): 0 soldier, 1 warden, 2 spitter, 3 flyer, 4 king, 5 queen ----
const _ANT_K := [1.0, 1.4, 1.35, 1.25, 2.1, 2.8]
const _ANT_C := [["2a0e08", "5c2412", "8a3c1c", "b05a2c"], ["10141c", "20283a", "34425c", "5c78a8"], ["10281c", "1c4a2c", "2e7c42", "50b868"], ["3a2808", "7a5614", "c0901c", "f0c030"], ["28060a", "58101a", "8a1c2c", "c0384c"], ["3a2810", "7a5a24", "b8903c", "e8c868"]]
const _ANT_D := [["140604", "2a0e08", "3c1a0e"], ["080a10", "10141c", "1c2434"], ["081408", "10281a", "1c4a2a"], ["1c1404", "3a2808", "5c400c"], ["120204", "28060a", "440c14"], ["1c1406", "3a2a10", "5c4418"]]

static func _ant(f: int, ang: float, v: int) -> Cv:
	var s := Scene3.new(ang)
	var k: float = _ANT_K[v]
	var c := _P(_ANT_C[v])
	var d := _P(_ANT_D[v])
	var gold := _P(["8a5c14", "d49a2c", "ffd060", "fff2b0"])
	var ph: float = [0.0, 1.0, 0.0, -1.0][f % 4]
	var legs := [[3.0, 1.6], [0.8, 0.0], [-1.6, -1.6]]
	for i in 3:
		var lx: float = legs[i][0]
		var fw: float = legs[i][1]
		for sg: float in [-1.0, 1.0]:
			var q := ph * (1.0 if (i + (1 if sg > 0.0 else 0)) % 2 == 0 else -1.0) * 1.8
			s.cap(Vector3(lx, sg * 1.6, 4.4) * k, Vector3(lx + fw * 0.6 + q * 0.5, sg * 4.8, 6.0) * k, 0.55 * k, d)
			s.cap(Vector3(lx + fw * 0.6 + q * 0.5, sg * 4.8, 6.0) * k, Vector3(lx + fw + q, sg * 7.4, 0.8) * k, 0.5 * k, d)
	var ab := Vector3(-6.4, 0, 4.6)
	var abr := Vector3(5.0, 3.5, 3.2)
	if v == 5:
		abr = Vector3(8.5, 5.6, 4.6)
		ab = Vector3(-9.5, 0, 5.2)
	elif v == 2:
		abr = Vector3(5.4, 3.8, 3.4)
	s.ell(ab * k, abr * k, c)
	if v == 5:
		for e in 3:                                     # eggs on the abdomen
			s.ell(Vector3(ab.x - 1.5 + float(e) * 3.6 - 3.6, 0, ab.z + 3.8) * k, Vector3(1.8, 1.8, 0.9) * k, _P(["d8c898", "f0e4c0", "fffff0"]))
	if v == 2:
		s.ell(Vector3(ab.x - 1.5, 0, ab.z + 2.2) * k, Vector3(2.6, 2.2, 1.6) * k, _P(["28a028", "68e040", "c8ff80"]).slice(0, 3))
	s.ell(Vector3(0.8, 0, 4.8) * k, Vector3(3.4, 2.6, 2.6) * k, c)
	s.ell(Vector3(-0.8, 0, 3.8) * k, Vector3(1.4, 1.4, 1.0) * k, d)
	var hx := 7.2 if v != 5 else 6.2
	s.ell(Vector3(hx, 0, 4.8) * k, Vector3(2.9, 2.7, 2.5) * k, c)
	var eye := _P(["e02020", "ff6060"]) if v < 4 else _P(["ffe030"])
	for sg: float in [-1.0, 1.0]:
		s.cap(Vector3(hx + 1.8, sg * 1.0, 4.4) * k, Vector3(hx + 4.6, sg * 1.8, 4.0) * k, 0.6 * k, d)
		s.cap(Vector3(hx + 0.6, sg * 1.2, 5.8) * k, Vector3(hx + 4.4, sg * 3.4, 7.4) * k, 0.35 * k, d)
		s.ell(Vector3(hx + 1.4, sg * 1.6, 5.8) * k, Vector3(0.55, 0.55, 0.55) * k, eye)
	if v == 1:
		for sg: float in [-1.0, 1.0]:
			s.cap(Vector3(hx + 2.0, sg * 1.2, 4.2) * k, Vector3(hx + 6.4, sg * 0.8, 4.2) * k, 0.8 * k, _P(["5c78a8", "a8c4ec"]))
		for e in 3:
			s.ell(Vector3(2.8 - float(e) * 2.8, 0, 6.9 - float(e) * 0.2) * k, Vector3(1.8, 3.0, 0.8) * k, _P(["34425c", "5c78a8", "a8c4ec"]))
	if v == 3:
		for sg: float in [-1.0, 1.0]:
			s.ell(Vector3(0.0, sg * 5.0, 8.0 + ph * 1.2) * k, Vector3(6.0, 2.4, 0.4) * k, _P(["a8c0d8", "d8ecfa", "ffffff"]), _rz(-sg * 0.35))
	if v >= 4:                                          # crown
		for e in 5:
			var a := float(e) * TAU / 5.0
			s.cone(Vector3(hx - 0.6 + 1.5 * cos(a), 1.5 * sin(a), 7.4) * k, 0.5 * k, 1.1 * k, gold)
		s.ell(Vector3(hx - 0.6, 0, 7.0) * k, Vector3(2.0, 2.0, 0.5) * k, gold)
	if v == 4:
		for sg: float in [-1.0, 1.0]:
			s.ell(Vector3(2.0, sg * 2.8, 6.8) * k, Vector3(1.6, 1.0, 1.0) * k, _P(["8a5c14", "d49a2c"]))
	var w := int(46.0 * k) + 2
	var h := int(40.0 * k) + 2
	return s.render(w, h, float(h) * 0.58)

# ---- Dark Continent trolls: 0 troll, 1 warrior, 2 captain, 3 king, 4 Titan ----
const _TR_K := [1.9, 2.1, 2.2, 2.6, 5.0, 3.3]
const _TR_SK := [["2a3a24", "46603a", "6c8a54", "92b078"], ["2c3844", "485a6c", "6e869c", "94acc4"], ["3a2e1c", "5c4a2c", "86704a", "b09a6c"], ["38243c", "5a3c60", "84608c", "ac88b4"], ["28282e", "44444c", "68686f", "8c8c96"], ["28282e", "44444c", "68686f", "8c8c96"]]

static func _tv(x: float, y: float, z: float, k: float) -> Vector3:
	return Vector3(x, y, z) * k

static func _troll(f: int, ang: float, v: int) -> Cv:
	var s := Scene3.new(ang)
	var k: float = _TR_K[v]
	var sw: float = [0.0, 3.4, 0.0, -3.4][f % 4]
	var sk := _P(_TR_SK[v])
	var dk := sk.slice(0, 3)
	var iron := _P(["14161c", "2a2e38", "444c5c", "6c788c"])
	var wood := _P(["2a1808", "5a3a18", "8a5c2c"])
	var bone := _P(["8a8070", "c8c0b0", "f0e8d8"])
	var gold := _P(["8a5c14", "d49a2c", "ffd060", "fff2b0"])
	var rock := _P(["28282c", "46464e", "6a6a74", "8e8e9a"])
	var lava := _P(["a03008", "ff7418", "ffc040"])
	var red := _P(["3a0808", "7a1414", "b02424"])
	var cloth := _P(["3a2a14", "5c4422", "7a5c32"]) if v != 3 else red
	for sg: float in [-1.0, 1.0]:
		var z := sw * sg
		var lift := 1.7 if ((f % 4 == 0 and sg > 0.0) or (f % 4 == 2 and sg < 0.0)) else 0.0     # the swinging leg lifts off the ground
		s.cap(_tv(z, sg * 2.6, 1.8 + lift, k), _tv(z * 0.5, sg * 2.6, 7.0, k), 2.1 * k, dk)
		s.ell(_tv(z * 0.6 + 1.4, sg * 2.6, 1.4 + lift, k), _tv(2.6, 1.9, 1.3, k), dk)
	s.ell(_tv(0, 0, 10, k), _tv(3.6, 5.0, 4.4, k), dk)
	s.ell(_tv(1.0, 0, 7.4, k), _tv(3.4, 4.2, 2.8, k), dk)
	s.ell(_tv(1.4, 0, 5.8, k), _tv(2.6, 4.2, 1.6, k), cloth)
	if v < 4:
		s.ell(_tv(0.6, 0, 8.6, k), _tv(3.2, 4.4, 2.4, k), sk.slice(0, 3))
		s.ell(_tv(1.0, 0, 12.2, k), _tv(4.4, 6.4, 3.8, k), sk.slice(0, 3))
		for sg: float in [-1.0, 1.0]:
			s.ell(_tv(3.6, sg * 2.5, 12.6, k), _tv(1.8, 2.6, 2.0, k), sk.slice(1))
			s.ell(_tv(-0.2, sg * 6.8, 13.6, k), _tv(2.6, 2.5, 2.5, k), sk.slice(0, 3))
			s.cap(_tv(0.4, sg * 7.0, 13.4, k), _tv(3.4, sg * 7.2, 10.8, k), 1.9 * k, sk)
			s.ell(_tv(3.8, sg * 7.1, 10.6, k), _tv(2.2, 2.2, 2.2, k), sk.slice(0, 3))
			s.cap(_tv(4.0, sg * 6.9, 10.4, k), _tv(6.0, sg * 5.6, 10.0, k), 1.8 * k, sk.slice(1))
			s.ell(_tv(6.4, sg * 5.4, 10.0, k), _tv(2.1, 2.1, 2.1, k), dk)
		s.cap(_tv(0.8, 0, 14.0, k), _tv(2.2, 0, 16.2, k), 2.4 * k, dk)
		s.ell(_tv(3.0, 0, 17.6, k), _tv(3.3, 3.2, 2.9, k), sk.slice(2))
		s.ell(_tv(5.0, 0, 18.8, k), _tv(1.2, 2.8, 0.8, k), dk)
		s.ell(_tv(4.8, 0, 16.4, k), _tv(1.9, 2.5, 1.1, k), sk.slice(0, 3))
		for sg: float in [-1.0, 1.0]:
			s.cap(_tv(5.6, sg * 1.6, 15.8, k), _tv(6.4, sg * 1.7, 18.2, k), 0.45 * k, bone)
			s.ell(_tv(5.5, sg * 1.3, 19.0, k), _tv(0.5, 0.6, 0.45, k), _P(["ffe030"]))
	if v == 0:
		s.cap(_tv(6.2, 5.4, 9.5, k), _tv(10.5, 6.0, 22.0, k), 1.3 * k, wood)
		s.ell(_tv(11, 6.2, 23.0, k), _tv(2.4, 2.4, 3.0, k), wood)
		for e in 3:
			s.cap(_tv(10.2 + float(e) * 0.3, 6.2 + float(e - 1) * 1.3, 22.0 + float(e) * 0.8, k), _tv(11.6, 6.2 + float(e - 1) * 2.4, 23.4, k), 0.3 * k, iron)
	if v == 1:
		s.ell(_tv(2.8, 0, 19.4, k), _tv(3.4, 3.4, 1.8, k), iron)
		for sg: float in [-1.0, 1.0]:
			s.cap(_tv(2.8, sg * 3.0, 19.2, k), _tv(2.2, sg * 5.6, 24.2, k), 0.7 * k, bone)
		s.ell(_tv(5.0, -7.0, 10.6, k), _tv(1.0, 3.8, 4.4, k), iron)
		s.ell(_tv(5.6, -7.0, 10.6, k), _tv(0.5, 1.6, 1.6, k), gold.slice(0, 3))
		s.cap(_tv(6.2, 5.4, 8.0, k), _tv(10.0, 5.8, 20.0, k), 0.8 * k, wood)
		s.ell(_tv(10.2, 5.8, 19.4, k), _tv(0.8, 3.4, 2.6, k), iron)
		s.ell(_tv(2.6, 0, 13.6, k), _tv(2.4, 5.2, 1.1, k), iron)
	if v == 2:
		s.cap(_tv(-3.2, 0, 6.0, k), _tv(-3.2, 0, 28.0, k), 0.5 * k, wood)
		s.ell(_tv(-3.2, 0, 24.0, k), _tv(0.4, 3.4, 3.2, k), red)
		s.ell(_tv(-3.2, 0, 24.0, k), _tv(0.5, 1.4, 1.4, k), gold.slice(0, 3))
		for sg: float in [-1.0, 1.0]:
			s.ell(_tv(-0.2, sg * 6.8, 15.8, k), _tv(2.8, 2.6, 1.4, k), iron)
			s.cone(_tv(-0.2, sg * 7.0, 17.4, k), 1.0 * k, 1.8 * k, iron)
		s.ell(_tv(8.2, 5.2, 11.4, k), _tv(2.6, 2.6, 2.6, k), rock)
		s.ell(_tv(2.8, 0, 19.2, k), _tv(3.3, 3.3, 1.6, k), iron)
	if v == 3:
		for e in 5:
			var a := float(e) * TAU / 5.0
			s.cap(_tv(3.0 + 2.0 * cos(a), 2.0 * sin(a), 20.8, k), _tv(3.0 + 2.2 * cos(a), 2.2 * sin(a), 23.4, k), 0.45 * k, gold)
		s.ell(_tv(3.0, 0, 20.6, k), _tv(2.6, 2.6, 0.8, k), gold)
		s.ell(_tv(-3.0, 0, 11.0, k), _tv(1.4, 6.2, 6.4, k), red)
		for sg: float in [-1.0, 1.0]:
			s.ell(_tv(-0.2, sg * 6.8, 15.8, k), _tv(3.0, 2.7, 1.5, k), gold.slice(0, 3))
		s.cap(_tv(6.2, 5.4, 9.5, k), _tv(11, 6, 24.0, k), 1.6 * k, wood)
		s.ell(_tv(11.6, 6.2, 25.0, k), _tv(3.0, 3.0, 3.6, k), gold.slice(0, 3))
		s.ell(_tv(8.0, -5.4, 11.4, k), _tv(2.8, 2.8, 2.8, k), rock)
	if v >= 4:
		var elite := v == 5
		var body := _P(["1a0c0c", "3a1814", "5c2c20", "80443a"]) if elite else _P(["16120e", "2c241c", "4a3c2e", "6a5844"])
		var plate := _P(["6a4410", "b88428", "f0c050", "fff0a0"]) if elite else _P(["34343c", "56565f", "86868f", "b4b4c0"])
		s.ell(_tv(0.4, 0, 9.4, k), _tv(3.8, 5.2, 3.2, k), body.slice(0, 3))
		s.ell(_tv(0.8, 0, 12.6, k), _tv(4.8, 7.0, 4.6, k), body)
		for sg: float in [-1.0, 1.0]:
			s.ell(_tv(3.4, sg * 3.0, 13.6, k), _tv(2.2, 3.0, 2.4, k), body.slice(1))
		s.ell(_tv(3.0, 0, 12.2, k), _tv(1.6, 3.6, 3.2, k), lava)
		s.ell(_tv(3.6, 0, 12.4, k), _tv(0.8, 1.8, 1.8, k), _P(["ffc040", "fff0a0"]))
		var cracks := [[-3.0, 9.0], [3.2, 8.4], [-1.6, 15.0], [2.0, 15.4]]
		for cr: Array in cracks:
			s.ell(_tv(3.0, float(cr[0]), float(cr[1]), k), _tv(0.6, 0.6, 1.6, k), lava)
		for sg: float in [-1.0, 1.0]:
			s.ell(_tv(0, sg * 7.6, 15.6, k), _tv(4.0, 3.4, 2.6, k), plate)
			s.ell(_tv(0.4, sg * 7.8, 17.2, k), _tv(2.8, 2.4, 1.2, k), plate.slice(1))
			s.cap(_tv(0, sg * 8.6, 17.4, k), _tv(-1.0, sg * 10.4, 22.0, k), 1.0 * k, plate.slice(1))
			s.cap(_tv(0, sg * 7.2, 14.4, k), _tv(2.6, sg * 6.4, 18.0, k), 2.7 * k, body.slice(1))
			s.ell(_tv(2.8, sg * 6.2, 18.2, k), _tv(2.6, 2.4, 2.4, k), body)
			s.cap(_tv(3.0, sg * 6.0, 18.4, k), _tv(5.8, sg * 3.4, 20.2, k), 2.3 * k, body.slice(1))
			s.ell(_tv(6.2, sg * 3.0, 19.6, k), _tv(2.4, 2.2, 2.2, k), plate)
		s.cap(_tv(0.8, 0, 16.0, k), _tv(1.8, 0, 18.0, k), 3.0 * k, body)
		s.ell(_tv(2.4, 0, 19.0, k), _tv(3.4, 3.4, 3.0, k), plate.slice(1))
		s.ell(_tv(4.8, 0, 17.6, k), _tv(1.8, 2.8, 1.1, k), body)
		s.ell(_tv(5.2, -1.3, 19.8, k), _tv(0.7, 0.9, 0.6, k), lava)
		s.ell(_tv(5.2, 1.3, 19.8, k), _tv(0.7, 0.9, 0.6, k), lava)
		for sg: float in [-1.0, 1.0]:
			s.cap(_tv(1.6, sg * 2.8, 21.0, k), _tv(0.4, sg * 4.6, 26.0, k), 0.9 * k, plate.slice(2))
		if elite:
			for sg: float in [-1.0, 1.0]:
				s.cap(_tv(2.0, sg * 3.2, 20.4, k), _tv(4.6, sg * 7.0, 26.0, k), 0.7 * k, plate.slice(1))
				s.cone(_tv(-0.6, sg * 9.6, 19.6, k), 1.1 * k, 2.4 * k, plate.slice(2))
				s.ell(_tv(1.2, sg * 9.2, 16.4, k), _tv(1.0, 1.0, 1.0, k), lava)
			for e2 in 5:
				var a2 := float(e2) * TAU / 5.0 + 0.3
				s.cone(_tv(2.4 + 2.6 * cos(a2), 2.6 * sin(a2), 22.0, k), 0.6 * k, 1.4 * k, plate.slice(2))
		if elite:    # Great Black Mace
			var blk := _P(["06060a", "14141c", "26262e", "3c3c48"])
			s.cap(_tv(5.8, 3.4, 19.6, k), _tv(10.0, 6.4, 35.0, k), 1.1 * k, blk)
			s.ell(_tv(5.8, 3.4, 19.4, k), _tv(1.4, 1.4, 1.4, k), blk.slice(1))
			var hc := Vector3(10.4, 6.6, 36.6)
			s.ell(_tv(hc.x, hc.y, hc.z, k), _tv(3.6, 3.6, 3.9, k), blk)
			s.ell(_tv(hc.x, hc.y, hc.z, k), _tv(3.7, 3.7, 0.7, k), lava)
			for d: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0.7, 0.7, 0.4), Vector3(-0.7, -0.7, 0.4), Vector3(0.7, -0.7, 0.4), Vector3(-0.7, 0.7, 0.4)]:
				var p0 := hc + d * 3.0
				var p1 := hc + d * Vector3(5.4, 5.4, 5.6)
				s.cap(_tv(p0.x, p0.y, p0.z, k), _tv(p1.x, p1.y, p1.z, k), 0.8 * k, blk.slice(2))
		else:
			s.ell(_tv(5.6, 0, 25.0, k), _tv(3.0, 3.0, 3.0, k), rock)
			s.ell(_tv(6.6, -1.0, 26.6, k), _tv(1.8, 1.6, 1.2, k), rock.slice(2))
	var w := int(30.0 * k) + 6
	var h := int(38.0 * k) + 6
	var gy := float(h) * 0.80
	if v == 5:
		h += int(10.0 * k)
		gy += 10.0 * k
	return s.render(w, h, gy)

static func _pillar(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var st := _P(["26262c", "46464e", "6e6e78", "98989f"])
	var cr := _P(["a03008", "ff7418", "ffc040"])
	s.ell(Vector3(0, 0, 2), Vector3(8, 8, 3), st)
	s.cap(Vector3(0, 0, 3), Vector3(0, 0, 26), 6.0, st)
	s.ell(Vector3(0, 0, 27), Vector3(7.5, 7.5, 2.6), st.slice(1))
	for p: Array in [[-3.0, 2.0], [3.0, -2.0], [1.0, 4.0]]:
		s.ell(Vector3(float(p[0]) * 1.4, float(p[1]) * 1.4, 14.0 + float(p[0])), Vector3(0.9, 0.9, 3.2), cr)
	s.cone(Vector3(-3, -1, 29), 2.4, 4.5, st.slice(1))
	s.cone(Vector3(3, 2, 29), 2.0, 3.2, st.slice(1))
	return s.render(44, 56, 44.0)

static func _mech(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var lift: float = [2.0, 0.0][f % 2]
	var lift2: float = [0.0, 2.0][f % 2]
	var steel := _P(["2a3040", "44506a", "6a7898", "8a9abc"])
	var dk := _P(["14161e", "22242c", "343842"])
	for leg: Array in [[5.0, -5.0, lift], [5.0, 5.0, lift2], [-5.0, -5.0, lift2], [-5.0, 5.0, lift]]:
		var sx: float = leg[0]
		var sy: float = leg[1]
		var l: float = leg[2]
		s.cap(Vector3(sx, sy * 0.8, 5), Vector3(sx * 1.2, sy * 1.5, 0.8 + l), 1.2, dk)
		s.ell(Vector3(sx * 1.2, sy * 1.6, 0.8 + l), Vector3(1.8, 1.8, 0.7), dk)
	s.box(Vector3(0, 0, 7), Vector3(7, 4.5, 2.6), steel)
	s.ell(Vector3(0.5, 0, 10.2), Vector3(3.8, 3.2, 1.8), _P(["286878", "48a8c0", "90f0ff", "d0ffff"]))
	s.cap(Vector3(3, 3.2, 8.2), Vector3(12, 3.2, 8.2), 1.1, _P(["0c0d12", "1c1e28", "2c2f3c"]))
	s.ell(Vector3(-6.8, 0, 8), Vector3(0.8, 0.8, 0.8), [_hx("ff3030")])
	return s.render(40, 38, 28.0)

static func _aegis(ang: float) -> Cv:
	var s := Scene3.new(ang)
	s.ell(Vector3(0, 0, 6), Vector3(7, 7, 5.5), _P(["1c2030", "343c52", "545e7c", "7a86a8", "a0aed0"]))
	s.ell(Vector3(-1.5, 0, 9.5), Vector3(3.6, 3.6, 2.2), _P(["10121c", "1c2030", "2a3044"]))
	s.ell(Vector3(4.5, 0, 8), Vector3(2.2, 2.2, 2.2), _P(["8a6a10", "d8a820", "ffd860"]))
	return s.render(26, 30, 22.0)

static func _worm(f: int, ang: float, grey: bool = false) -> Cv:
	var s := Scene3.new(ang)
	var pal := _P(["3a0408", "5c0a10", "8a1418", "b02a30", "d04048"])
	var head := _P(["5a0a10", "8a1418", "c42a32", "e85058"])
	if grey:      # Earthworm: the grey cousin of the Bloodworm
		pal = _P(["1c1c1e", "34343a", "54545c", "7a7a84", "a0a0aa"])
		head = _P(["2a2a2e", "4a4a52", "74747e", "9a9aa6"])
	for i in range(6, 0, -1):
		var y := sin(float(f) * 1.57 - float(i) * 0.9) * 1.8
		var r := 3.6 if i < 4 else 2.8
		s.ell(Vector3(float(-i) * 3.6 + 3.0, y, r + 0.5), Vector3(r + 0.5, r, r), pal)
	s.ell(Vector3(4.5, 0, 5), Vector3(4.2, 3.8, 3.8), head)
	s.ell(Vector3(8, 0, 4.2), Vector3(2.2, 2.0, 1.0), _P(["200204", "3a0408"]) if not grey else _P(["0a0a0c", "1c1c20"]))
	var eyec := _hx("ffe040") if not grey else _hx("d8e8ff")
	s.ell(Vector3(6.2, -2.0, 6.6), Vector3(0.7, 0.7, 0.7), [eyec])
	s.ell(Vector3(6.2, 2.0, 6.6), Vector3(0.7, 0.7, 0.7), [eyec])
	return s.render(52, 44, 30.0)

static func _hunter(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var pal := _P(["2a0c1a", "5a1a38", "9a2a60", "c85a8a"])
	s.ell(Vector3(-9.5, 0, 10), Vector3(2.6 + float(f) * 0.6, 1.2, 1.2), _P(["c05a08", "ff9020", "ffd060"]))
	s.ell(Vector3(-3, -5, 10), Vector3(5, 1.8, 0.7), pal, _rz(-0.6))
	s.ell(Vector3(-3, 5, 10), Vector3(5, 1.8, 0.7), pal, _rz(0.6))
	s.ell(Vector3(0, 0, 10), Vector3(8.5, 2.8, 2.4), pal)
	s.ell(Vector3(6.8, 0, 10), Vector3(3, 1.2, 1.2), _P(["a0a0b0", "f0f0f8"]))
	s.ell(Vector3(2.5, 0, 12), Vector3(1.6, 1.2, 0.8), _P(["a07008", "ffd860"]))
	return s.render(32, 30, 24.0)

static func _drone(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var pal := _P(["14121c", "2a2638", "403a56", "5e5680"])
	s.ell(Vector3(-6.5, 0, 9), Vector3(2.0 + float(f) * 0.6, 0.9, 0.9), _P(["c05a08", "ff9020", "ffd060"]))
	s.ell(Vector3(-2, -3.5, 9), Vector3(3.6, 1.4, 0.6), pal, _rz(-0.6))
	s.ell(Vector3(-2, 3.5, 9), Vector3(3.6, 1.4, 0.6), pal, _rz(0.6))
	s.ell(Vector3(0, 0, 9), Vector3(5.8, 2.4, 2.0), pal)
	s.ell(Vector3(4.5, 0, 9), Vector3(1.8, 1.0, 1.0), _P(["a02820", "f04030"]))
	return s.render(26, 26, 20.0)

static func _starship(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var wing := _P(["0c1018", "1c2030", "2c3248", "444c68"])
	var hull := _P(["1c2030", "3a4258", "5a6482", "7e8aae"])
	for y: float in [-2.0, 2.0]:
		s.ell(Vector3(-12.5 - float(f) * 0.5, y, 10), Vector3(2.6, 0.9, 0.9), _P(["c05a08", "ff9020", "ffd060"]))
	s.ell(Vector3(-6, -7, 10), Vector3(6, 3.0, 0.8), wing, _rz(-0.45))
	s.ell(Vector3(-6, 7, 10), Vector3(6, 3.0, 0.8), wing, _rz(0.45))
	s.ell(Vector3(0, 0, 10), Vector3(13, 3.4, 3.0), hull)
	s.ell(Vector3(7, 0, 12), Vector3(3.4, 1.4, 1.0), _P(["286878", "48a8c0", "90f0ff"]))
	s.ell(Vector3(-5, 0, 13), Vector3(5, 0.5, 0.7), _P(["a01818", "d83030"]))
	return s.render(44, 38, 26.0)

static func _corvette(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var wing := _P(["181c28", "2c3244", "444c64", "5e6888"])
	var hull := _P(["22283a", "44506c", "6a7898", "94a4c8"])
	for y: float in [-2.0, 2.0]:
		s.ell(Vector3(-10.5 - float(f) * 0.5, y, 10), Vector3(2.4, 0.9, 0.9), _P(["c05a08", "ff9020", "ffd060"]))
	s.ell(Vector3(-5, -6, 10), Vector3(4.5, 2.6, 0.8), wing, _rz(-0.5))
	s.ell(Vector3(-5, 6, 10), Vector3(4.5, 2.6, 0.8), wing, _rz(0.5))
	s.ell(Vector3(0, 0, 10), Vector3(10.5, 3.6, 3.2), hull)
	s.ell(Vector3(4, 0, 12.5), Vector3(2.6, 2.0, 1.4), _P(["286878", "48a8c0", "90f0ff"]))
	s.ell(Vector3(-7, 0, 11.5), Vector3(0.8, 0.8, 0.8), [_hx("ff3030")])
	return s.render(40, 34, 24.0)

static func _golem(f: int, ang: float, mud: bool = false) -> Cv:
	var s := Scene3.new(ang)
	var sw: float = [0.0, 2.2, 0.0, -2.2][f % 4]
	var rock := _P(["1c1a1a", "342e2c", "564e4a", "7a706a", "9a908a"])
	var dk := _P(["0c0a0a", "1c1818", "2e2826", "443c38", "564e4a"])
	if mud:
		rock = _P(["1e1208", "3a2410", "5e3c1c", "86602e", "a8804a"])
		dk = _P(["0e0804", "20140a", "32200e", "4a3016", "5e3c1c"])
	s.ell(Vector3(sw, -5, 5), Vector3(3.6, 3.4, 5.2), dk)
	s.ell(Vector3(-sw, 5, 5), Vector3(3.6, 3.4, 5.2), dk)
	s.ell(Vector3(0, 0, 15), Vector3(7.5, 10, 8.5), rock)
	s.ell(Vector3(-2, -5, 21), Vector3(4.5, 4.5, 3.5), rock)
	s.ell(Vector3(-3, 5, 20), Vector3(4.5, 4, 3.5), rock)
	s.ell(Vector3(0, -11, 18), Vector3(4.2, 4.2, 5.0), rock)
	s.ell(Vector3(0, 11, 18), Vector3(4.2, 4.2, 5.0), rock)
	s.cap(Vector3(0, -11, 17), Vector3(5 + sw, -12.5, 10), 3.0, rock)
	s.cap(Vector3(0, 11, 17), Vector3(5 - sw, 12.5, 10), 3.0, rock)
	s.ell(Vector3(6 + sw, -12.5, 9), Vector3(4, 4, 4), rock)
	s.ell(Vector3(6 - sw, 12.5, 9), Vector3(4, 4, 4), rock)
	s.ell(Vector3(3, 0, 24), Vector3(4.2, 4.2, 3.6), dk)
	var g := _P(["c05a08", "ff8a20", "ffd060"])
	s.ell(Vector3(6.8, -1.6, 16.5), Vector3(0.8, 0.8, 3.0), g)
	s.ell(Vector3(6.8, 1.6, 15.5), Vector3(0.8, 0.8, 3.0), g)
	s.ell(Vector3(-6.8, -2, 15), Vector3(0.8, 0.9, 4), g)
	s.ell(Vector3(6.8, -1.6, 24.6), Vector3(0.6, 0.9, 0.6), [_hx("ffb040")])
	s.ell(Vector3(6.8, 1.6, 24.6), Vector3(0.6, 0.9, 0.6), [_hx("ffb040")])
	if mud:
		# clay bands across the body, moss on the shoulders and head, a glowing crack and dripping mud
		var moss := _P(["0e2a12", "1c4a1e", "2e7a2c", "4aa83c"])
		s.ell(Vector3(0, 0, 12.2), Vector3(7.7, 10.2, 0.9), dk)
		s.ell(Vector3(0, 0, 17.6), Vector3(7.6, 10.1, 0.8), dk)
		s.ell(Vector3(-2, -5, 24.2), Vector3(2.8, 2.6, 1.0), moss)
		s.ell(Vector3(-3, 5, 23.6), Vector3(2.6, 2.4, 1.0), moss)
		s.ell(Vector3(2.5, 0.5, 27.4), Vector3(1.8, 1.6, 1.0), moss)
		s.ell(Vector3(-1.0, 3.0, 27.0), Vector3(1.0, 1.0, 0.8), moss)
		s.ell(Vector3(7.5, 0.2, 15.0), Vector3(0.6, 0.7, 3.6), _P(["a04a08", "e88018", "ffc850"]))
		s.ell(Vector3(7.3, -2.6, 12.4), Vector3(0.5, 0.6, 1.8), _P(["a04a08", "e88018", "ffc850"]))
		for sg: float in [-1.0, 1.0]:
			s.cap(Vector3(6.0 + sw * sg * -1.0, sg * 12.6, 6.0), Vector3(6.0 + sw * sg * -1.0, sg * 12.6, 2.0), 1.1, dk)
			s.ell(Vector3(6.0 + sw * sg * -1.0, sg * 12.6, 1.6), Vector3(1.6, 1.6, 1.0), dk)
		s.ell(Vector3(-5.5, 0, 22), Vector3(2.0, 3.0, 2.6), dk)      # a mud lump on the back
	return s.render(40, 50, 38.0)

static func _demon_scene(f: int, ang: float, k: float) -> Scene3:
	var s := Scene3.new(ang)
	var fl: float = [0.0, 0.35, 0.6, 0.35][f % 4]
	var mem := _P(["0c0104", "1c0206", "340408", "4a0810"])
	var arm := _P(["2a0408", "50080e", "7a1218"])
	var red := _P(["3a0408", "70101a", "b01c24", "e04048"])
	var bone := _P(["8a8070", "c8c0b0", "e8e0d0"])
	for sg: float in [-1.0, 1.0]:
		s.ell(Vector3(-6, sg * 10, 14.6 - fl * 3.0) * k, Vector3(6.5, 9, 0.8) * k, mem, _rz(sg * 0.45) * _rx(-sg * (0.15 + fl * 0.5)))
		for tip: Vector3 in [Vector3(-6, 20, 17), Vector3(-12, 16, 16), Vector3(-14, 8, 14)]:
			s.cap(Vector3(-1, sg * 3, 15) * k, Vector3(tip.x, sg * tip.y, tip.z + fl * 8.0) * k, 0.9 * k, arm)
	s.cap(Vector3(-4, 0, 8) * k, Vector3(-12, 3, 5) * k, 0.9 * k, _P(["340408", "70101a"]))
	s.ell(Vector3(-13, 3.5, 4.5) * k, Vector3(2.2, 1.0, 1.0) * k, _P(["c05a08", "ff9020", "ffd060"]))
	s.cap(Vector3(-2, -2, 4) * k, Vector3(-2, -2, 0.5) * k, 1.6 * k, _P(["340408", "560a10"]))
	s.cap(Vector3(-2, 2, 4) * k, Vector3(-2, 2, 0.5) * k, 1.6 * k, _P(["340408", "560a10"]))
	s.ell(Vector3(-1, 0, 10) * k, Vector3(4.6, 4.8, 6.0) * k, red)
	s.ell(Vector3(3.5, 0, 17.5) * k, Vector3(4, 4, 4) * k, red)
	for sg: float in [-1.0, 1.0]:
		s.cap(Vector3(3, sg * 2.5, 20.5) * k, Vector3(6, sg * 5.5, 26) * k, 0.9 * k, bone)
		s.ell(Vector3(7.0, sg * 1.9, 18.2) * k, Vector3(0.6, 0.7, 0.6) * k, [_hx("ffe030")])
	return s

const _DK := 1.5

static func _dv(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z) * _DK

# The detailed Demon: muscular body, spiked pauldrons, swept horns, fiery-clawed bat wings, a flame in its hand.
static func _demon(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var fl: float = [0.0, 0.35, 0.6, 0.35][f % 4]
	var sw: float = [0.0, 2.0, 0.0, -2.0][f % 4]
	var fk: float = [0.0, 1.0, 0.0, 1.0][f % 4]
	var skin := _P(["1a0206", "3c0609", "621018", "8c1a22"])
	var dsk := _P(["0a0102", "1c0306", "30060a", "4a0c10"])
	var mem := _P(["0c0106", "220409", "3c0810", "5e0e18"])
	var bone := _P(["5a5040", "9a8e78", "d8ccb0", "f4ecd4"])
	var iron := _P(["14121a", "262430", "3c3a4c", "5a586c"])
	var ember := _P(["a03008", "ff7418", "ffc040", "fff0a0"])
	var pec := _P(["3c0609", "621018", "8c1a22", "b02a30"])
	for sg: float in [-1.0, 1.0]:                       # bat wings: bone fingers, scalloped membrane, glowing claw tips
		var root := Vector3(-2, sg * 5, 21)
		var tips: Array = [Vector3(-4, sg * 27, 26 + fl * 9), Vector3(-13, sg * 24, 22 + fl * 8), Vector3(-20, sg * 16, 19 + fl * 6), Vector3(-23, sg * 8, 16 + fl * 4)]
		for i in 4:
			var t: Vector3 = tips[i]
			s.cap(root * _DK, t * _DK, 0.95 * _DK, bone)
			s.ell(t * _DK, Vector3(1, 1, 1) * _DK, ember.slice(1) if (i + f) % 4 == 0 else ember.slice(0, 2))
		var pts: Array = tips.duplicate()
		pts.append(Vector3(-6, sg * 3.5, 13))
		for i in 4:
			var p: Vector3 = pts[i]
			var q: Vector3 = pts[i + 1]
			var mid := (p + q) * 0.5
			var d := mid - root
			var ln := Vector2(d.x, d.y).length()
			var gap := p.distance_to(q)
			var an := atan2(d.y, d.x)
			s.ell((root + d * 0.55) * _DK, Vector3(ln * 0.5, minf(gap * 0.55, 9.0), 0.6) * _DK, mem, _rz(an) * _rx(-sg * (0.1 + fl * 0.3)))
		s.cap(Vector3(-1, sg * 5, 21.5) * _DK, (tips[0] as Vector3) * _DK, 1.3 * _DK, dsk)
	s.cap(_dv(-5, 0, 9), _dv(-14, 2.5, 5.5 + fk), 1.1 * _DK, skin)                    # tail with a blade tip
	s.cap(_dv(-14, 2.5, 5.5 + fk), _dv(-22, -1.5, 6.5), 0.8 * _DK, skin)
	s.cone(_dv(-24, -2, 6.5), 1.7 * _DK, 2.8 * _DK, ember)
	for sg: float in [-1.0, 1.0]:                       # digitigrade clawed legs
		var z := sw * sg
		s.cap(_dv(z, sg * 3.2, 10), _dv(z * 0.6 + 2.2, sg * 3.6, 5.5), 2.3 * _DK, skin)
		s.cap(_dv(z * 0.6 + 2.2, sg * 3.6, 5.5), _dv(z * 0.4 - 0.6, sg * 3.8, 1.4), 1.7 * _DK, dsk)
		s.cap(_dv(z * 0.4 - 0.6, sg * 3.8, 1.0), _dv(z * 0.4 + 3.6, sg * 3.8, 0.9), 1.5 * _DK, dsk)
		for c: float in [-1.2, 0.0, 1.2]:
			s.cap(_dv(z * 0.4 + 3.6, sg * 3.8 + c, 0.9), _dv(z * 0.4 + 5.4, sg * 3.8 + c * 1.6, 0.8), 0.5 * _DK, bone)
	s.ell(_dv(-1, 0, 11), _dv(4.4, 4.6, 3.8), dsk)                                    # hips
	s.ell(_dv(-0.5, 0, 15.5), _dv(4.9, 6.0, 5.0), skin)                               # abdomen
	s.ell(_dv(1.4, 0, 19), _dv(4.2, 7.0, 3.6), skin)                                  # chest
	for sy: float in [-1.0, 1.0]:
		s.ell(_dv(2.6, sy * 2.6, 19.8), _dv(2.0, 2.8, 2.4), pec)
		s.ell(_dv(2.8, sy * 1.0, 14.6), _dv(1.2, 1.8, 1.4), dsk)
	s.ell(_dv(3.4, 0, 17.6), _dv(0.7, 0.9, 1.8), ember.slice(0, 3))                   # glowing cracks
	s.ell(_dv(3.0, 0, 13.0), _dv(0.7, 0.7, 1.2), ember.slice(0, 3))
	s.ell(_dv(0.5, 0, 12.2), _dv(3.4, 5.4, 0.9), iron)                                # belt + skull buckle
	s.ell(_dv(3.0, 0, 12.2), _dv(1.0, 1.6, 0.9), bone)
	for sy: float in [-1.0, 1.0]:
		s.ell(_dv(0.6, sy * 8.0, 22.2), _dv(3.8, 3.4, 2.4), iron)                     # spiked pauldrons
		s.ell(_dv(0.6, sy * 8.0, 24.0), _dv(2.4, 2.2, 1.0), iron.slice(1))
		s.cap(_dv(0.6, sy * 8.2, 24.0), _dv(-0.6, sy * 10.8, 29.5), 1.1 * _DK, bone)
		s.cap(_dv(1.8, sy * 9.4, 23.0), _dv(2.2, sy * 12.6, 26.5), 0.8 * _DK, bone)
		s.cap(_dv(0.8, sy * 8.2, 20.5), _dv(6.6, sy * 6.6, 17.4), 2.2 * _DK, skin)    # arms
		s.cap(_dv(6.6, sy * 6.6, 17.4), _dv(10.8, sy * 4.0, 18.6), 1.8 * _DK, dsk)
		s.ell(_dv(5.4, sy * 7.0, 18.2), _dv(1.8, 1.6, 1.6), iron)
		for c: float in [-1.0, 0.0, 1.0]:
			s.cap(_dv(10.8, sy * 4.0 + c, 18.6), _dv(13.4, sy * 3.0 + c * 1.5, 18.0), 0.5 * _DK, bone)
	var pf: float = [0.0, 0.8, 1.5, 0.8][f % 4]
	s.ell(_dv(14.2, -3.0, 19.4), _dv(2.4 + pf, 2.4 + pf, 2.4 + pf), ember.slice(0, 3))   # flame in hand
	s.ell(_dv(14.4, -3.0, 19.8), _dv(1.4, 1.4, 1.4), ember.slice(2))
	s.ell(_dv(3.2, 0, 25.5), _dv(4.2, 4.6, 4.4), skin)                                # head
	s.ell(_dv(5.8, 0, 23.3), _dv(2.8, 3.2, 1.6), dsk)                                 # jaw
	for sy: float in [-1.0, 1.0]:
		s.cap(_dv(7.2, sy * 1.4, 22.6), _dv(7.8, sy * 1.6, 21.2), 0.55 * _DK, bone)   # fangs
		s.ell(_dv(6.8, sy * 2.0, 26.8), _dv(1.5, 1.6, 0.9), dsk)                      # brow
		s.ell(_dv(7.0, sy * 1.7, 26.0), _dv(0.55, 0.8, 0.5), _P(["ffe030", "fff8a0"]))   # eyes
		s.cap(_dv(2.4, sy * 3.4, 28.2), _dv(-0.5, sy * 7.2, 32.5), 1.4 * _DK, bone)   # swept horns
		s.cap(_dv(-0.5, sy * 7.2, 32.5), _dv(-4.5, sy * 8.0, 38.0), 0.95 * _DK, bone.slice(1))
		s.cap(_dv(-4.5, sy * 8.0, 38.0), _dv(-6.0, sy * 6.4, 41.0), 0.6 * _DK, bone.slice(2))
		s.ell(_dv(1.2, sy * 4.2, 29.2), _dv(1.2, 1.2, 1.0), iron)
		s.cap(_dv(3.2, sy * 1.4, 30.0), _dv(1.6, sy * 1.4, 33.0), 0.7 * _DK, bone)
	return s.render(112, 120, 70.0)

static func _void(f: int) -> Cv:
	var cv := Cv.new(24, 24)
	var b: int = [0, 1][f % 2]
	cv.sph(0, b, 7, 7, _P(["0c0418", "1e0a34", "381560", "5a2a98"]))
	cv.sph(1, b, 3, 3, _P(["c8b8e0", "ece8f8", "ffffff"]))
	cv.sph(2, b, 1, 1, _P(["6a1ac8", "9a50f0"]))
	cv.px(2, b, Color.BLACK)
	return cv

# ---------- the bosses (body radius about BOSS_R art pixels; the boss script scales them) ----------

static func _b_leaves(f: int) -> Cv:
	var s := Scene3.new(0.0)
	var pal := _P(["0a2a0e", "12481a", "1c6a26", "2f8a38"])
	for i in 10:
		var a := TAU * float(i) / 10.0 + float(f) * TAU / 100.0
		s.ell(Vector3(17.0 * cos(a), 17.0 * sin(a), 7.0), Vector3(8, 3.2, 0.9), pal, _rz(a) * _rx(0.25))
	return s.render(84, 66, 38.0)

static func _b_garden(ang: float) -> Cv:
	var s := Scene3.new(ang)
	s.ell(Vector3(0, 0, 9), Vector3(16, 16, 10), _P(["10401a", "1f6a28", "33953f", "5cc060"]))
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.3
		s.ell(Vector3(11.0 * cos(a), 11.0 * sin(a), 14.5), Vector3(4.6, 4.6, 3.6), _P(["a02a58", "e05088", "ff80ac", "ffb0cc"]))
	s.ell(Vector3(0, 0, 17.5), Vector3(8, 8, 3.6), _P(["a08010", "e0b820", "ffd840", "fff088"]))
	for sy: float in [-1.0, 1.0]:
		s.ell(Vector3(13.2, sy * 4.5, 13), Vector3(2.6, 2.6, 2.8), _P(["05060a", "14180c"]))
		s.ell(Vector3(15.2, sy * 4.5, 13.6), Vector3(0.8, 0.8, 0.8), [_hx("fff060")])
	return s.render(56, 60, 42.0)

static func _b_mud(ang: float) -> Cv:
	var s := Scene3.new(ang)
	var side := _P(["1e1206", "3e2810", "5a3a1a", "74502a"])
	s.ell(Vector3(2, -15, 6), Vector3(7, 7, 6), side)
	s.ell(Vector3(2, 15, 6), Vector3(7, 7, 6), side)
	s.ell(Vector3(0, 0, 8), Vector3(16, 16, 10), _P(["2e1c0a", "5a3a1a", "7a5228", "9a7440"]))
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.3
		s.ell(Vector3(12.5 * cos(a), 12.5 * sin(a), 15), Vector3(4.6, 2.6, 1.8), _P(["5a5040", "8a7a62", "a89478", "c8b898"]), _rz(a + 1.57))
	for sy: float in [-1.0, 1.0]:
		s.ell(Vector3(13.5, sy * 4.5, 11), Vector3(2.4, 2.4, 2.4), _P(["0e0602", "1e1006", "3a2208"]))
		s.ell(Vector3(15.4, sy * 4.5, 11), Vector3(0.8, 0.8, 0.8), [_hx("ffb030")])
	return s.render(60, 62, 42.0)

static func _b_titan(ang: float) -> Cv:
	var s := Scene3.new(ang)
	var rock := _P(["22242c", "3c4048", "5e626e", "80848f"])
	s.ell(Vector3(0, 0, 10), Vector3(15, 15, 11), rock)
	for i in 8:
		var a := TAU * float(i) / 8.0 + 0.2
		s.ell(Vector3(12.0 * cos(a), 12.0 * sin(a), 7), Vector3(5.5, 5.5, 5), rock)
	s.ell(Vector3(0, 0, 18.5), Vector3(9.5, 9.5, 3.6), _P(["30343c", "4c505a", "6e727e", "9296a2"]))
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.4
		s.ell(Vector3(6.5 * cos(a), 6.5 * sin(a), 21.4), Vector3(5, 0.9, 0.6), _P(["c05a08", "ff8a20", "ffc060"]), _rz(a))
	s.ell(Vector3(0, 0, 21.6), Vector3(2.6, 2.6, 1.0), _P(["c05a08", "ff9a20", "ffd060"]))
	for sy: float in [-1.0, 1.0]:
		s.ell(Vector3(13.5, sy * 3.6, 14), Vector3(2.0, 2.0, 1.6), _P(["c05a08", "ffa020", "ffe080"]))
	return s.render(56, 60, 42.0)

static func _b_void(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	s.ell(Vector3(0, 0, 17), Vector3(15, 15, 15), _P(["06020c", "12051f", "220a38", "380f5c"]))
	for p: Vector3 in [Vector3(-7, -6, 26), Vector3(-10, 3, 22), Vector3(-4, 9, 12), Vector3(8, -9, 24), Vector3(10, 6, 12), Vector3(-12, -2, 17), Vector3(2, 12, 24)]:
		s.ell(p, Vector3(0.9, 0.9, 0.9), [_hx("9a70e0")])
	s.ell(Vector3(12, 0, 17), Vector3(4.5, 6.5, 6.5), _P(["a8a0c0", "dcd6ec", "f6f2ff"]))
	var iris := _P(["4a1090", "7a30d0", "a060f0"]) if f == 0 else _P(["90081a", "d01a30", "ff5060"])
	s.ell(Vector3(15.2, 0, 17), Vector3(2.4, 3.4, 3.4), iris)
	s.ell(Vector3(17.4, 0, 17), Vector3(1.2, 1.5, 1.5), [Color.BLACK])
	return s.render(48, 58, 44.0)

static func _b_hell(f: int, ang: float) -> Cv:
	return _demon_scene(f, ang, 1.6).render(72, 84, 56.0)

static func _stalker(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var k: float = [0.0, 1.0, 0.0, -1.0][f % 4] * 2.8
	var fur := _P(["1a2838", "2a4058", "40607e", "5f86a6", "8ab4d0"])
	var dk := _P(["0c1420", "16222f", "22364a", "304a62", "3e607c"])
	var glow := _P(["0a7a68", "1ce0b4", "9affe8"])
	var eye := [_hx("fff060")]
	for l: Vector3 in [Vector3(7, -4.4, k), Vector3(7, 4.4, -k), Vector3(-6.5, -4.4, -k), Vector3(-6.5, 4.4, k)]:
		s.cap(Vector3(l.x, l.y, 7.5), Vector3(l.x + l.z, l.y * 1.2, 1.4), 1.7, dk)
		s.ell(Vector3(l.x + l.z + 1.0, l.y * 1.2, 1.2), Vector3(2.0, 1.7, 1.0), dk)
	s.cap(Vector3(-9, 0, 9), Vector3(-15, k * 0.6, 11), 1.4, fur)
	s.cap(Vector3(-15, k * 0.6, 11), Vector3(-19.5, -k * 0.8, 14.5), 1.1, fur)
	s.ell(Vector3(-20, -k * 0.8, 15), Vector3(1.6, 1.6, 1.6), glow)
	s.ell(Vector3(-1.5, 0, 10.5), Vector3(10, 5.6, 5.2), fur)
	s.ell(Vector3(5.5, 0, 11.5), Vector3(5.6, 5.4, 5.4), fur)
	for x: float in [-7.0, -4.0, -1.0, 2.0]:
		s.ell(Vector3(x, 0, 15.0), Vector3(0.8, 5.0, 0.7), glow)
	s.ell(Vector3(12, 0, 13), Vector3(4.6, 4.2, 3.8), fur)
	s.ell(Vector3(15.6, 0, 11.4), Vector3(2.8, 2.4, 1.8), dk)
	for sg: float in [-1.0, 1.0]:
		s.cap(Vector3(16.2, sg * 1.3, 10.4), Vector3(16.6, sg * 1.3, 8.2), 0.55, [_hx("f0f6ff")])
		s.cone(Vector3(10.8, sg * 2.8, 17.2), 1.5, 1.6, dk)
		s.ell(Vector3(14.0, sg * 2.3, 14.4), Vector3(1.1, 0.9, 0.8), eye)
	return s.render(50, 44, 32.0)

static func _b_dark(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var k: float = [0.0, 1.0, 0.0, -1.0][f % 4] * 3.4
	var hide := _P(["1c1830", "322c52", "4c4478", "6c64a0", "928ac8"])
	var dk := _P(["0a0814", "16122a", "241e40", "34305a", "46427a"])
	var glow := _P(["0a7a68", "1ce0b4", "9affe8"])
	var bone := _P(["7a7060", "b0a48c", "dcd0b8", "f4ecd8"])
	for l: Vector3 in [Vector3(12, -11, k), Vector3(12, 11, -k), Vector3(-12, -11, -k), Vector3(-12, 11, k)]:
		s.cap(Vector3(l.x * 0.7, l.y * 0.55, 13), Vector3(l.x + l.z, l.y, 3), 3.6, hide)
		s.ell(Vector3(l.x + l.z + 1.0, l.y, 2.2), Vector3(4.6, 4.2, 2.2), dk)
	s.ell(Vector3(-3, 0, 16), Vector3(17, 12.5, 10.5), hide)
	s.ell(Vector3(8, 0, 17.5), Vector3(10.5, 11.5, 10), hide)
	s.ell(Vector3(-14, 0, 15.5), Vector3(7.5, 8.5, 8), hide)
	var i := 0
	for x: float in [-15.0, -10.0, -5.0, 0.0, 5.0, 9.0]:
		var h := 7.0 + (3.0 if i == 2 or i == 3 else 0.0)
		s.cone(Vector3(x, 0, 24.0 + h * 0.5), 3.2, h * 0.55, glow)
		for sg: float in [-1.0, 1.0]:
			s.cone(Vector3(x - 1.0, sg * 6.4, 23.0), 2.0, 3.4, bone)
		i += 1
	s.cap(Vector3(14, 0, 18), Vector3(18.5, 0, 15.5), 5.0, hide)
	s.ell(Vector3(22, 0, 15.5), Vector3(7.2, 7.6, 6.6), hide)
	s.ell(Vector3(28, 0, 12.8), Vector3(5.4, 5.4, 3.8), dk)
	s.ell(Vector3(26.5, 0, 10.6), Vector3(4.8, 4.0, 1.4), dk)
	for sg: float in [-1.0, 1.0]:
		s.cap(Vector3(27, sg * 4.6, 11.4), Vector3(31.5, sg * 6.2, 18), 1.7, bone)
		s.cap(Vector3(20, sg * 7.6, 19), Vector3(17.5, sg * 13.5, 27), 1.5, bone)
		s.ell(Vector3(25.6, sg * 4.0, 17.4), Vector3(1.8, 1.6, 1.4), [_hx("ffe848")])
		s.ell(Vector3(26.4, sg * 4.0, 17.4), Vector3(0.8, 0.8, 0.8), [_hx("fff8c0")])
	return s.render(84, 76, 48.0)

static func _feathers(s: Scene3, sg: float, fl: float, n: int, base_len: float, z0: float, wing: Array) -> void:
	for i in n:
		var ln := base_len * (1.0 - 0.1 * float(i))
		var th := sg * (PI / 2.0 - 0.55 + float(i) * 0.38)
		var c := Vector3(1.0 + cos(th) * ln * 0.55, sin(th) * ln * 0.55, z0 + fl * float(i) * 0.9)
		var pal: Array = wing.slice((i % 2) * 2, (i % 2) * 2 + 2)
		s.ell(c, Vector3(ln * 0.55, 1.9, 0.8), pal, _rz(th) * _rx(-sg * (0.12 + fl * 0.5)))

static func _herald(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var fl: float = [0.0, 0.6][f % 2]
	var wing := _P(["9090aa", "c0c0d6", "e6e6f4", "fffff6"])
	var armor := _P(["8a7a40", "c8a848", "f0d070", "fff0a0"])
	var robe := _P(["a8a8c0", "d0d0e4", "eeeef8", "ffffff"])
	var glow := _P(["c89818", "ffd850", "fff8c0"])
	for sg: float in [-1.0, 1.0]:
		_feathers(s, sg, fl, 5, 17.0, 15.0, wing)
		s.cap(Vector3(2, sg * 4.5, 18), Vector3(7, sg * 8.5, 13), 1.7, robe)
		s.ell(Vector3(8, sg * 8.8, 12.5), Vector3(1.7, 1.7, 1.7), armor)
	s.cone(Vector3(-1, 0, 9), 6.2, 8, robe)
	s.ell(Vector3(0, 0, 15), Vector3(4.8, 5.6, 4.8), armor)
	for k in 10:
		var t := float(k) * PI / 5.0
		s.ell(Vector3(0.5 + 4.6 * cos(t), 4.6 * sin(t), 26.8), Vector3(1.0, 1.0, 0.7), glow)
	s.ell(Vector3(1, 0, 22), Vector3(3.4, 3.4, 3.4), robe)
	s.ell(Vector3(3.7, 0, 22.4), Vector3(0.9, 2.2, 0.7), [_hx("202030")])
	s.ell(Vector3(5.5, 0, 16), Vector3(1.6, 1.6, 1.6), glow)
	return s.render(60, 52, 36.0)

static func _b_seraph(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var fl: float = [0.0, 0.5][f % 2]
	var wing := _P(["8484a4", "b4b4d0", "e0e0f0", "fffff6"])
	var armor := _P(["8a7030", "c8a040", "f0d068", "fff0a0"])
	var robe := _P(["8a8aac", "b8b8d8", "e4e4f4", "ffffff"])
	var glow := _P(["c89818", "ffd850", "fff8c0"])
	var dark := _P(["10101c", "1c1c30"])
	var tiers := [[5, 34.0, 22.0], [5, 28.0, 25.0], [4, 22.0, 28.0]]
	for t in 3:
		var tr: Array = tiers[t]
		for sg: float in [-1.0, 1.0]:
			_feathers(s, sg, fl * (1.0 - float(t) * 0.2), int(tr[0]), float(tr[1]), float(tr[2]), wing)
	s.cone(Vector3(-2, 0, 11), 12, 12, robe)
	s.ell(Vector3(0, 0, 22), Vector3(9, 10.5, 8), armor)
	for k in 14:
		var a := float(k) * PI / 7.0
		s.ell(Vector3(1.0 + 7.0 * cos(a), 7.0 * sin(a), 42.5), Vector3(1.5, 1.5, 1.0), glow)
	s.ell(Vector3(1, 0, 32), Vector3(5.6, 5.6, 5.6), robe)
	s.ell(Vector3(6, 0, 32.5), Vector3(1.2, 3.2, 1.0), dark)
	for sg: float in [-1.0, 1.0]:
		s.cap(Vector3(3, sg * 8, 28), Vector3(11, sg * 13, 20), 2.6, robe)
		s.ell(Vector3(12, sg * 13.5, 19), Vector3(3, 3, 3), armor)
	s.ell(Vector3(9, 0, 23), Vector3(2.8, 2.8, 2.8), glow)
	return s.render(120, 104, 66.0)

const _PET := ["120208", "3a0a1c", "66143a", "952a58", "c4547c"]
const _TEETH := ["b8b090", "e8e4cc", "ffffee"]

static func _thornling(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var k: float = [0.0, 1.0, 0.0, -1.0][f % 4] * 2.2
	var body := _P(["0a1c10", "122e18", "1c4422", "2e6430", "468a3e"])
	var root := _P(["120c06", "241808", "3a2a12", "54401e"])
	var glow := _P(["5a7a08", "a8d818", "f0ff70"])
	var thorn := _P(["a8a080", "d8d0b4", "fffff0"])
	var pet := _P(_PET)
	var teeth := _P(_TEETH)
	for i in 6:
		var a := float(i) * PI / 3.0 + 0.3
		var sw := k * (1.0 if i % 2 == 1 else -1.0)
		s.cap(Vector3(cos(a) * 3.0, sin(a) * 3.0, 8), Vector3(cos(a) * 9.0 + sw * 0.5, sin(a) * 9.0 + sw * 0.5, 1.2), 1.3, root)
	s.ell(Vector3(-2, 0, 10), Vector3(7.5, 7.0, 6.5), body)
	for a: float in [2.4, 3.2, 4.0, 0.9, 5.6]:
		s.cone(Vector3(-2.0 + cos(a) * 6.5, sin(a) * 6.5, 13), 1.3, 2.6, thorn)
	s.cap(Vector3(0, 0, 12), Vector3(6, 0, 18), 2.4, body)
	for yz: Vector2 in [Vector2(-5.5, 18), Vector2(-3, 22.5), Vector2(0, 23.5), Vector2(3, 22.5), Vector2(5.5, 18)]:
		s.ell(Vector3(10.5, yz.x, yz.y), Vector3(6.5, 1.7, 1.2), pet, _rz(yz.x * 0.07))
	s.ell(Vector3(8, 0, 17.5), Vector3(4.2, 3.6, 2.4), glow)
	for yy: float in [-3.2, -1.1, 1.1, 3.2]:
		s.cone(Vector3(11.5, yy, 19.2), 0.9, 1.9, teeth)
	return s.render(54, 50, 36.0)

static func _b_queen(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var sw: float = [0.0, 1.0, 0.0, -1.0][f % 4] * 2.5
	var body := _P(["0a1c10", "122e18", "1c4422", "2e6430", "468a3e"])
	var root := _P(["120c06", "241808", "3a2a12", "54401e"])
	var glow := _P(["5a7a08", "a8d818", "f0ff70"])
	var thorn := _P(["a8a080", "d8d0b4", "fffff0"])
	var vine := _P(["081808", "10301a", "1c4a24", "2e6c34"])
	var pet := _P(_PET)
	var teeth := _P(_TEETH)
	for i in 8:
		var a := float(i) * PI / 4.0 + 0.2
		var sg := sw * (1.0 if i % 2 == 1 else -1.0)
		s.cap(Vector3(cos(a) * 6.0, sin(a) * 6.0, 12), Vector3(cos(a) * 24.0 + sg * 0.6, sin(a) * 24.0 + sg * 0.6, 1.5), 2.4, root)
	for i in 6:
		var a := float(i) * PI / 3.0 + 0.6
		var p0 := Vector3(cos(a) * 10.0, sin(a) * 10.0, 8)
		var p1 := Vector3(cos(a + 0.35) * 22.0, sin(a + 0.35) * 22.0, 4)
		s.cap(p0, p1, 1.8, vine)
		for t: float in [0.3, 0.6, 0.9]:
			var q := p0.lerp(p1, t)
			s.cone(Vector3(q.x, q.y, q.z + 2.5), 1.3, 2.8, thorn)
	s.ell(Vector3(0, 0, 15), Vector3(13.5, 13.5, 9.5), body)
	for a: float in [0.3, 1.1, 1.9, 2.7, 3.5, 4.3, 5.1, 5.9]:
		s.cone(Vector3(cos(a) * 12.0, sin(a) * 12.0, 18), 2.2, 4.5, thorn)
	for i in 12:
		var a := float(i) * TAU / 12.0
		s.ell(Vector3(cos(a) * 11.0, sin(a) * 11.0, 24.5 + sin(a * 3.0 + float(f)) * 0.5), Vector3(9.5, 2.4, 1.3), pet, _rz(a) * Basis(Vector3(0, 1, 0), 0.6))
	for i in 9:
		var a := float(i) * TAU / 9.0 + 0.3
		s.ell(Vector3(cos(a) * 6.0, sin(a) * 6.0, 28), Vector3(6.0, 2.0, 1.0), pet, _rz(a) * Basis(Vector3(0, 1, 0), 0.3))
	s.ell(Vector3(0, 0, 28), Vector3(8, 8, 3), glow)
	s.ell(Vector3(0, 0, 29.4), Vector3(5.6, 5.6, 2.0), _P(["100804", "281408"]))
	for i in 12:
		var a := float(i) * TAU / 12.0
		s.cone(Vector3(cos(a) * 6.6, sin(a) * 6.6, 31), 1.2, 3.4, teeth)
	return s.render(110, 100, 62.0)

const _SEA_SK := ["0c1c34", "1a3458", "2c5686", "4482b4", "6aaad8"]
const _SEA_SKD := ["040a18", "0a1428", "10223a", "1a3450", "264a68"]
const _SEA_BELLY := ["2a3a58", "44587c", "6c84a8", "9cb4d0"]
const _SEA_TEETH := ["b8c8d0", "e4eef2", "ffffff"]
const _SEA_LURE := ["18a088", "40f0d0", "c8fff4"]

static func _angler(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var k: float = [0.0, 1.0, 0.0, -1.0][f % 4] * 2.6
	var sk := _P(_SEA_SK)
	var skd := _P(_SEA_SKD)
	var belly := _P(_SEA_BELLY)
	var teeth := _P(_SEA_TEETH)
	var lure := _P(_SEA_LURE)
	for l: Vector3 in [Vector3(5, -6, k), Vector3(5, 6, -k), Vector3(-6, -6, -k), Vector3(-6, 6, k)]:
		s.cap(Vector3(l.x, l.y * 0.6, 6.5), Vector3(l.x + l.z, l.y * 1.35, 1.6), 1.5, skd)
		s.ell(Vector3(l.x + l.z + 0.8, l.y * 1.35, 1.3), Vector3(2.4, 2.0, 1.0), skd)
	s.cap(Vector3(-9, 0, 10), Vector3(-15, k * 0.6, 9), 2.0, sk)
	s.ell(Vector3(-17, k * 0.8, 9), Vector3(2.6, 5.0, 1.2), skd)
	s.ell(Vector3(-1, 0, 11), Vector3(10.5, 6.6, 6.4), sk)
	s.ell(Vector3(-1, 0, 9), Vector3(9, 5.4, 3.6), belly)
	for x: float in [-5.0, -1.0, 3.0]:
		s.cone(Vector3(x, 0, 16.8), 1.6, 3.2, skd)
	s.ell(Vector3(8, 0, 12), Vector3(6.5, 6.0, 5.6), sk)
	s.ell(Vector3(13.5, 0, 13.5), Vector3(4.5, 5.0, 2.6), skd)
	s.ell(Vector3(13, 0, 9), Vector3(5.0, 5.2, 2.0), skd)
	for yy: float in [-3.6, -1.2, 1.2, 3.6]:
		s.cone(Vector3(15.8, yy, 12.0), 0.8, 2.0, teeth)
		s.cone(Vector3(15.4, yy * 0.9, 10.5), 0.8, 2.0, teeth)
	s.cap(Vector3(8, 0, 16), Vector3(10.5, 0, 23), 0.8, skd)
	s.cap(Vector3(10.5, 0, 23), Vector3(16, 0, 24), 0.7, skd)
	s.ell(Vector3(16.8, 0, 23.8), Vector3(2.4, 2.4, 2.4), lure)
	for sg: float in [-1.0, 1.0]:
		s.ell(Vector3(10.5, sg * 4.0, 16), Vector3(1.7, 1.5, 1.4), [_hx("ffe848")])
	return s.render(60, 52, 34.0)

static func _b_leviathan(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var w: float = [0.0, 1.0, 0.0, -1.0][f % 4] * 2.0
	var sk := _P(_SEA_SK)
	var skd := _P(_SEA_SKD)
	var belly := _P(_SEA_BELLY)
	var teeth := _P(_SEA_TEETH)
	var lure := _P(_SEA_LURE)
	for i in 4:
		var t := float(i) / 3.0
		var x := -12.0 - float(i) * 8.0
		var y := sin(float(i) * 1.1 + float(f) * 0.8) * 7.0 * (0.4 + t)
		var r := 10.0 - 6.0 * t
		s.ell(Vector3(x, y, r + 2.0), Vector3(r + 1.0, r, r), sk)
		if i % 2 == 0:
			s.cone(Vector3(x, y, r * 2.0 + 1.5), 1.8, 3.2 - 1.6 * t, skd)
	s.ell(Vector3(-6, 0, 14), Vector3(14, 11, 9.5), sk)
	s.ell(Vector3(-6, 0, 11), Vector3(12, 9, 5), belly)
	for x: float in [-10.0, -4.0, 2.0]:
		s.cone(Vector3(x, 0, 23), 2.6, 5, skd)
	for sg: float in [-1.0, 1.0]:
		s.ell(Vector3(-4, sg * 14, 10), Vector3(9, 3.2, 1.2), skd, _rz(sg * 0.5) * _rx(-sg * (0.25 + 0.1 * w)))
	s.ell(Vector3(12, 0, 15), Vector3(9.5, 9, 8), sk)
	s.ell(Vector3(20, 0, 17), Vector3(7, 7.2, 3.4), skd)
	s.ell(Vector3(19, 0, 10.5), Vector3(7.5, 7.2, 2.6), skd)
	for yy: float in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		s.cone(Vector3(25.5, yy, 15.2), 1.1, 3.0, teeth)
		s.cone(Vector3(24.5, yy * 0.9, 12.0), 1.1, 3.0, teeth)
	s.cap(Vector3(10, 0, 20), Vector3(15, 0, 31), 1.2, skd)
	s.cap(Vector3(15, 0, 31), Vector3(24, 0, 33), 1.0, skd)
	s.ell(Vector3(25.5, 0, 33), Vector3(4, 4, 4), lure)
	for sg: float in [-1.0, 1.0]:
		s.ell(Vector3(17, sg * 6.4, 21), Vector3(2.6, 2.2, 2.0), [_hx("ffe848")])
		s.ell(Vector3(18, sg * 6.4, 21), Vector3(1.1, 1.1, 1.1), [_hx("fff8c0")])
	return s.render(112, 92, 56.0)

const _SH_HULL := ["20262e", "323a48", "4a5466", "6a768c", "8e9ab2"]
const _SH_DECK := ["3a4250", "565f70", "78849a", "a2aec4"]
const _SH_DK := ["10141a", "1c222c", "2c3440", "424c5c"]
const _SH_RED := ["4a0e0e", "7a1818", "a82828"]
const _SH_FOAM := ["9ab8c8", "d0e4f0", "ffffff"]
const _SH_LT := ["8a8a40", "d8d060", "fff8a0"]
const _SH_WH := ["8a94a8", "b4bece", "e0e8f4", "ffffff"]
const _SH_ORA := ["8a3a08", "d86a18", "ffa040"]
const _SH_GLS := ["06121e", "12304a", "2a5e82", "78b4d0"]
const _SH_GRY := ["4a5468", "7a869a", "aab6c8", "d8e2f0"]
const _SH_BLK := ["04060a", "0e121a", "1a202c"]
const _SH_GRN := ["1a3a22", "2c5a38", "46845a"]

static func _ship_hull(s: Scene3, len_: float, beam: float, h: float) -> void:
	s.ell(Vector3(0, 0, h * 0.7), Vector3(len_, beam, h * 0.8), _P(_SH_RED))
	s.ell(Vector3(0, 0, h), Vector3(len_, beam, h), _P(_SH_HULL))
	s.ell(Vector3(len_ * 0.72, 0, h + 0.4), Vector3(len_ * 0.4, beam * 0.85, h * 0.9), _P(_SH_HULL))
	s.box(Vector3(-len_ * 0.1, 0, h * 1.55), Vector3(len_ * 0.78, beam * 0.82, 0.8), _P(_SH_DECK))

# The white foam beside the hull is no longer painted into the sprite: Enemy._draw_wake animates it as bubbles
# that only appear while the ship is sailing.
static func _ship_wake(_s: Scene3, _len: float, _beam: float, _f: int) -> void:
	pass

static func _ship_turret(s: Scene3, x: float, y: float, z: float, sc: float, dirx: float, n: int) -> void:
	s.cyl(Vector3(x, y, z), 3.2 * sc, 1.4 * sc, _P(_SH_DECK))
	for k in n:
		var yy := y + (float(k) - float(n - 1) / 2.0) * 2.0 * sc
		s.cap(Vector3(x, yy, z + 1.2 * sc), Vector3(x + 7.0 * sc * dirx, yy, z + 1.4 * sc), 0.8 * sc, _P(_SH_DK))

static func _destroyer(_f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	s.us = 2.0
	var blk := _P(_SH_BLK)
	var deck := _P(_SH_DECK)
	var dk := _P(_SH_DK)
	var gls := _P(_SH_GLS)
	var gry := _P(_SH_GRY)
	var hull := _P(_SH_HULL)
	var lt := _P(_SH_LT)
	var ora := _P(_SH_ORA)
	var red := _P(_SH_RED)
	var wh := _P(_SH_WH)
	s.ell(Vector3(0, 0, 2.8), Vector3(22, 5.2, 3.2), red)
	s.ell(Vector3(0, 0, 4), Vector3(22, 5.2, 4), hull)
	s.ell(Vector3(15.84, 0, 4.4), Vector3(8.8, 4.42, 3.6), hull)
	s.box(Vector3(-2.2, 0, 6.2), Vector3(17.16, 4.264, 0.8), deck)
	s.ell(Vector3(0, -5.044, 4.2), Vector3(19.8, 0.25, 0.3), dk)
	s.box(Vector3(12.1, -4.16, 4.6), Vector3(1.54, 0.18, 0.56), wh)
	s.box(Vector3(13.64, -4.056, 4.6), Vector3(0.88, 0.18, 0.56), wh)
	s.ell(Vector3(17.16, -2.496, 4.8), Vector3(0.8, 0.5, 0.7), dk)
	s.ell(Vector3(0, 5.044, 4.2), Vector3(19.8, 0.25, 0.3), dk)
	s.box(Vector3(12.1, 4.16, 4.6), Vector3(1.54, 0.18, 0.56), wh)
	s.box(Vector3(13.64, 4.056, 4.6), Vector3(0.88, 0.18, 0.56), wh)
	s.ell(Vector3(17.16, 2.496, 4.8), Vector3(0.8, 0.5, 0.7), dk)
	s.cap(Vector3(-17, -4.2, 7.9), Vector3(13, -4.2, 7.9), 0.2, gry)
	s.cap(Vector3(-17, -4.2, 7), Vector3(-17, -4.2, 7.9), 0.15, gry)
	s.cap(Vector3(-14, -4.2, 7), Vector3(-14, -4.2, 7.9), 0.15, gry)
	s.cap(Vector3(-11, -4.2, 7), Vector3(-11, -4.2, 7.9), 0.15, gry)
	s.cap(Vector3(-8, -4.2, 7), Vector3(-8, -4.2, 7.9), 0.15, gry)
	s.cap(Vector3(-5, -4.2, 7), Vector3(-5, -4.2, 7.9), 0.15, gry)
	s.cap(Vector3(-2, -4.2, 7), Vector3(-2, -4.2, 7.9), 0.15, gry)
	s.cap(Vector3(1, -4.2, 7), Vector3(1, -4.2, 7.9), 0.15, gry)
	s.cap(Vector3(4, -4.2, 7), Vector3(4, -4.2, 7.9), 0.15, gry)
	s.cap(Vector3(7, -4.2, 7), Vector3(7, -4.2, 7.9), 0.15, gry)
	s.cap(Vector3(10, -4.2, 7), Vector3(10, -4.2, 7.9), 0.15, gry)
	s.cap(Vector3(13, -4.2, 7), Vector3(13, -4.2, 7.9), 0.15, gry)
	s.cap(Vector3(-17, 4.2, 7.9), Vector3(13, 4.2, 7.9), 0.2, gry)
	s.cap(Vector3(-17, 4.2, 7), Vector3(-17, 4.2, 7.9), 0.15, gry)
	s.cap(Vector3(-14, 4.2, 7), Vector3(-14, 4.2, 7.9), 0.15, gry)
	s.cap(Vector3(-11, 4.2, 7), Vector3(-11, 4.2, 7.9), 0.15, gry)
	s.cap(Vector3(-8, 4.2, 7), Vector3(-8, 4.2, 7.9), 0.15, gry)
	s.cap(Vector3(-5, 4.2, 7), Vector3(-5, 4.2, 7.9), 0.15, gry)
	s.cap(Vector3(-2, 4.2, 7), Vector3(-2, 4.2, 7.9), 0.15, gry)
	s.cap(Vector3(1, 4.2, 7), Vector3(1, 4.2, 7.9), 0.15, gry)
	s.cap(Vector3(4, 4.2, 7), Vector3(4, 4.2, 7.9), 0.15, gry)
	s.cap(Vector3(7, 4.2, 7), Vector3(7, 4.2, 7.9), 0.15, gry)
	s.cap(Vector3(10, 4.2, 7), Vector3(10, 4.2, 7.9), 0.15, gry)
	s.cap(Vector3(13, 4.2, 7), Vector3(13, 4.2, 7.9), 0.15, gry)
	s.box(Vector3(-2, 0, 10.5), Vector3(5, 3.2, 2.4), deck)
	s.box(Vector3(3.05, 0, 11.2), Vector3(0.12, 2.72, 0.5), gls)
	s.box(Vector3(-2, -3.25, 11.2), Vector3(4.25, 0.12, 0.5), gls)
	s.box(Vector3(-2, 3.25, 11.2), Vector3(4.25, 0.12, 0.5), gls)
	s.box(Vector3(-2, 0, 13.2), Vector3(3, 2.4, 1.2), wh)
	s.box(Vector3(1.05, 0, 13.3), Vector3(0.12, 2.04, 0.45), gls)
	s.box(Vector3(-2, -2.45, 13.3), Vector3(2.55, 0.12, 0.45), gls)
	s.box(Vector3(-2, 2.45, 13.3), Vector3(2.55, 0.12, 0.45), gls)
	s.box(Vector3(1.2, 0, 9.6), Vector3(0.5, 2.6, 0.4), dk)
	s.cap(Vector3(-2, 0, 14), Vector3(-2, 0, 21), 0.4, dk)
	s.ell(Vector3(-2, 0, 18), Vector3(0.4, 2.6, 0.3), dk)
	s.cap(Vector3(-2, 0, 18.5), Vector3(-2, 0, 21.5), 0.4, dk)
	s.ell(Vector3(-2, 0, 21.9), Vector3(1.2, 3.2, 0.35), dk)
	s.ell(Vector3(-2, 0, 21.9), Vector3(0.8, 2.24, 0.4), gry)
	s.cap(Vector3(-2, 0, 22), Vector3(-2, 0, 25), 0.18, dk)
	s.box(Vector3(-2.9, 0, 24.4), Vector3(0.9, 0.08, 0.55), red)
	s.cyl(Vector3(-9, 0, 10), 1.8, 2.2, dk)
	s.cyl(Vector3(-9, 0, 12.3), 1.95, 0.25, gry)
	s.ell(Vector3(-9, 0, 12.6), Vector3(1.3, 1.3, 0.3), blk)
	s.cyl(Vector3(10, 0, 8.2), 2.88, 1.26, deck)
	s.ell(Vector3(10.54, 0, 9.55), Vector3(2.16, 1.98, 0.9), gry)
	s.cap(Vector3(10, 0, 9.46), Vector3(17.2, 0, 9.55), 0.72, dk)
	s.ell(Vector3(17.2, 0, 9.55), Vector3(0.45, 0.81, 0.81), blk)
	s.cyl(Vector3(-14, 0, 8.2), 2.56, 1.12, deck)
	s.ell(Vector3(-14.48, 0, 9.4), Vector3(1.92, 1.76, 0.8), gry)
	s.cap(Vector3(-14, 0, 9.32), Vector3(-20.4, 0, 9.4), 0.64, dk)
	s.ell(Vector3(-20.4, 0, 9.4), Vector3(0.4, 0.72, 0.72), blk)
	s.cyl(Vector3(-5.8, 3.4, 7.6), 1.2, 0.6, dk)
	s.ell(Vector3(-5.8, 3.4, 9), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(-5.8, 3.4, 9.3), Vector3(-3.6, 3.4, 9.5), 0.35, dk)
	s.cyl(Vector3(-5.8, -3.4, 7.6), 1.2, 0.6, dk)
	s.ell(Vector3(-5.8, -3.4, 9), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(-5.8, -3.4, 9.3), Vector3(-3.6, -3.4, 9.5), 0.35, dk)
	s.cap(Vector3(-12.5, -3, 7.9), Vector3(-9.5, -3, 8), 0.7, gry)
	s.cap(Vector3(-19, -2, 7.5), Vector3(-19, -2, 8.2), 0.5, dk)
	s.cap(Vector3(-12.5, 3, 7.9), Vector3(-9.5, 3, 8), 0.7, gry)
	s.cap(Vector3(-19, 2, 7.5), Vector3(-19, 2, 8.2), 0.5, dk)
	s.ell(Vector3(4, -3.8, 7.9), Vector3(2.2, 0.9, 0.75), ora)
	s.ell(Vector3(4, -3.8, 8.45), Vector3(1.6, 0.6, 0.3), wh)
	s.ell(Vector3(4, 3.8, 7.9), Vector3(2.2, 0.9, 0.75), ora)
	s.ell(Vector3(4, 3.8, 8.45), Vector3(1.6, 0.6, 0.3), wh)
	s.ell(Vector3(15, 0, 9.2), Vector3(1.3, 1.3, 1), lt)
	return s.render(168, 112, 72.0)

static func _cruiser(_f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	s.us = 2.0
	var blk := _P(_SH_BLK)
	var deck := _P(_SH_DECK)
	var dk := _P(_SH_DK)
	var gls := _P(_SH_GLS)
	var grn := _P(_SH_GRN)
	var gry := _P(_SH_GRY)
	var hull := _P(_SH_HULL)
	var ora := _P(_SH_ORA)
	var red := _P(_SH_RED)
	var wh := _P(_SH_WH)
	s.ell(Vector3(0, 0, 3.5), Vector3(30, 7.2, 4), red)
	s.ell(Vector3(0, 0, 5), Vector3(30, 7.2, 5), hull)
	s.ell(Vector3(21.6, 0, 5.4), Vector3(12, 6.12, 4.5), hull)
	s.box(Vector3(-3, 0, 7.75), Vector3(23.4, 5.904, 0.8), deck)
	s.ell(Vector3(0, -6.984, 5.25), Vector3(27, 0.25, 0.3), dk)
	s.box(Vector3(16.5, -5.76, 5.75), Vector3(2.1, 0.18, 0.7), wh)
	s.box(Vector3(18.6, -5.616, 5.75), Vector3(1.2, 0.18, 0.7), wh)
	s.ell(Vector3(23.4, -3.456, 6), Vector3(0.8, 0.5, 0.7), dk)
	s.ell(Vector3(0, 6.984, 5.25), Vector3(27, 0.25, 0.3), dk)
	s.box(Vector3(16.5, 5.76, 5.75), Vector3(2.1, 0.18, 0.7), wh)
	s.box(Vector3(18.6, 5.616, 5.75), Vector3(1.2, 0.18, 0.7), wh)
	s.ell(Vector3(23.4, 3.456, 6), Vector3(0.8, 0.5, 0.7), dk)
	s.cap(Vector3(-24, -6.1, 9.45), Vector3(18, -6.1, 9.45), 0.2, gry)
	s.cap(Vector3(-24, -6.1, 8.55), Vector3(-24, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-21, -6.1, 8.55), Vector3(-21, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-18, -6.1, 8.55), Vector3(-18, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-15, -6.1, 8.55), Vector3(-15, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-12, -6.1, 8.55), Vector3(-12, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-9, -6.1, 8.55), Vector3(-9, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-6, -6.1, 8.55), Vector3(-6, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-3, -6.1, 8.55), Vector3(-3, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(0, -6.1, 8.55), Vector3(0, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(3, -6.1, 8.55), Vector3(3, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(6, -6.1, 8.55), Vector3(6, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(9, -6.1, 8.55), Vector3(9, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(12, -6.1, 8.55), Vector3(12, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(15, -6.1, 8.55), Vector3(15, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(18, -6.1, 8.55), Vector3(18, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-24, 6.1, 9.45), Vector3(18, 6.1, 9.45), 0.2, gry)
	s.cap(Vector3(-24, 6.1, 8.55), Vector3(-24, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-21, 6.1, 8.55), Vector3(-21, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-18, 6.1, 8.55), Vector3(-18, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-15, 6.1, 8.55), Vector3(-15, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-12, 6.1, 8.55), Vector3(-12, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-9, 6.1, 8.55), Vector3(-9, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-6, 6.1, 8.55), Vector3(-6, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-3, 6.1, 8.55), Vector3(-3, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(0, 6.1, 8.55), Vector3(0, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(3, 6.1, 8.55), Vector3(3, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(6, 6.1, 8.55), Vector3(6, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(9, 6.1, 8.55), Vector3(9, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(12, 6.1, 8.55), Vector3(12, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(15, 6.1, 8.55), Vector3(15, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(18, 6.1, 8.55), Vector3(18, 6.1, 9.45), 0.15, gry)
	s.box(Vector3(-3, 0, 12), Vector3(8, 4.6, 2.8), deck)
	s.box(Vector3(5.05, 0, 12.4), Vector3(0.12, 3.91, 0.6), gls)
	s.box(Vector3(-3, -4.65, 12.4), Vector3(6.8, 0.12, 0.6), gls)
	s.box(Vector3(-3, 4.65, 12.4), Vector3(6.8, 0.12, 0.6), gls)
	s.box(Vector3(-3, 0, 15.5), Vector3(5, 3.4, 1.4), wh)
	s.box(Vector3(2.05, 0, 15.6), Vector3(0.12, 2.89, 0.5), gls)
	s.box(Vector3(-3, -3.45, 15.6), Vector3(4.25, 0.12, 0.5), gls)
	s.box(Vector3(-3, 3.45, 15.6), Vector3(4.25, 0.12, 0.5), gls)
	s.box(Vector3(-3, 0, 18), Vector3(3, 2.4, 1.2), deck)
	s.box(Vector3(0.05, 0, 18.1), Vector3(0.12, 2.04, 0.4), gls)
	s.box(Vector3(-3, -2.45, 18.1), Vector3(2.55, 0.12, 0.4), gls)
	s.box(Vector3(-3, 2.45, 18.1), Vector3(2.55, 0.12, 0.4), gls)
	s.cap(Vector3(-3, 0, 19), Vector3(-3, 0, 28), 0.5, dk)
	s.ell(Vector3(-3, 0, 24), Vector3(0.6, 4.5, 0.5), dk)
	s.cap(Vector3(-3, 0, 25.5), Vector3(-3, 0, 28.5), 0.4, dk)
	s.ell(Vector3(-3, 0, 28.9), Vector3(1.2, 3.8, 0.35), dk)
	s.ell(Vector3(-3, 0, 28.9), Vector3(0.8, 2.66, 0.4), gry)
	s.cap(Vector3(-3, 0, 29), Vector3(-3, 0, 32), 0.18, dk)
	s.box(Vector3(-3.9, 0, 31.4), Vector3(0.9, 0.08, 0.55), red)
	s.box(Vector3(2.4, 0, 20.6), Vector3(0.3, 3, 0.9), dk)
	s.cyl(Vector3(-12, 0, 11.5), 2.2, 2.6, dk)
	s.cyl(Vector3(-12, 0, 14.2), 2.3, 0.25, gry)
	s.ell(Vector3(-12, 0, 14.5), Vector3(1.6, 1.6, 0.3), blk)
	s.cyl(Vector3(6, 0, 11.5), 2, 2.4, dk)
	s.cyl(Vector3(6, 0, 14.2), 2.1, 0.25, gry)
	s.ell(Vector3(6, 0, 14.5), Vector3(1.6, 1.6, 0.3), blk)
	s.cyl(Vector3(16, 0, 9.65), 3.84, 1.68, deck)
	s.ell(Vector3(16.72, 0, 11.45), Vector3(2.88, 2.64, 1.2), gry)
	s.cap(Vector3(16, -1.2, 11.33), Vector3(25.6, -1.2, 11.45), 0.96, dk)
	s.ell(Vector3(25.6, -1.2, 11.45), Vector3(0.6, 1.08, 1.08), blk)
	s.cap(Vector3(16, 1.2, 11.33), Vector3(25.6, 1.2, 11.45), 0.96, dk)
	s.ell(Vector3(25.6, 1.2, 11.45), Vector3(0.6, 1.08, 1.08), blk)
	s.cyl(Vector3(11, 0, 10.85), 3.52, 1.54, deck)
	s.ell(Vector3(11.66, 0, 12.5), Vector3(2.64, 2.42, 1.1), gry)
	s.cap(Vector3(11, -1.1, 12.39), Vector3(19.8, -1.1, 12.5), 0.88, dk)
	s.ell(Vector3(19.8, -1.1, 12.5), Vector3(0.55, 0.99, 0.99), blk)
	s.cap(Vector3(11, 1.1, 12.39), Vector3(19.8, 1.1, 12.5), 0.88, dk)
	s.ell(Vector3(19.8, 1.1, 12.5), Vector3(0.55, 0.99, 0.99), blk)
	s.cyl(Vector3(-20, 0, 9.65), 3.52, 1.54, deck)
	s.ell(Vector3(-20.66, 0, 11.3), Vector3(2.64, 2.42, 1.1), gry)
	s.cap(Vector3(-20, -1.1, 11.19), Vector3(-28.8, -1.1, 11.3), 0.88, dk)
	s.ell(Vector3(-28.8, -1.1, 11.3), Vector3(0.55, 0.99, 0.99), blk)
	s.cap(Vector3(-20, 1.1, 11.19), Vector3(-28.8, 1.1, 11.3), 0.88, dk)
	s.ell(Vector3(-28.8, 1.1, 11.3), Vector3(0.55, 0.99, 0.99), blk)
	s.cyl(Vector3(-25, 0, 8.75), 4.6, 0.18, grn)
	s.box(Vector3(-25, 0, 9), Vector3(2.2, 0.28, 0.1), wh)
	s.box(Vector3(-25.8, 0, 9), Vector3(0.28, 1.5, 0.1), wh)
	s.box(Vector3(-24.2, 0, 9), Vector3(0.28, 1.5, 0.1), wh)
	s.cyl(Vector3(6.5, 5.4, 9.15), 1.2, 0.6, dk)
	s.ell(Vector3(6.5, 5.4, 10.55), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(6.5, 5.4, 10.85), Vector3(8.7, 5.4, 11.05), 0.35, dk)
	s.cyl(Vector3(6.5, -5.4, 9.15), 1.2, 0.6, dk)
	s.ell(Vector3(6.5, -5.4, 10.55), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(6.5, -5.4, 10.85), Vector3(8.7, -5.4, 11.05), 0.35, dk)
	s.cyl(Vector3(-14, 5, 9.15), 1.2, 0.6, dk)
	s.ell(Vector3(-14, 5, 10.55), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(-14, 5, 10.85), Vector3(-11.8, 5, 11.05), 0.35, dk)
	s.cyl(Vector3(-14, -5, 9.15), 1.2, 0.6, dk)
	s.ell(Vector3(-14, -5, 10.55), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(-14, -5, 10.85), Vector3(-11.8, -5, 11.05), 0.35, dk)
	s.ell(Vector3(-6.5, -5.6, 9.45), Vector3(2.2, 0.9, 0.75), ora)
	s.ell(Vector3(-6.5, -5.6, 10), Vector3(1.6, 0.6, 0.3), wh)
	s.ell(Vector3(-6.5, 5.6, 9.45), Vector3(2.2, 0.9, 0.75), ora)
	s.ell(Vector3(-6.5, 5.6, 10), Vector3(1.6, 0.6, 0.3), wh)
	s.cap(Vector3(-9, -5.4, 9.45), Vector3(-9, -5.4, 11.55), 0.35, dk)
	s.cap(Vector3(-9, -5.4, 11.55), Vector3(-5, -5.4, 11.85), 0.3, dk)
	s.cap(Vector3(-9, 5.4, 9.45), Vector3(-9, 5.4, 11.55), 0.35, dk)
	s.cap(Vector3(-9, 5.4, 11.55), Vector3(-5, 5.4, 11.85), 0.3, dk)
	return s.render(208, 128, 84.0)

static func _missilecruiser(_f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	s.us = 2.0
	var blk := _P(_SH_BLK)
	var deck := _P(_SH_DECK)
	var dk := _P(_SH_DK)
	var gls := _P(_SH_GLS)
	var gry := _P(_SH_GRY)
	var hull := _P(_SH_HULL)
	var ora := _P(_SH_ORA)
	var red := _P(_SH_RED)
	var wh := _P(_SH_WH)
	s.ell(Vector3(0, 0, 3.5), Vector3(30, 7.2, 4), red)
	s.ell(Vector3(0, 0, 5), Vector3(30, 7.2, 5), hull)
	s.ell(Vector3(21.6, 0, 5.4), Vector3(12, 6.12, 4.5), hull)
	s.box(Vector3(-3, 0, 7.75), Vector3(23.4, 5.904, 0.8), deck)
	s.ell(Vector3(0, -6.984, 5.25), Vector3(27, 0.25, 0.3), dk)
	s.box(Vector3(16.5, -5.76, 5.75), Vector3(2.1, 0.18, 0.7), wh)
	s.box(Vector3(18.6, -5.616, 5.75), Vector3(1.2, 0.18, 0.7), wh)
	s.ell(Vector3(23.4, -3.456, 6), Vector3(0.8, 0.5, 0.7), dk)
	s.ell(Vector3(0, 6.984, 5.25), Vector3(27, 0.25, 0.3), dk)
	s.box(Vector3(16.5, 5.76, 5.75), Vector3(2.1, 0.18, 0.7), wh)
	s.box(Vector3(18.6, 5.616, 5.75), Vector3(1.2, 0.18, 0.7), wh)
	s.ell(Vector3(23.4, 3.456, 6), Vector3(0.8, 0.5, 0.7), dk)
	s.cap(Vector3(-24, -6.1, 9.45), Vector3(18, -6.1, 9.45), 0.2, gry)
	s.cap(Vector3(-24, -6.1, 8.55), Vector3(-24, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-21, -6.1, 8.55), Vector3(-21, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-18, -6.1, 8.55), Vector3(-18, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-15, -6.1, 8.55), Vector3(-15, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-12, -6.1, 8.55), Vector3(-12, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-9, -6.1, 8.55), Vector3(-9, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-6, -6.1, 8.55), Vector3(-6, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-3, -6.1, 8.55), Vector3(-3, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(0, -6.1, 8.55), Vector3(0, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(3, -6.1, 8.55), Vector3(3, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(6, -6.1, 8.55), Vector3(6, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(9, -6.1, 8.55), Vector3(9, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(12, -6.1, 8.55), Vector3(12, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(15, -6.1, 8.55), Vector3(15, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(18, -6.1, 8.55), Vector3(18, -6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-24, 6.1, 9.45), Vector3(18, 6.1, 9.45), 0.2, gry)
	s.cap(Vector3(-24, 6.1, 8.55), Vector3(-24, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-21, 6.1, 8.55), Vector3(-21, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-18, 6.1, 8.55), Vector3(-18, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-15, 6.1, 8.55), Vector3(-15, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-12, 6.1, 8.55), Vector3(-12, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-9, 6.1, 8.55), Vector3(-9, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-6, 6.1, 8.55), Vector3(-6, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(-3, 6.1, 8.55), Vector3(-3, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(0, 6.1, 8.55), Vector3(0, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(3, 6.1, 8.55), Vector3(3, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(6, 6.1, 8.55), Vector3(6, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(9, 6.1, 8.55), Vector3(9, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(12, 6.1, 8.55), Vector3(12, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(15, 6.1, 8.55), Vector3(15, 6.1, 9.45), 0.15, gry)
	s.cap(Vector3(18, 6.1, 8.55), Vector3(18, 6.1, 9.45), 0.15, gry)
	s.box(Vector3(-4, 0, 12), Vector3(7, 4.2, 2.8), deck)
	s.box(Vector3(3.05, 0, 12.4), Vector3(0.12, 3.57, 0.6), gls)
	s.box(Vector3(-4, -4.25, 12.4), Vector3(5.95, 0.12, 0.6), gls)
	s.box(Vector3(-4, 4.25, 12.4), Vector3(5.95, 0.12, 0.6), gls)
	s.box(Vector3(-4, 0, 15.2), Vector3(4.5, 3.2, 1.2), wh)
	s.box(Vector3(0.55, 0, 15.3), Vector3(0.12, 2.72, 0.45), gls)
	s.box(Vector3(-4, -3.25, 15.3), Vector3(3.825, 0.12, 0.45), gls)
	s.box(Vector3(-4, 3.25, 15.3), Vector3(3.825, 0.12, 0.45), gls)
	s.cap(Vector3(-4, 0, 16), Vector3(-4, 0, 26), 0.5, dk)
	s.cyl(Vector3(-4, 0, 24.6), 2.8, 0.5, wh)
	s.ell(Vector3(-4, 0, 27), Vector3(2.6, 2.6, 2.2), wh)
	s.ell(Vector3(-4, 0, 27), Vector3(2.7, 2.7, 0.35), gry)
	s.box(Vector3(0.6, 0, 13.3), Vector3(0.25, 2.6, 1), blk)
	s.box(Vector3(11.2, 0, 9.05), Vector3(5.2, 3.4, 0.35), dk)
	s.box(Vector3(14, -2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(14, -2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.box(Vector3(14, 2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(14, 2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.box(Vector3(11.2, -2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(11.2, -2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.box(Vector3(11.2, 2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(11.2, 2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.box(Vector3(8.4, -2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(8.4, -2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.box(Vector3(8.4, 2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(8.4, 2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.box(Vector3(-19.8, 0, 9.05), Vector3(5.2, 3.4, 0.35), dk)
	s.box(Vector3(-17, -2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(-17, -2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.box(Vector3(-17, 2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(-17, 2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.box(Vector3(-19.8, -2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(-19.8, -2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.box(Vector3(-19.8, 2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(-19.8, 2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.box(Vector3(-22.6, -2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(-22.6, -2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.box(Vector3(-22.6, 2, 10.4), Vector3(1.1, 1.1, 0.5), dk)
	s.box(Vector3(-22.6, 2, 10.95), Vector3(0.85, 0.85, 0.1), gry)
	s.cap(Vector3(-12, -5, 11), Vector3(-9.5, -5, 15.5), 1.1, wh)
	s.ell(Vector3(-9.5, -5, 16), Vector3(0.9, 0.9, 0.9), red)
	s.cap(Vector3(-12, -5, 11), Vector3(-12, -5, 8.55), 0.5, dk)
	s.cap(Vector3(-15.2, -5, 11), Vector3(-12.7, -5, 15.5), 1.1, wh)
	s.ell(Vector3(-12.7, -5, 16), Vector3(0.9, 0.9, 0.9), red)
	s.cap(Vector3(-15.2, -5, 11), Vector3(-15.2, -5, 8.55), 0.5, dk)
	s.cap(Vector3(-12, 5, 11), Vector3(-9.5, 5, 15.5), 1.1, wh)
	s.ell(Vector3(-9.5, 5, 16), Vector3(0.9, 0.9, 0.9), red)
	s.cap(Vector3(-12, 5, 11), Vector3(-12, 5, 8.55), 0.5, dk)
	s.cap(Vector3(-15.2, 5, 11), Vector3(-12.7, 5, 15.5), 1.1, wh)
	s.ell(Vector3(-12.7, 5, 16), Vector3(0.9, 0.9, 0.9), red)
	s.cap(Vector3(-15.2, 5, 11), Vector3(-15.2, 5, 8.55), 0.5, dk)
	s.cyl(Vector3(-10, 0, 12), 1.8, 2.2, dk)
	s.cyl(Vector3(-10, 0, 14.3), 1.95, 0.25, gry)
	s.ell(Vector3(-10, 0, 14.6), Vector3(1.3, 1.3, 0.3), blk)
	s.cyl(Vector3(19.5, 0, 9.55), 2.88, 1.26, deck)
	s.ell(Vector3(20.04, 0, 10.9), Vector3(2.16, 1.98, 0.9), gry)
	s.cap(Vector3(19.5, 0, 10.81), Vector3(26.7, 0, 10.9), 0.72, dk)
	s.ell(Vector3(26.7, 0, 10.9), Vector3(0.45, 0.81, 0.81), blk)
	s.cyl(Vector3(6, 5.2, 9.15), 1.2, 0.6, dk)
	s.ell(Vector3(6, 5.2, 10.55), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(6, 5.2, 10.85), Vector3(8.2, 5.2, 11.05), 0.35, dk)
	s.cyl(Vector3(6, -5.2, 9.15), 1.2, 0.6, dk)
	s.ell(Vector3(6, -5.2, 10.55), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(6, -5.2, 10.85), Vector3(8.2, -5.2, 11.05), 0.35, dk)
	s.cyl(Vector3(-22, 0, 9.15), 1.2, 0.6, dk)
	s.ell(Vector3(-22, 0, 10.55), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(-22, 0, 10.85), Vector3(-19.8, 0, 11.05), 0.35, dk)
	s.ell(Vector3(2, -5.7, 9.45), Vector3(2.2, 0.9, 0.75), ora)
	s.ell(Vector3(2, -5.7, 10), Vector3(1.6, 0.6, 0.3), wh)
	s.ell(Vector3(2, 5.7, 9.45), Vector3(2.2, 0.9, 0.75), ora)
	s.ell(Vector3(2, 5.7, 10), Vector3(1.6, 0.6, 0.3), wh)
	s.box(Vector3(-4, 0, 19), Vector3(0.4, 1.6, 0.4), red)
	s.cap(Vector3(-4, 0, 27.4), Vector3(-4, 0, 30.4), 0.18, dk)
	s.box(Vector3(-4.9, 0, 29.8), Vector3(0.9, 0.08, 0.55), red)
	return s.render(208, 128, 84.0)

static func _carrier(_f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	s.us = 2.0
	var blk := _P(_SH_BLK)
	var deck := _P(_SH_DECK)
	var dk := _P(_SH_DK)
	var gls := _P(_SH_GLS)
	var gry := _P(_SH_GRY)
	var hull := _P(_SH_HULL)
	var lt := _P(_SH_LT)
	var ora := _P(_SH_ORA)
	var red := _P(_SH_RED)
	var wh := _P(_SH_WH)
	s.ell(Vector3(0, 0, 4.2), Vector3(50, 15, 4.8), red)
	s.ell(Vector3(0, 0, 6), Vector3(50, 15, 6), hull)
	s.ell(Vector3(36, 0, 6.4), Vector3(20, 12.75, 5.4), hull)
	s.box(Vector3(-5, 0, 9.3), Vector3(39, 12.3, 0.8), deck)
	s.ell(Vector3(0, -14.55, 6.3), Vector3(45, 0.25, 0.3), dk)
	s.box(Vector3(27.5, -12, 6.9), Vector3(3.5, 0.18, 0.84), wh)
	s.box(Vector3(31, -11.7, 6.9), Vector3(2, 0.18, 0.84), wh)
	s.ell(Vector3(39, -7.2, 7.2), Vector3(0.8, 0.5, 0.7), dk)
	s.ell(Vector3(0, 14.55, 6.3), Vector3(45, 0.25, 0.3), dk)
	s.box(Vector3(27.5, 12, 6.9), Vector3(3.5, 0.18, 0.84), wh)
	s.box(Vector3(31, 11.7, 6.9), Vector3(2, 0.18, 0.84), wh)
	s.ell(Vector3(39, 7.2, 7.2), Vector3(0.8, 0.5, 0.7), dk)
	s.box(Vector3(-2, 0, 11.5), Vector3(44, 15.75, 0.9), deck)
	s.box(Vector3(-40, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(-34, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(-28, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(-22, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(-16, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(-10, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(-4, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(2, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(8, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(14, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(20, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(26, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(32, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(38, 0, 12.5), Vector3(2, 0.3, 0.1), wh)
	s.box(Vector3(0, 3.5, 12.5), Vector3(30, 0.4, 0.1), lt)
	s.box(Vector3(-6, 3.5, 12.5), Vector3(26, 0.25, 0.1), wh)
	s.box(Vector3(-2, -14.2, 12.5), Vector3(42, 0.3, 0.1), lt)
	s.ell(Vector3(-42, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-37, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-32, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-27, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-22, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-17, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-12, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-7, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-2, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(3, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(8, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(13, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(18, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(23, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(28, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(33, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(38, -14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.box(Vector3(-2, 14.2, 12.5), Vector3(42, 0.3, 0.1), lt)
	s.ell(Vector3(-42, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-37, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-32, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-27, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-22, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-17, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-12, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-7, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(-2, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(3, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(8, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(13, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(18, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(23, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(28, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(33, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.ell(Vector3(38, 14.8, 12.7), Vector3(0.35, 0.35, 0.3), lt)
	s.box(Vector3(26, -4, 12.5), Vector3(14, 0.3, 0.1), gry)
	s.box(Vector3(26, -8, 12.5), Vector3(14, 0.3, 0.1), gry)
	s.box(Vector3(-28, 3.5, 12.5), Vector3(0.25, 3.8, 0.1), dk)
	s.box(Vector3(-24, 3.5, 12.5), Vector3(0.25, 3.8, 0.1), dk)
	s.box(Vector3(-20, 3.5, 12.5), Vector3(0.25, 3.8, 0.1), dk)
	s.box(Vector3(-10, 11.7, 16), Vector3(6, 3.4, 4.5), deck)
	s.box(Vector3(-3.95, 11.7, 17.2), Vector3(0.12, 2.89, 0.8), gls)
	s.box(Vector3(-10, 8.25, 17.2), Vector3(5.1, 0.12, 0.8), gls)
	s.box(Vector3(-10, 15.15, 17.2), Vector3(5.1, 0.12, 0.8), gls)
	s.box(Vector3(-10, 11.7, 21), Vector3(4, 2.6, 1.6), wh)
	s.box(Vector3(-5.95, 11.7, 21.2), Vector3(0.12, 2.21, 0.6), gls)
	s.box(Vector3(-10, 9.05, 21.2), Vector3(3.4, 0.12, 0.6), gls)
	s.box(Vector3(-10, 14.35, 21.2), Vector3(3.4, 0.12, 0.6), gls)
	s.box(Vector3(-10, 11.7, 23.6), Vector3(2.4, 1.8, 1), deck)
	s.box(Vector3(-7.5, 11.7, 19), Vector3(0.3, 2.2, 0.8), dk)
	s.cap(Vector3(-10, 11.7, 22), Vector3(-10, 11.7, 33), 0.5, dk)
	s.ell(Vector3(-10, 11.7, 29), Vector3(0.6, 4, 0.5), dk)
	s.cap(Vector3(-10, 11.7, 30.5), Vector3(-10, 11.7, 33.5), 0.4, dk)
	s.ell(Vector3(-10, 11.7, 33.9), Vector3(1.2, 4.6, 0.35), dk)
	s.ell(Vector3(-10, 11.7, 33.9), Vector3(0.8, 3.22, 0.4), gry)
	s.cap(Vector3(-10, 11.7, 34), Vector3(-10, 11.7, 37), 0.18, dk)
	s.box(Vector3(-10.9, 11.7, 36.4), Vector3(0.9, 0.08, 0.55), red)
	s.cap(Vector3(-4.5, 11.7, 19), Vector3(-4.5, 11.7, 28), 0.4, dk)
	s.box(Vector3(-4.5, 11.7, 28.5), Vector3(0.4, 2.6, 1.5), dk)
	s.cyl(Vector3(-18, 11.7, 16), 2.2, 3.2, dk)
	s.cyl(Vector3(-18, 11.7, 19.4), 2.4, 0.3, gry)
	s.ell(Vector3(-18, 11.7, 19.8), Vector3(1.8, 1.8, 0.3), blk)
	s.ell(Vector3(18, -6, 13.6), Vector3(3.6, 0.85, 0.8), wh)
	s.ell(Vector3(20.6, -6, 13.7), Vector3(1.4, 0.6, 0.5), gry)
	s.ell(Vector3(18.6, -6, 14.15), Vector3(1, 0.5, 0.4), gls)
	s.ell(Vector3(17, -6, 13.5), Vector3(1.5, 3.3, 0.3), wh)
	s.ell(Vector3(14.8, -6, 13.7), Vector3(0.9, 1.5, 0.25), wh)
	s.ell(Vector3(15, -6, 14.3), Vector3(0.8, 0.2, 0.9), wh)
	s.ell(Vector3(26, 3, 13.6), Vector3(3.6, 0.85, 0.8), wh)
	s.ell(Vector3(28.6, 3, 13.7), Vector3(1.4, 0.6, 0.5), gry)
	s.ell(Vector3(26.6, 3, 14.15), Vector3(1, 0.5, 0.4), gls)
	s.ell(Vector3(25, 3, 13.5), Vector3(1.5, 3.3, 0.3), wh)
	s.ell(Vector3(22.8, 3, 13.7), Vector3(0.9, 1.5, 0.25), wh)
	s.ell(Vector3(23, 3, 14.3), Vector3(0.8, 0.2, 0.9), wh)
	s.ell(Vector3(-24, -5, 13.6), Vector3(3.6, 0.85, 0.8), wh)
	s.ell(Vector3(-21.4, -5, 13.7), Vector3(1.4, 0.6, 0.5), gry)
	s.ell(Vector3(-23.4, -5, 14.15), Vector3(1, 0.5, 0.4), gls)
	s.ell(Vector3(-25, -5, 13.5), Vector3(1.5, 1.2, 0.3), wh)
	s.ell(Vector3(-27.2, -5, 13.7), Vector3(0.9, 1.5, 0.25), wh)
	s.ell(Vector3(-27, -5, 14.3), Vector3(0.8, 0.2, 0.9), wh)
	s.ell(Vector3(-32, 5, 13.6), Vector3(3.6, 0.85, 0.8), wh)
	s.ell(Vector3(-29.4, 5, 13.7), Vector3(1.4, 0.6, 0.5), gry)
	s.ell(Vector3(-31.4, 5, 14.15), Vector3(1, 0.5, 0.4), gls)
	s.ell(Vector3(-33, 5, 13.5), Vector3(1.5, 3.3, 0.3), wh)
	s.ell(Vector3(-35.2, 5, 13.7), Vector3(0.9, 1.5, 0.25), wh)
	s.ell(Vector3(-35, 5, 14.3), Vector3(0.8, 0.2, 0.9), wh)
	s.ell(Vector3(8, -9, 13.6), Vector3(3.6, 0.85, 0.8), wh)
	s.ell(Vector3(10.6, -9, 13.7), Vector3(1.4, 0.6, 0.5), gry)
	s.ell(Vector3(8.6, -9, 14.15), Vector3(1, 0.5, 0.4), gls)
	s.ell(Vector3(7, -9, 13.5), Vector3(1.5, 1.2, 0.3), wh)
	s.ell(Vector3(4.8, -9, 13.7), Vector3(0.9, 1.5, 0.25), wh)
	s.ell(Vector3(5, -9, 14.3), Vector3(0.8, 0.2, 0.9), wh)
	s.ell(Vector3(-6, -10, 13.6), Vector3(3.6, 0.85, 0.8), wh)
	s.ell(Vector3(-3.4, -10, 13.7), Vector3(1.4, 0.6, 0.5), gry)
	s.ell(Vector3(-5.4, -10, 14.15), Vector3(1, 0.5, 0.4), gls)
	s.ell(Vector3(-7, -10, 13.5), Vector3(1.5, 3.3, 0.3), wh)
	s.ell(Vector3(-9.2, -10, 13.7), Vector3(0.9, 1.5, 0.25), wh)
	s.ell(Vector3(-9, -10, 14.3), Vector3(0.8, 0.2, 0.9), wh)
	s.ell(Vector3(34, -11, 13.6), Vector3(3.6, 0.85, 0.8), wh)
	s.ell(Vector3(36.6, -11, 13.7), Vector3(1.4, 0.6, 0.5), gry)
	s.ell(Vector3(34.6, -11, 14.15), Vector3(1, 0.5, 0.4), gls)
	s.ell(Vector3(33, -11, 13.5), Vector3(1.5, 1.2, 0.3), wh)
	s.ell(Vector3(30.8, -11, 13.7), Vector3(0.9, 1.5, 0.25), wh)
	s.ell(Vector3(31, -11, 14.3), Vector3(0.8, 0.2, 0.9), wh)
	s.box(Vector3(14, -11, 12.9), Vector3(1.3, 0.8, 0.5), ora)
	s.box(Vector3(-16, -3, 12.9), Vector3(1.1, 0.7, 0.45), ora)
	s.box(Vector3(30, -8.25, 12.4), Vector3(2.6, 2.6, 0.1), dk)
	s.box(Vector3(30, -8.25, 12.45), Vector3(2.2, 2.2, 0.08), gry)
	s.box(Vector3(-30, -8.25, 12.4), Vector3(2.6, 2.6, 0.1), dk)
	s.box(Vector3(-30, -8.25, 12.45), Vector3(2.2, 2.2, 0.08), gry)
	s.ell(Vector3(36, -16.2, 11), Vector3(3, 1.8, 0.8), deck)
	s.cyl(Vector3(36, -16.2, 11.3), 1.2, 0.6, dk)
	s.ell(Vector3(36, -16.2, 12.7), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(36, -16.2, 13), Vector3(38.2, -16.2, 13.2), 0.35, dk)
	s.ell(Vector3(36, 16.2, 11), Vector3(3, 1.8, 0.8), deck)
	s.cyl(Vector3(36, 16.2, 11.3), 1.2, 0.6, dk)
	s.ell(Vector3(36, 16.2, 12.7), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(36, 16.2, 13), Vector3(38.2, 16.2, 13.2), 0.35, dk)
	s.ell(Vector3(-36, -16.2, 11), Vector3(3, 1.8, 0.8), deck)
	s.cyl(Vector3(-36, -16.2, 11.3), 1.2, 0.6, dk)
	s.ell(Vector3(-36, -16.2, 12.7), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(-36, -16.2, 13), Vector3(-33.8, -16.2, 13.2), 0.35, dk)
	s.ell(Vector3(-36, 16.2, 11), Vector3(3, 1.8, 0.8), deck)
	s.cyl(Vector3(-36, 16.2, 11.3), 1.2, 0.6, dk)
	s.ell(Vector3(-36, 16.2, 12.7), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(-36, 16.2, 13), Vector3(-33.8, 16.2, 13.2), 0.35, dk)
	s.ell(Vector3(0, -16.2, 11), Vector3(3, 1.8, 0.8), deck)
	s.cyl(Vector3(0, -16.2, 11.3), 1.2, 0.6, dk)
	s.ell(Vector3(0, -16.2, 12.7), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(0, -16.2, 13), Vector3(2.2, -16.2, 13.2), 0.35, dk)
	s.ell(Vector3(0, 16.2, 11), Vector3(3, 1.8, 0.8), deck)
	s.cyl(Vector3(0, 16.2, 11.3), 1.2, 0.6, dk)
	s.ell(Vector3(0, 16.2, 12.7), Vector3(1.3, 1.3, 1.4), wh)
	s.cap(Vector3(0, 16.2, 13), Vector3(2.2, 16.2, 13.2), 0.35, dk)
	s.ell(Vector3(-14, -15.6, 10.2), Vector3(2.4, 0.9, 0.7), ora)
	s.ell(Vector3(-14, 15.6, 10.2), Vector3(2.4, 0.9, 0.7), ora)
	s.ell(Vector3(16, -15.6, 10.2), Vector3(2.4, 0.9, 0.7), ora)
	s.ell(Vector3(16, 15.6, 10.2), Vector3(2.4, 0.9, 0.7), ora)
	s.cap(Vector3(-2, -14.8, 12.5), Vector3(-2, -14.8, 16.5), 0.4, dk)
	s.cap(Vector3(-2, -14.8, 16.5), Vector3(2.5, -14.8, 17), 0.4, dk)
	return s.render(352, 192, 104.0)

# ---- Deep Ocean jets (seen from above, 16 headings) ----
const _JGR := ["3a424a", "586470", "7c8a98", "a4b2c0", "d0dae4"]
const _JGD := ["20262c", "323a42", "46505a", "5c6874"]
const _JCAN := ["183050", "2c5890", "5a9ad0", "b8e0ff"]
const _JFLM := ["c85a10", "ff9a30", "ffe080"]
const _JOL := ["2a3418", "3e4c24", "566a34", "74904a"]
const _JOLD := ["181e0e", "242c14", "323c1c", "424e26"]
const _JBK := ["06060a", "0e0e16", "181824", "26263a"]

static func _jsweep(s: Scene3, x: float, y: float, z: float, l: float, w: float, ang: float, pal: Array, tilt: float = 0.0) -> void:
	s.ell(Vector3(x, y, z), Vector3(l, w, 0.8), pal, _rz(ang) * _rx(tilt))

static func _phantom(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var gr := _P(_JGR)
	var gd := _P(_JGD)
	s.ell(Vector3(0, 0, 12), Vector3(15, 2.6, 2.4), gr)
	s.ell(Vector3(15, 0, 12), Vector3(5, 1.8, 1.6), gr)
	s.cone(Vector3(19.5, 0, 12), 1.2, 3, gd)
	for sg: float in [-1.0, 1.0]:
		_jsweep(s, -3, sg * 8.5, 12.2, 10, 3.0, -sg * 0.75, gr)
		_jsweep(s, -8, sg * 15.5, 13.2, 4, 1.6, -sg * 0.75, gd, -sg * 0.5)
		_jsweep(s, -12, sg * 4, 12.5, 5.5, 2.0, -sg * 0.3, gr)
		s.ell(Vector3(2, sg * 3.4, 11.5), Vector3(5, 1.6, 1.4), gd)
		s.cap(Vector3(-4, sg * 7, 10.4), Vector3(2, sg * 7, 10.4), 0.8, gd)
	s.cap(Vector3(-12, 0, 13.5), Vector3(-14, 0, 19), 1.0, gr)
	s.ell(Vector3(6, 0, 13.6), Vector3(3.2, 1.4, 1.1), _P(_JCAN))
	s.ell(Vector3(-15.6, 0, 12), Vector3(1.8 + float(f % 2) * 0.8, 1.6, 1.4), _P(_JFLM))
	return s.render(64, 64, 30.0)

static func _falcon(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var gr := _P(_JGR)
	var gd := _P(_JGD)
	s.ell(Vector3(0, 0, 12), Vector3(13, 2.4, 2.4), gr)
	s.ell(Vector3(13, 0, 12), Vector3(5, 1.7, 1.5), gr)
	s.cone(Vector3(17.5, 0, 12), 1.0, 3, gd)
	for sg: float in [-1.0, 1.0]:
		_jsweep(s, -4, sg * 7, 12.2, 8, 3.4, -sg * 0.45, gr)
		_jsweep(s, -11, sg * 3.8, 12.4, 4.2, 1.8, -sg * 0.25, gr)
		s.cap(Vector3(-4, sg * 13.5, 12.2), Vector3(-2, sg * 13.5, 12.2), 0.5, gd)
	s.ell(Vector3(-1, 0, 10.4), Vector3(6, 2.4, 1.6), gd)
	s.cap(Vector3(-10, 0, 13), Vector3(-12.5, 0, 18.5), 0.9, gr)
	s.ell(Vector3(4.5, 0, 13.8), Vector3(4.2, 1.5, 1.4), _P(_JCAN))
	s.ell(Vector3(-14, 0, 12), Vector3(2.0 + float(f % 2) * 0.9, 1.5, 1.4), _P(_JFLM))
	return s.render(60, 60, 30.0)

static func _warthog(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var ol := _P(_JOL)
	var old := _P(_JOLD)
	var gd := _P(_JGD)
	s.ell(Vector3(0, 0, 12), Vector3(11, 3.0, 3.0), ol)
	s.ell(Vector3(11, 0, 12), Vector3(4.5, 2.4, 2.2), old)
	s.cap(Vector3(14, 0, 11), Vector3(20, 0, 11), 0.9, gd)
	for sg: float in [-1.0, 1.0]:
		s.ell(Vector3(-2, sg * 10, 12.2), Vector3(4.4, 10, 0.9), ol)
		s.ell(Vector3(-3, sg * 10, 12.6), Vector3(3, 4, 0.5), old)
		s.cap(Vector3(-7, sg * 3.6, 13.2), Vector3(-12, sg * 3.6, 13.2), 1.8, gd)
		s.cap(Vector3(-12, sg * 3.6, 13.2), Vector3(-14, sg * 3.6, 13.2), 1.4, _P(["50301a", "90501a"]))
		s.cap(Vector3(-10, sg * 5, 13), Vector3(-12, sg * 5, 20), 0.9, ol)
		s.cap(Vector3(-4, sg * 8, 10.6), Vector3(2, sg * 8, 10.6), 0.8, gd)
	s.ell(Vector3(-12, 0, 14), Vector3(2.4, 10, 0.6), ol)
	s.ell(Vector3(5, 0, 14), Vector3(3.4, 1.6, 1.4), _P(_JCAN))
	return s.render(72, 64, 30.0)

static func _stealth(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var bk := _P(_JBK)
	var las := _P(["ff3040", "ffc0c8"])
	s.ell(Vector3(2, 0, 12), Vector3(12, 4, 2.2), bk)
	for sg: float in [-1.0, 1.0]:
		s.ell(Vector3(-4, sg * 11, 12), Vector3(9, 3.4, 1.0), bk, _rz(-sg * 0.5))
		s.ell(Vector3(-9, sg * 19, 12), Vector3(6, 2.6, 0.8), bk, _rz(-sg * 0.45))
		s.ell(Vector3(-13, sg * 6, 11.8), Vector3(4, 3, 0.7), bk, _rz(-sg * 0.2))
		s.ell(Vector3(7, sg * 5, 12.8), Vector3(3, 1.0, 0.5), bk.slice(2))
		s.cap(Vector3(6, sg * 9, 11.2), Vector3(12, sg * 9, 11.2), 0.9, _P(["a01020", "ff3040", "ffc0c8"]))
		s.ell(Vector3(12.6, sg * 9, 11.2), Vector3(1.0, 1.0, 1.0), las)
	s.ell(Vector3(5, 0, 13.8), Vector3(3.6, 1.4, 1.2), bk.slice(1))
	s.ell(Vector3(-12, 0, 12), Vector3(2.2, 2.2, 1.2), _P(["3a1010", "a02020"]))
	return s.render(76, 60, 30.0)

const _FK := 1.55

static func _fv(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z) * _FK

static func _fallen(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var fl: float = [0.0, 0.5, 0.7, 0.3][f % 4]
	var sw: float = [0.0, 2.0, 0.0, -2.0][f % 4]
	var gold := _P(["a06818", "e8a830", "ffe070", "fffbd0"])
	var steel := _P(["30343e", "50566a", "7c84a0", "b4bcd4"])
	var cloak := _P(["34343c", "585864", "8c8c9c", "c4c4d2"])
	var hood := _P(["14141a", "24242e", "36363f"])
	var rune := _P(["a07818", "ffd050", "fffbd8"])
	var blade := _P(["70788e", "b8c0d8", "f0f4ff", "ffffff"])
	# wings: root between the shoulder blades, graded from a dark base to a glowing white-gold tip
	var wbase := _P(["2e2a26", "4a4338", "6a604c"])
	var wmid := _P(["7c7258", "a89c78", "d0c498"])
	var wtip := _P(["e8d490", "fff0b8", "fffce8"])
	var wtipb := _P(["fff6d0", "ffffff", "ffffff"])
	var segs := [[0.30, 0, 0.22], [0.62, 1, 0.2], [0.92, 2, 0.16]]
	for sg: float in [-1.0, 1.0]:
		for i in 5:
			var th := sg * (1.35 + float(i) * 0.26)
			var ln := 27.0 - float(i) * 1.6
			var zr := 21.0 + fl * float(i) * 0.4
			var flash := (i + f) % 4 == 0
			for sgm: Array in segs:
				var fr: float = sgm[0]
				var kind: int = sgm[1]
				var pal: Array = wbase.slice(i % 2, i % 2 + 2)
				var wy := 2.7
				if kind == 1:
					pal = wmid.slice(i % 2, i % 2 + 2)
				elif kind == 2:
					pal = wtipb if flash else wtip
					wy = 2.0
				var c := Vector3(-3.0 + cos(th) * ln * fr, sin(th) * ln * fr, zr + 0.4 * fr)
				s.ell(c * _FK, Vector3(ln * float(sgm[2]) + 1.6, wy, 0.9) * _FK, pal, _rz(th) * _rx(-sg * (0.1 + fl * 0.4)))
			var c2 := Vector3(-3.0 + cos(th) * ln * 1.02, sin(th) * ln * 1.02, zr + 0.5)
			s.ell(c2 * _FK, Vector3(2.4, 1.5, 0.8) * _FK, gold.slice(2) if flash else gold.slice(1, 3), _rz(th))
		for q in 3:                                     # coverts hugging the shoulder
			var th2 := sg * (1.1 + float(q) * 0.45)
			s.ell(Vector3(-3.0 + cos(th2) * 4.0, sin(th2) * 4.0 + sg * 2.0, 21.5) * _FK, Vector3(4.2, 2.4, 1.1) * _FK, wmid.slice(1), _rz(th2))
	s.cap(_fv(sw, -2.4, 1.5), _fv(sw * 0.5, -2.4, 9), 1.9 * _FK, steel)
	s.cap(_fv(-sw, 2.4, 1.5), _fv(-sw * 0.5, 2.4, 9), 1.9 * _FK, steel)
	var dk := _P(["1a1c24", "2c3040", "444a60", "687090"])
	var mask := _P(["5c6074", "98a0b8", "d0d8ec", "ffffff"])
	s.cone(_fv(-1, 0, 11), 8.0 * _FK, 7.5 * _FK, cloak)
	for k in 7:                                         # torn hem
		var a := float(k) * TAU / 7.0 + 0.3
		s.cap(_fv(7.0 * cos(a) - 1.0, 7.0 * sin(a), 6), _fv(8.6 * cos(a) - 1.0, 8.6 * sin(a), 1.5), 0.9 * _FK, cloak.slice(0, 3))
	var plates := [[14.5, 4.2, 6.0], [17.0, 4.6, 6.6], [19.5, 4.4, 6.2]]         # segmented, ribbed chest
	for j in 3:
		var pl: Array = plates[j]
		s.ell(_fv(0, 0, float(pl[0])), _fv(float(pl[1]), float(pl[2]), 2.3), steel if j % 2 == 0 else dk)
		s.ell(_fv(1.6, 0, float(pl[0]) + 1.0), _fv(1.6, 3.6, 0.7), gold.slice(0, 3))
	s.cap(_fv(-3, -5, 19.5), _fv(-3, 5, 19.5), 1.4 * _FK, dk)
	s.ell(_fv(0.2, 0, 22.3), _fv(3.6, 5.6, 1.5), steel)                            # gorget
	s.ell(_fv(0.5, 0, 13), _fv(3.2, 5.2, 1.0), gold.slice(0, 3))                   # belt
	s.ell(_fv(2.6, 0, 12.6), _fv(1.0, 1.5, 0.8), gold)
	var yys := [-3.6, -1.2, 1.2, 3.6]
	for k in 4:                                         # tattered tassets
		var yy: float = yys[k]
		s.cap(_fv(3.4, yy, 12.5), _fv(4.6, yy * 1.15, 6.5), 1.1 * _FK, cloak.slice(0, 3) if k % 2 == 1 else dk.slice(0, 3))
	var pz := [[20.0, 1.0], [21.8, 0.8], [23.4, 0.6]]
	for sy: float in [-1.0, 1.0]:
		for q in 3:                                     # layered pauldrons
			var zz: float = pz[q][0]
			var sc: float = pz[q][1]
			s.ell(_fv(0, sy * 7.8, zz), _fv(4.2 * sc, 3.6 * sc, 1.5), steel if q % 2 == 0 else dk)
			s.ell(_fv(0.4, sy * 7.8, zz + 0.9), _fv(3.2 * sc, 2.8 * sc, 0.5), gold.slice(0, 3))
		s.cap(_fv(0, sy * 8.6, 22.5), _fv(-1.5, sy * 11.5, 27.5), 0.9 * _FK, steel)     # pauldron spike
		s.cap(_fv(0, sy * 7.4, 18.8), _fv(8, sy * 1.8, 15.4), 1.7 * _FK, steel)         # arms reaching the hilt
		s.ell(_fv(5.4, sy * 3.8, 16.6), _fv(2.6, 1.5, 1.5), gold.slice(0, 3))           # bracers
		s.ell(_fv(8.4, sy * 1.4, 15.2), _fv(1.5, 1.5, 1.5), dk)                         # gauntlets
		var lg := sw if sy < 0.0 else -sw
		s.cap(_fv(lg, sy * 2.4, 6), _fv(lg * 0.5, sy * 2.4, 9.5), 2.0 * _FK, dk)         # greaves
	s.cone(_fv(-2.6, 0, 27.5), 4.6 * _FK, 5.0 * _FK, cloak)                          # cloak behind the head
	s.ell(_fv(0.6, 0, 26.5), _fv(4.4, 4.2, 4.4), hood)
	s.cone(_fv(-1.2, 0, 31.5), 3.4 * _FK, 3.4 * _FK, hood)                           # pointed hood peak
	s.ell(_fv(3.4, 0, 26.4), _fv(1.3, 2.7, 3.4), mask)                               # silver mask plate
	s.ell(_fv(4.5, 0, 25.0), _fv(0.7, 1.1, 1.3), _P(["3a3e50", "5c6074"]))
	s.ell(_fv(4.5, -1.2, 27.0), _fv(0.4, 0.9, 0.28), gold.slice(1))
	s.ell(_fv(4.5, 1.2, 27.0), _fv(0.4, 0.9, 0.28), gold.slice(1))
	# divine greatsword: gold hilt, flared crossguard with a blue gem, long bright blade, animated light
	var zs := 14.8
	var hg := _P(["8a5c14", "d49a2c", "ffd060", "fff2b0"])
	var bl := _P(["6c7894", "a4b2d0", "d4e0f4", "f4f8ff"])
	var gl := _P(["fff0a0", "fffbd8", "ffffff"])
	var gem := _P(["2038a0", "5a88ff", "c8e0ff"])
	var white := _P(["ffffff"])
	var pulse: float = [0.0, 0.5, 1.0, 0.5][f % 4]
	s.ell(_fv(5.2, 0, zs), _fv(1.5, 1.5, 1.5), hg)
	s.ell(_fv(5.0, 0, zs + 0.9), _fv(0.8, 0.8, 0.6), gem)
	s.cap(_fv(6.2, 0, zs), _fv(11.0, 0, zs), 0.9 * _FK, hg)
	s.cap(_fv(11.4, -6.8, zs), _fv(11.4, 6.8, zs), 0.9 * _FK, hg)
	for sy: float in [-1.0, 1.0]:
		s.cap(_fv(11.4, sy * 6.8, zs), _fv(13.6, sy * 8.0, zs), 0.8 * _FK, hg)
		s.ell(_fv(14.0, sy * 8.1, zs), _fv(1.2, 1.4, 0.8), hg)
		s.cap(_fv(13, sy * (3.6 + 0.5 * pulse), zs - 0.8), _fv(35, sy * (2.0 + 0.3 * pulse), zs - 0.8), (0.9 + 0.4 * pulse) * _FK, _P(["e0b838", "ffe880", "fff6c0"]))   # pulsing golden aura
	s.ell(_fv(11.6, 0, zs + 0.8), _fv(1.0, 1.0, 0.8), gem)
	s.cap(_fv(12.8, 0, zs), _fv(30, 0, zs), 2.2 * _FK, bl)
	s.cap(_fv(30, 0, zs), _fv(36.5, 0, zs), 1.3 * _FK, bl)
	s.cap(_fv(14, 0, zs + 0.9), _fv(32, 0, zs + 0.9), 0.6 * _FK, _P(["8090b0", "b0c0e0"]))
	s.cap(_fv(13, -1.8, zs + 0.4), _fv(34, -0.6, zs + 0.4), 0.35 * _FK, gl)
	s.cap(_fv(13, 1.8, zs + 0.4), _fv(34, 0.6, zs + 0.4), 0.35 * _FK, gl)
	var sx := 15.0 + float(f % 4) * 5.5                  # a flash of light sliding along the blade
	s.ell(_fv(sx, 0, zs + 1.2), _fv(3.0, 1.5, 1.0), gl)
	s.ell(_fv(sx, 0, zs + 1.5), _fv(1.4, 0.9, 0.8), white)
	var sparks := [[33.0, 2.8, 3.0], [26.0, -3.0, 4.0], [19.0, 3.2, 2.0], [36.0, -2.2, 5.0]]      # twinkling sparks
	for j in 4:
		if (j + f) % 4 < 2:
			var sp: Array = sparks[j]
			s.ell(_fv(float(sp[0]), float(sp[1]), zs + float(sp[2])), _fv(1.0, 1.0, 1.0), white)
	return s.render(150, 140, 82.0)

static func _wisp(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var b := float(f % 2) * 1.0
	var glow := _P(["a8c8ff", "d8e8ff", "ffffff"])
	var tail := _P(["8098d8", "b0c8f8", "e0ecff"])
	s.ell(Vector3(2, 0, 13.0 + b), Vector3(4.2, 4.2, 4.2), glow)
	s.ell(Vector3(-4, 0, 12.5 + b), Vector3(3.2, 3.0, 3.0), tail)
	s.ell(Vector3(-8.5, 0.8, 12.0 + b), Vector3(2.4, 2.2, 2.2), tail)
	s.ell(Vector3(-12, -0.6, 11.6 + b), Vector3(1.6, 1.5, 1.5), tail)
	s.ell(Vector3(4.2, -1.3, 14.0 + b), Vector3(0.8, 0.8, 0.8), _P(["303050"]))
	s.ell(Vector3(4.2, 1.3, 14.0 + b), Vector3(0.8, 0.8, 0.8), _P(["303050"]))
	return s.render(40, 40, 22.0)

static func _fighter(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var wh := _P(_SH_WH)
	s.ell(Vector3(0, 0, 12), Vector3(8, 1.6, 1.6), wh)
	s.ell(Vector3(-2, 0, 12), Vector3(4, 9, 0.8), wh)
	for sg: float in [-1.0, 1.0]:
		s.ell(Vector3(-6, sg * 3.5, 12), Vector3(2.4, 1.0, 0.7), wh.slice(0, 3))
	s.ell(Vector3(3, 0, 13.3), Vector3(2.0, 0.8, 0.7), _P(["2a4a6a", "4a7aa0"]))
	s.ell(Vector3(-8, 0, 12), Vector3(1.0, 0.6, 0.6), _P(_SH_LT))
	return s.render(36, 36, 22.0)
