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
const DIRECTIONAL := ["soldier", "ally", "medic", "bee", "golem", "demon", "tank", "heavytank", "apoctank", "sinner", "earthworm", "mech", "aegis", "worm", "hunter", "drone", "starship", "corvette", "b_hell", "b_garden", "b_mud", "b_titan", "b_void"]
const DIRS := 16
# frames, and how many frames per unit of the mob's walk phase (see Enemy._walk)
const INFO := {
	"soldier": [4, 0.64], "ally": [4, 0.64], "medic": [4, 0.64], "bee": [2, 3.0],
	"tank": [3, 0.6], "heavytank": [3, 0.6], "apoctank": [3, 0.6], "sinner": [4, 0.5], "earthworm": [4, 0.22], "mech": [2, 0.6], "aegis": [1, 1.0], "worm": [4, 0.22],
	"golem": [4, 0.95], "demon": [4, 0.45], "hunter": [2, 1.5], "drone": [2, 1.5],
	"starship": [2, 1.5], "corvette": [2, 1.5], "void": [2, 0.25],
	"b_garden": [1, 1.0], "b_leaves": [10, 1.0], "b_mud": [1, 1.0], "b_titan": [1, 1.0],
	"b_void": [2, 1.0], "b_hell": [4, 1.0],
	"castle0": [1, 1.0], "castle1": [1, 1.0], "castle2": [1, 1.0], "castle3": [1, 1.0], "castle4": [1, 1.0],
}
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
		"worm", "earthworm", "sinner", "golem", "demon", "hunter", "void", "bee", "medic", "aegis":
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
	return "b_hell"

# infantry is drawn smaller than the vehicles so tanks and mechs look big next to it
static func scale_for(key: String) -> float:
	match key:
		"soldier", "ally", "medic", "sinner":
			return 0.62
		"bee":
			return 0.7
		"golem":
			return 0.9
		"demon":
			return 0.85
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
static var _thread: Thread = null
static var _running: bool = false
static var _jobs: Array = []        # [key, dir]
static var _done: Array = []        # [key, dir, result]
static var _pending: Dictionary = {}
static var _drain_frame: int = -1

static func _ck(key: String, dir: int) -> String:
	return "%s#%d" % [key, dir] if DIRECTIONAL.has(key) else key

# Paints every frame of one kind/heading into Images. Safe to run on a thread.
static func _build(key: String, dir: int) -> Dictionary:
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

static func _worker() -> void:
	while true:
		_mutex.lock()
		if _jobs.is_empty():
			_running = false
			_mutex.unlock()
			return
		var j: Array = _jobs.pop_front()
		_mutex.unlock()
		var res := _build(j[0], int(j[1]))
		_mutex.lock()
		_done.append([j[0], j[1], res])
		_mutex.unlock()

static func _request(key: String, dir: int) -> void:
	var ck := _ck(key, dir)
	if _pending.has(ck) or _cache.has(ck):
		return
	_pending[ck] = true
	_mutex.lock()
	_jobs.append([key, dir])
	var start := not _running
	if start:
		_running = true
	_mutex.unlock()
	if start:
		if _thread != null:
			_thread.wait_to_finish()
		_thread = Thread.new()
		_thread.start(_worker)

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
	for key in ["soldier", "ally", "medic", "tank", "mech", "bee", "golem", "worm", "aegis", "sinner", "earthworm", "heavytank", "apoctank"]:
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

	func _init(a: float) -> void:
		rot = Basis(Vector3(0, 0, 1), a)

	func ell(c: Vector3, r: Vector3, pal: Array, tilt: Basis = Basis.IDENTITY) -> void:
		prims.append([rot * c, r, rot * tilt, pal, 0])

	# a box with half sizes h (hard edges: hulls, treads, bodies)
	func box(c: Vector3, h: Vector3, pal: Array, tilt: Basis = Basis.IDENTITY) -> void:
		prims.append([rot * c, h, rot * tilt, pal, 1])

	# an upright cylinder: c = middle of the cylinder, r = radius, hh = half height (flat top: towers, drums)
	func cyl(c: Vector3, r: float, hh: float, pal: Array) -> void:
		prims.append([rot * c, Vector3(r, r, hh), rot, pal, 3])

	# an upright cone: c = middle of the cone, r = radius at the bottom, hh = half height (roofs, spires)
	func cone(c: Vector3, r: float, hh: float, pal: Array) -> void:
		prims.append([rot * c, Vector3(r, r, hh), rot, pal, 2])

	# a rounded bar between two points
	func cap(a: Vector3, b: Vector3, r: float, pal: Array) -> void:
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
		"ally":
			return _soldier(f, ang, 1)
		"medic":
			return _soldier(f, ang, 2)
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
		"demon":
			return _demon(f, ang)
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
	if role == 0:
		s.ell(Vector3(-2.8, 0, 10), Vector3(1.6, 2.6, 3.0), _P(["0e1409", "1a2310", "2a3a1a", "3a5024"]))
	if role == 3:       # zombie walk: both arms stretched out in front, swaying
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
	if role == 0:
		s.cap(Vector3(-2, 3.0, 9.4), Vector3(9.5, 3.0, 9.4), 0.9, _P(["0a0b08", "1c1e18", "2e3126", "444838"]))
	s.ell(Vector3(0.4, 0, 15.2), Vector3(3.1, 3.1, 3.2), skin)
	s.ell(Vector3(0.0, 0, 16.9), Vector3(3.7, 3.7, 2.3), hel)
	var eye := _hx("ff2020") if role == 3 else _hx("0a0a0a")
	s.ell(Vector3(3.2, -1.2, 15.4), Vector3(0.5, 0.5, 0.5), [eye])
	s.ell(Vector3(3.2, 1.2, 15.4), Vector3(0.5, 0.5, 0.5), [eye])
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

static func _golem(f: int, ang: float) -> Cv:
	var s := Scene3.new(ang)
	var sw: float = [0.0, 2.2, 0.0, -2.2][f % 4]
	var rock := _P(["1c1a1a", "342e2c", "564e4a", "7a706a", "9a908a"])
	var dk := _P(["0c0a0a", "1c1818", "2e2826", "443c38", "564e4a"])
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

static func _demon(f: int, ang: float) -> Cv:
	return _demon_scene(f, ang, 1.0).render(40, 48, 38.0)

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
