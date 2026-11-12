class_name MobArt
extends RefCounted

# Pixel-art sprites for the ordinary mobs, painted in code (no image files). Same look as the map props:
# shaded volumes lit from the upper left, a dark 1-pixel outline, a few walk frames. Rotating units
# (tanks, ships, worms...) are shaded symmetrically and drawn facing right, the game rotates them.
# One art pixel = PX world pixels. Textures are built once per kind and cached.

const PX := 3.0
const ROTATING := ["tank", "mech", "aegis", "worm", "hunter", "drone", "starship", "corvette"]
const FLIPPING := ["soldier", "ally", "medic", "bee"]
# frames, and how many frames per unit of the mob's walk phase (see Enemy._walk)
const INFO := {
	"soldier": [4, 0.64], "ally": [4, 0.64], "medic": [4, 0.64], "bee": [2, 3.0],
	"tank": [3, 0.6], "mech": [2, 0.6], "aegis": [1, 1.0], "worm": [4, 0.22],
	"golem": [4, 0.95], "demon": [4, 0.45], "hunter": [2, 1.5], "drone": [2, 1.5],
	"starship": [2, 1.5], "corvette": [2, 1.5], "void": [2, 0.25],
}

static var _cache: Dictionary = {}      # key -> {"n": int, "tex": Array, "flash": Array}

static func key_for(kind: String, space: bool, ally: bool) -> String:
	if ally:
		return "ally"
	match kind:
		"tank":
			return "starship" if space else "tank"
		"mech":
			return "corvette" if space else "mech"
		"soldier":
			return "drone" if space else "soldier"
		"worm", "golem", "demon", "hunter", "void", "bee", "medic", "aegis":
			return kind
	return "soldier"

# infantry is drawn smaller than the vehicles so tanks and mechs look big next to it
static func scale_for(key: String) -> float:
	match key:
		"soldier", "ally", "medic":
			return 0.68
		"bee":
			return 0.85
	return 1.0

static func rotates(key: String) -> bool:
	return ROTATING.has(key)

static func flips(key: String) -> bool:
	return FLIPPING.has(key)

static func frame_count(key: String) -> int:
	return int((INFO[key] as Array)[0])

static func frame_rate(key: String) -> float:
	return float((INFO[key] as Array)[1])

static func frames(key: String) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	var n := frame_count(key)
	var tex: Array = []
	var flash: Array = []
	for f in n:
		var cv := _paint(key, f)
		cv.outline()
		tex.append(ImageTexture.create_from_image(cv.img))
		var fi := cv.img.duplicate() as Image
		for y in fi.get_height():
			for x in fi.get_width():
				var c := fi.get_pixel(x, y)
				if c.a > 0.5:
					fi.set_pixel(x, y, c.lerp(Color.WHITE, 0.75))
		flash.append(ImageTexture.create_from_image(fi))
	var out := {"n": n, "tex": tex, "flash": flash}
	_cache[key] = out
	return out

# ---------- a tiny pixel canvas; (0, 0) is the middle ----------

class Cv extends RefCounted:
	var w: int
	var h: int
	var ox: int
	var oy: int
	var img: Image

	func _init(wd: int, ht: int) -> void:
		w = wd
		h = ht
		ox = wd / 2
		oy = ht / 2
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

# ---------- helpers ----------

static func _hx(s: String) -> Color:
	return Color.html(s)

static func _P(list: Array) -> Array:
	var out: Array = []
	for s in list:
		out.append(Color.html(str(s)))
	return out

static func _paint(key: String, f: int) -> Cv:
	match key:
		"soldier":
			return _soldier(f, false)
		"ally":
			return _soldier(f, true)
		"medic":
			return _medic(f)
		"bee":
			return _bee(f)
		"tank":
			return _tank(f)
		"mech":
			return _mech(f)
		"aegis":
			return _aegis()
		"worm":
			return _worm(f)
		"golem":
			return _golem(f)
		"demon":
			return _demon(f)
		"hunter":
			return _hunter(f)
		"drone":
			return _drone(f)
		"starship":
			return _starship(f)
		"corvette":
			return _corvette(f)
	return _void(f)

# ---------- the mobs ----------

static func _soldier(f: int, ally: bool) -> Cv:
	var cv := Cv.new(22, 22)
	var l: int = [0, 1, 0, -1][f % 4]
	var skin := _P(["6a4a38", "a87a5a", "d8a880", "f0c8a0"])
	cv.rect(-3 - l, 3, 2, 4, _hx("343a28"))
	cv.rect(1 + l, 3, 2, 4, _hx("22261a"))
	cv.rect(-3 - l, 7, 3, 1, _hx("14160f"))
	cv.rect(1 + l, 7, 3, 1, _hx("14160f"))
	var jac := _P(["2a1418", "7a2a2a", "b04040", "d86060"]) if ally else _P(["1f2a14", "2f4020", "47602f", "6a8a45"])
	cv.box(-3, -4, 7, 8, jac)
	if not ally:
		cv.line(3, -1, 9, -2, _hx("2a2d22"))
		cv.px(4, -2, skin[2])
		cv.px(3, -2, skin[2])
	else:
		cv.px(4, -1, skin[2])
	cv.sph(0, -7, 3, 3, skin)
	var hel := _P(["3a0c12", "6a1820", "a02a34", "c8505a"]) if ally else _P(["1c2614", "2c3a1e", "3e5229", "567338"])
	cv.sph(0, -8, 4, 3, hel, -7)
	cv.px(2, -6, _hx("1a1a1a"))
	if ally:
		cv.line(5, 0, 5, -10, _hx("8a6a44"))
		cv.polyc([Vector2(6, -10), Vector2(10, -9), Vector2(6, -6)], Color.WHITE)
	return cv

static func _medic(f: int) -> Cv:
	var cv := Cv.new(22, 22)
	var l: int = [0, 1, 0, -1][f % 4]
	cv.rect(-3 - l, 3, 2, 4, _hx("3a4a3a"))
	cv.rect(1 + l, 3, 2, 4, _hx("2a382a"))
	cv.box(-4, -4, 9, 9, _P(["9aa89a", "c8d4c8", "e8f0e8", "ffffff"]))
	cv.rect(0, -2, 1, 5, _hx("2fcb4a"))
	cv.rect(-2, 0, 5, 1, _hx("2fcb4a"))
	cv.sph(0, -7, 3, 3, _P(["6a4a38", "a87a5a", "d8a880", "f0c8a0"]))
	cv.sph(0, -9, 4, 3, _P(["a8b4a8", "d0dcd0", "f0f8f0", "ffffff"]), -8)
	cv.px(2, -6, _hx("1a1a1a"))
	return cv

static func _bee(f: int) -> Cv:
	var cv := Cv.new(20, 18)
	var w: int = [0, -1][f % 2]
	var wing := _hx("d8f0ff")
	var wing2 := _hx("a8d0f0")
	cv.sph(-2, -5 + w, 3, 2, [wing2, wing, wing])
	cv.sph(2, -5 - w, 3, 2, [wing2, wing, wing])
	cv.sph(0, 0, 5, 4, _P(["a07008", "d8a010", "ffcc20", "ffe870"]))
	cv.rect(-4, -1, 9, 1, _hx("2a1a08"))
	cv.rect(-3, 2, 7, 1, _hx("2a1a08"))
	cv.sph(5, 0, 2, 2, _P(["0c0803", "1c1408", "2a1e0c", "46341a"]))
	cv.px(6, -1, Color.WHITE)
	cv.line(-5, 1, -8, 2, _hx("2a1e0c"))
	return cv

static func _tank(f: int) -> Cv:
	var cv := Cv.new(26, 22)
	var tr := _P(["0c0d0a", "1c1d18", "2c2d26", "3e3f36"])
	cv.rect(-9, -8, 18, 4, tr[1])
	cv.rect(-9, 4, 18, 4, tr[1])
	for i in range(0, 18, 3):
		var x := -9 + ((i + f) % 18)
		cv.px(x, -7, tr[3])
		cv.px(x, -6, tr[3])
		cv.px(x, 5, tr[3])
		cv.px(x, 6, tr[3])
	cv.sbox(-8, -5, 16, 10, _P(["1c2a14", "2f4222", "47602f", "6a8a45"]))
	cv.dome(1, 0, 4, 4, _P(["1c2a14", "2f4222", "47602f", "6a8a45", "88ab5c"]))
	cv.rect(4, -1, 10, 2, _hx("1c2014"))
	cv.rect(13, -2, 2, 4, _hx("0c0e08"))
	return cv

static func _mech(f: int) -> Cv:
	var cv := Cv.new(24, 20)
	for sx in [-5, 5]:
		for sy in [-6, 5]:
			cv.rect(int(sx) - 1, int(sy) - 1, 3, 3, _hx("1c1d24"))
			cv.px(int(sx), int(sy), _hx("8a8a98") if f % 2 == 1 else _hx("606070"))
	cv.sbox(-7, -4, 15, 9, _P(["2a3040", "44506a", "6a7898", "8a9abc"]))
	cv.rect(-1, -3, 5, 7, _hx("6ad0e8"))
	cv.rect(-1, -3, 5, 1, _hx("a8f0ff"))
	cv.rect(4, -1, 6, 2, _hx("22242c"))
	cv.px(-6, 0, _hx("ff3030"))
	return cv

static func _aegis() -> Cv:
	var cv := Cv.new(20, 20)
	cv.dome(0, 0, 6, 6, _P(["1c2030", "343c52", "545e7c", "7a86a8", "a0aed0"]))
	cv.dome(-1, 0, 3, 3, _P(["10121c", "1c2030", "2a3044"]))
	cv.dome(3, 0, 2, 2, _P(["8a6a10", "d8a820", "ffd860"]))
	return cv

static func _worm(f: int) -> Cv:
	var cv := Cv.new(40, 18)
	var pal := _P(["3a0408", "5c0a10", "8a1418", "b02a30"])
	for i in range(6, 0, -1):
		var y := roundi(sin(float(f) * 1.57 - float(i) * 0.9) * 1.5)
		var rr := 3.0 if i < 4 else 2.0
		cv.sph(-i * 3 + 4, y, rr + 0.5, rr, pal)
	cv.sph(5, 0, 3, 3, _P(["5a0a10", "8a1418", "c42a32", "e85058"]))
	cv.polyc([Vector2(7, -1), Vector2(10, 0), Vector2(7, 1)], _hx("200204"))
	cv.px(5, -2, _hx("ffe040"))
	cv.px(5, 2, _hx("ffe040"))
	return cv

static func _golem(f: int) -> Cv:
	var cv := Cv.new(30, 32)
	var sw: int = [0, 1, 0, -1][f % 4]
	var rock := _P(["1c1a1a", "342e2c", "564e4a", "7a706a", "9a908a"])
	var dk := _P(["0c0a0a", "1c1818", "2e2826", "443c38"])
	cv.sph(-5, 10, 3, 3, dk)
	cv.sph(5, 10, 3, 3, dk)
	cv.sph(-9, sw, 4, 4, rock)
	cv.sph(9, -sw, 4, 4, rock)
	cv.poly([Vector2(-7, -6), Vector2(-4, -10), Vector2(4, -10), Vector2(7, -6), Vector2(8, 5), Vector2(4, 11), Vector2(-4, 11), Vector2(-8, 5)], rock)
	cv.sph(0, -11, 3, 3, dk)
	var g := _hx("ff8a20")
	cv.line(-4, -4, -1, 0, g)
	cv.line(-1, 0, -3, 5, g)
	cv.line(3, -3, 1, 2, g)
	cv.px(-1, -12, _hx("ffb040"))
	cv.px(1, -12, _hx("ffb040"))
	return cv

static func _demon(f: int) -> Cv:
	var cv := Cv.new(44, 40)
	var fl: int = [0, -2, -3, -2][f % 4]
	var wing := _P(["1c0206", "340408", "560a10", "7a1218"])
	cv.poly([Vector2(-3, -3), Vector2(-17, -10 + fl), Vector2(-15, -1), Vector2(-11, 3), Vector2(-5, 3)], wing)
	cv.poly([Vector2(3, -3), Vector2(17, -10 + fl), Vector2(15, -1), Vector2(11, 3), Vector2(5, 3)], wing)
	var red := _P(["3a0408", "70101a", "b01c24", "e04048"])
	cv.line(-10, 10, -5, 2, _hx("340408"))
	cv.line(10, 10, 5, 2, _hx("340408"))
	cv.poly([Vector2(-6, -5), Vector2(-4, -8), Vector2(4, -8), Vector2(6, -5), Vector2(7, 5), Vector2(3, 11), Vector2(-3, 11), Vector2(-7, 5)], red)
	cv.sph(0, -11, 4, 4, red)
	var bone := _P(["8a8070", "c8c0b0", "e8e0d0"])
	cv.poly([Vector2(-4, -13), Vector2(-8, -19), Vector2(-2, -14)], bone)
	cv.poly([Vector2(4, -13), Vector2(8, -19), Vector2(2, -14)], bone)
	cv.px(-2, -11, _hx("ffe030"))
	cv.px(2, -11, _hx("ffe030"))
	cv.line(-2, -8, 2, -8, _hx("200000"))
	var fl2 := 3 + (f % 2)
	cv.polyc([Vector2(-2, 11), Vector2(0, 12 + fl2), Vector2(2, 11)], _hx("ff9020"))
	return cv

static func _hunter(f: int) -> Cv:
	var cv := Cv.new(24, 20)
	var fx := 2 + (f % 2)
	cv.polyc([Vector2(-9, -2), Vector2(-9 - fx, 0), Vector2(-9, 2)], _hx("ff9020"))
	var pal := _P(["2a0c1a", "5a1a38", "9a2a60", "c85a8a"])
	cv.poly([Vector2(2, -3), Vector2(-6, -9), Vector2(-8, -7), Vector2(-3, -2)], pal, true)
	cv.poly([Vector2(2, 3), Vector2(-6, 9), Vector2(-8, 7), Vector2(-3, 2)], pal, true)
	cv.poly([Vector2(10, 0), Vector2(3, -3), Vector2(-7, -3), Vector2(-6, 0), Vector2(-7, 3), Vector2(3, 3)], pal, true)
	cv.polyc([Vector2(10, 0), Vector2(5, -1), Vector2(5, 1)], _hx("f0f0f8"))
	cv.px(2, 0, _hx("ffd860"))
	cv.px(3, 0, _hx("ffd860"))
	return cv

static func _drone(f: int) -> Cv:
	var cv := Cv.new(20, 16)
	var fx := 2 + (f % 2)
	cv.polyc([Vector2(-4, -1), Vector2(-4 - fx, 0), Vector2(-4, 1)], _hx("ff9020"))
	var pal := _P(["14121c", "2a2638", "403a56", "5e5680"])
	cv.poly([Vector2(0, -2), Vector2(-5, -6), Vector2(-4, -2)], pal, true)
	cv.poly([Vector2(0, 2), Vector2(-5, 6), Vector2(-4, 2)], pal, true)
	cv.poly([Vector2(7, 0), Vector2(-1, -4), Vector2(-4, 0), Vector2(-1, 4)], pal, true)
	cv.polyc([Vector2(7, 0), Vector2(1, -1), Vector2(1, 1)], _hx("f04030"))
	cv.px(-1, 0, _hx("ff6040"))
	return cv

static func _starship(f: int) -> Cv:
	var cv := Cv.new(34, 26)
	var fx := 2 + (f % 2)
	for y in [-2, 2]:
		var yy: int = y
		cv.polyc([Vector2(-11, yy - 1), Vector2(-11 - fx - 1, yy), Vector2(-11, yy + 1)], _hx("ff9020"))
	var wing := _P(["0c1018", "1c2030", "2c3248", "444c68"])
	cv.poly([Vector2(2, -3), Vector2(-8, -10), Vector2(-11, -10), Vector2(-8, -3)], wing, true)
	cv.poly([Vector2(2, 3), Vector2(-8, 10), Vector2(-11, 10), Vector2(-8, 3)], wing, true)
	var hull := _P(["1c2030", "3a4258", "5a6482", "7e8aae"])
	cv.poly([Vector2(14, 0), Vector2(5, -3), Vector2(-9, -4), Vector2(-11, 0), Vector2(-9, 4), Vector2(5, 3)], hull, true)
	cv.rect(-8, 0, 12, 1, _hx("d83030"))
	cv.polyc([Vector2(8, -1), Vector2(11, 0), Vector2(8, 1)], _hx("90e8ff"))
	return cv

static func _corvette(f: int) -> Cv:
	var cv := Cv.new(30, 22)
	var fx := 2 + (f % 2)
	for y in [-2, 2]:
		var yy: int = y
		cv.polyc([Vector2(-9, yy - 1), Vector2(-9 - fx, yy), Vector2(-9, yy + 1)], _hx("ff9020"))
	var wing := _P(["181c28", "2c3244", "444c64", "5e6888"])
	cv.poly([Vector2(-3, -4), Vector2(-9, -8), Vector2(-7, -3)], wing, true)
	cv.poly([Vector2(-3, 4), Vector2(-9, 8), Vector2(-7, 3)], wing, true)
	var hull := _P(["22283a", "44506c", "6a7898", "94a4c8"])
	cv.poly([Vector2(11, 0), Vector2(6, -3), Vector2(-5, -4), Vector2(-9, -2), Vector2(-9, 2), Vector2(-5, 4), Vector2(6, 3)], hull, true)
	cv.dome(4, 0, 2, 2, _P(["286878", "48a8c0", "90f0ff"]))
	cv.px(-6, 0, _hx("ff3030"))
	return cv

static func _void(f: int) -> Cv:
	var cv := Cv.new(24, 24)
	var b: int = [0, 1][f % 2]
	cv.sph(0, b, 7, 7, _P(["0c0418", "1e0a34", "381560", "5a2a98"]))
	cv.sph(1, b, 3, 3, _P(["c8b8e0", "ece8f8", "ffffff"]))
	cv.sph(2, b, 1, 1, _P(["6a1ac8", "9a50f0"]))
	cv.px(2, b, Color.BLACK)
	return cv
