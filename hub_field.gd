class_name HubField
extends Node2D

# The safe hub: "Skyhold", a gigantic flying carrier above the clouds. The hull, the buildings, the airships and the
# clouds are baked pixel-art pictures (SkyholdPng) made with the castle's own palettes and lighting, so they match the
# castle and the mobs. Only the moving bits are drawn here: flags, smoke, propellers, engine flames and lights.
# One art pixel = 3 world pixels, the camera looks from 55 degrees like the castles.
const USE_DIST := 650.0         # the castle must be this close to a building to use it
const CLICK_R := 150.0
const HALF := Vector2(2000.0, 1000.0)
const PX := 3.0
const SIN := 0.8192
const COS := 0.5736

const GOLD := Color(0.95, 0.78, 0.2)
const BRONZE := Color(0.68, 0.46, 0.2)
const OUT := Color(0.05, 0.04, 0.09)
const GLOW := Color(0.35, 0.85, 1.0)
const SPRITES := {"map": "b_map", "workshop": "b_workshop", "trader": "b_trader", "stash": "b_stash", "yard": "b_yard"}

var origin: Vector2 = Vector2.ZERO
var stations: Array[Dictionary] = []
var _t: float = 0.0
var _hot: String = ""

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func setup(o: Vector2) -> void:
	origin = o
	stations = [
		{"id": "map", "name": "Map Table", "pos": o + Vector2(-800, -380), "col": Color(0.95, 0.8, 0.35)},
		{"id": "workshop", "name": "Castle Workshop", "pos": o + Vector2(800, -380), "col": Color(0.55, 0.8, 1.0)},
		{"id": "trader", "name": "Trader", "pos": o + Vector2(-1120, -90), "col": Color(0.55, 1.0, 0.6)},
		{"id": "stash", "name": "Stash", "pos": o + Vector2(1150, -60), "col": Color(0.85, 0.6, 1.0)},
		{"id": "yard", "name": "Shipyard", "pos": o + Vector2(0, -470), "col": Color(1.0, 0.55, 0.4)},
	]

func clamp_pos(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, origin.x - HALF.x, origin.x + HALF.x), clampf(p.y, origin.y - HALF.y, origin.y + HALF.y))

func station_at(p: Vector2) -> Dictionary:
	for s in stations:
		if p.distance_to(s["pos"] as Vector2) <= CLICK_R:
			return s
	return {}

const STATION_TIPS := {
	"map": "Pick an expedition or the Dungeon and fly out. Clear the zones, beat the boss and bring loot home.",
	"workshop": "Open the Castle window: spend stat points, and upgrade your weapon.",
	"trader": "Sell the items from your bag for gold.",
	"stash": "Keep your items safe between trips. Nothing in the stash is lost when you fall.",
	"yard": "Grow your castle to the next stage with gold and materials.",
}

func _process(delta: float) -> void:
	_t += delta
	var st := station_at(get_global_mouse_position())
	_hot = "" if st.is_empty() else str(st["id"])
	if st.is_empty() or get_tree().paused:
		Tip.hide_for(self)
	else:
		Tip.show_text(self, str(st["name"]), str(STATION_TIPS.get(str(st["id"]), "")), "")
	queue_redraw()

# ---------------------------------------------------------------- helpers

static func _h(i: int, s: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(s) * 78.233) * 43758.5453, 1.0)

func _view() -> Rect2:
	var inv := get_canvas_transform().affine_inverse()
	var sz := get_viewport_rect().size
	return Rect2(inv * Vector2.ZERO, inv.basis_xform(sz)).abs()

# a point of the carrier's scene (x right, y towards the viewer, z up) on the screen
func _sc(x: float, y: float, z: float) -> Vector2:
	return origin + Vector2(x, y * SIN - z * COS) * PX

func _snap(p: Vector2) -> Vector2:
	return Vector2(roundf(p.x / PX) * PX, roundf(p.y / PX) * PX)

# a baked picture: `at` is where its ground point goes
func _spr(name: String, at: Vector2, flip: float = 1.0, tint: Color = Color.WHITE, k: float = 1.0) -> void:
	var t := SkyholdPng.tex(name)
	draw_set_transform(_snap(at), 0.0, Vector2(PX * k * flip, PX * k))
	draw_texture(t, Vector2(-floorf(SkyholdPng.w(name) * 0.5), -SkyholdPng.gy(name)), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _ring_flat(c: Vector2, r: float, col: Color, w: float) -> void:
	draw_set_transform(c, 0.0, Vector2(1.0, SIN))
	PixelFx.ring(self, Vector2.ZERO, r, col, w)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _flag(tip: Vector2, col: Color, ph: float) -> void:
	var fl := roundf(sin(_t * 4.0 + ph) * 2.0) * PX
	var p := _snap(tip)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(42, 6 + fl), p + Vector2(0, 18)]), OUT)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, 0), p + Vector2(36, 7 + fl), p + Vector2(0, 14)]), col)

func _smoke(p: Vector2) -> void:
	for i in 5:
		var f := fposmod(_t * 0.3 + float(i) * 0.2, 1.0)
		var q := _snap(p + Vector2(sin(f * 6.0 + float(i)) * 12.0 + f * 30.0, -f * 160.0))
		var r := 9.0 + f * 24.0
		draw_rect(Rect2(q - Vector2(r, r) * 0.5, Vector2(r, r)), Color(0.88, 0.9, 0.96, 0.55 * (1.0 - f)))

func _clouds(v: Rect2, k: float, n: int, seed_: int, speed: float, y_frac: float, y_span: float, tint: Color, sc: float) -> void:
	var w := v.size.x * 1.5
	var c := v.get_center()
	for i in n:
		var x := fposmod(_h(i, seed_) * w + _t * speed - (c.x - origin.x) * k, w) - w * 0.5
		var y := v.size.y * (y_frac + _h(i, seed_ + 9) * y_span - 0.5) - (c.y - origin.y) * k
		var nm := "cloud%d" % int(_h(i, seed_ + 4) * 7.999)
		var p := c + Vector2(x, y)
		var hw := SkyholdPng.w(nm) * PX * sc * 0.5
		if p.x < v.position.x - hw or p.x > v.end.x + hw or p.y < v.position.y - 400.0 or p.y > v.end.y + 400.0:
			continue
		_spr(nm, p + Vector2(0, SkyholdPng.gy(nm) * PX * sc * 0.5), 1.0, tint, sc)

func _sky(v: Rect2) -> void:
	var top := Color(0.2, 0.42, 0.84)
	var bot := Color(0.98, 0.82, 0.66)
	var bands := 16
	var bh := v.size.y / float(bands) + 1.0
	for i in bands:
		var f := float(i) / float(bands - 1)
		draw_rect(Rect2(v.position.x - 4.0, v.position.y + v.size.y * float(i) / float(bands), v.size.x + 8.0, bh), top.lerp(bot, f * f * 0.95 + f * 0.05))
	var sun := v.position + v.size * Vector2(0.82, 0.2)
	PixelFx.disc(self, sun, 230.0, Color(1.0, 0.93, 0.7, 0.10))
	PixelFx.disc(self, sun, 150.0, Color(1.0, 0.95, 0.75, 0.16))
	PixelFx.disc(self, sun, 82.0, Color(1.0, 0.98, 0.85, 0.95))

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var v := _view()
	_sky(v)
	_clouds(v, 0.08, 10, 31, 3.0, 0.70, 0.30, Color(0.8, 0.84, 0.98, 0.7), 0.7)
	_clouds(v, 0.18, 18, 3, 6.0, 0.88, 0.30, Color(0.93, 0.93, 1.0, 0.95), 1.0)
	_clouds(v, 0.4, 16, 11, 10.0, 0.96, 0.26, Color(1, 1, 1, 1), 1.25)
	# far airships crossing the sky
	for i in 3:
		var w := v.size.x * 1.6
		var x := fposmod(_h(i, 31) * w + _t * (14.0 + 6.0 * float(i)) - (v.get_center().x - origin.x) * 0.3, w) - w * 0.5
		var y := v.size.y * (0.14 + 0.1 * float(i)) - 120.0 - (v.get_center().y - origin.y) * 0.3
		_spr(["ship_a", "ship_b", "ship_c"][i], v.get_center() + Vector2(x, y), 1.0, Color(0.85, 0.88, 1.0, 0.92), 0.67)
	# the shadow of the carrier on the clouds below
	draw_colored_polygon(_ellipse(origin + Vector2(80, 1260), 1700.0, 150.0), Color(0.15, 0.2, 0.4, 0.13))
	_engine_flames()
	_spr("hull", origin)
	_hull_lights()
	_moored()
	_clouds(v, 0.75, 6, 21, 18.0, 1.02, 0.2, Color(1, 1, 1, 0.96), 1.5)
	for p: Vector2 in [Vector2(-500, -130), Vector2(-500, 60), Vector2(470, -150), Vector2(470, 70)]:
		_turret(p)
	_spr("radar", _sc(473, -100, 0))
	_radar_dish()
	for id: String in ["yard", "map", "workshop", "trader", "stash"]:
		for s in stations:
			if str(s["id"]) == id:
				_building(s, _hot == id)
	_people()
	_gulls()
	_beacons()
	_labels()
	PixelUI.text(self, _sc(-380, 135, -96) + Vector2(0, 0), "SKYHOLD", 54, Color(0.95, 0.78, 0.2, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 760.0, 6)

func _ellipse(c: Vector2, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var a := PackedVector2Array()
	for i in n:
		var ang := TAU * float(i) / float(n)
		a.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return a

func _engine_flames() -> void:
	for ey: float in [-120.0, 30.0]:
		var p := _sc(-663.0, ey, -50.0)
		var fl := 0.82 + 0.18 * sin(_t * 18.0 + ey)
		var q := _snap(p)
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -60), q + Vector2(-380.0 * fl, 0), q + Vector2(0, 60)]), Color(GLOW.r, GLOW.g, GLOW.b, 0.22))
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -36), q + Vector2(-250.0 * fl, 0), q + Vector2(0, 36)]), Color(GLOW.r, GLOW.g, GLOW.b, 0.4))
		draw_colored_polygon(PackedVector2Array([q + Vector2(0, -18), q + Vector2(-130.0 * fl, 0), q + Vector2(0, 18)]), Color(0.9, 1.0, 1.0, 0.75))

func _hull_lights() -> void:
	# propellers on the stern pods
	for ey: float in [-120.0, 30.0]:
		var hub := _snap(_sc(-668.0, ey, -50.0))
		draw_rect(Rect2(hub + Vector2(-3, -78), Vector2(6, 156)), Color(0.8, 0.88, 1.0, 0.13))
		for k in 2:
			var a := _t * 12.0 + float(k) * PI * 0.5
			var L := 26.0 * PX
			var e := Vector2(0.0, sin(a) * L * COS * 1.2 + cos(a) * L * 0.0)
			draw_line(hub - e, hub + e, OUT, 12.0)
			draw_line(hub - e, hub + e, Color(0.92, 0.78, 0.47), 7.0)
		draw_rect(Rect2(hub - Vector2(9, 9), Vector2(18, 18)), OUT)
		draw_rect(Rect2(hub - Vector2(6, 6), Vector2(12, 12)), BRONZE)
	# the landing pad ring pulses, the runway lights chase towards the bow
	var pc := _sc(0.0, 0.0, 1.5)
	_ring_flat(pc, 76.0 * PX, Color(GLOW.r, GLOW.g, GLOW.b, 0.30 + 0.22 * sin(_t * 2.0)), 9.0)
	for k in 33:
		var f := fposmod(float(k) * 0.045 - _t * 0.7, 1.0)
		var a := 0.15 + 0.85 * pow(1.0 - f, 4.0)
		for yy: float in [-52.0, 56.0]:
			var q := _snap(_sc(-530.0 + float(k) * 33.0, yy, 1.0))
			draw_rect(Rect2(q - Vector2(6, 6), Vector2(12, 12)), Color(0.8, 0.97, 1.0, a))
	# warm light pools under the deck lamps
	var lamps: Array = []
	for lx in range(-470, -60, 95):
		lamps.append(float(lx))
	for lx in range(100, 360, 95):
		lamps.append(float(lx))
	for i in lamps.size():
		var lxx: float = lamps[i]
		var fl := 0.85 + 0.15 * sin(_t * 3.1 + float(i) * 1.7)
		_pool(_snap(_sc(lxx, 121.0, 0.0)), 15.0 * PX, fl)
	# flags on the corner towers and the prow tower
	var tips: Array = SkyholdPng.anchors("hull_flags")
	for i in tips.size():
		_flag(origin + (tips[i] as Vector2) * PX, Color(0.85, 0.16, 0.2) if i < 4 else Color(0.95, 0.78, 0.2), float(i))

func _pool(p: Vector2, r: float, f: float) -> void:
	# soft warm pool of lamp light, squashed to lie flat on the deck
	draw_set_transform(p, 0.0, Vector2(1.0, SIN))
	for k in 4:
		var rr := r * (1.0 - float(k) * 0.24)
		draw_circle(Vector2.ZERO, rr, Color(1.0, 0.82, 0.42, 0.045 * f))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _moored() -> void:
	# airships tied up at the two docking arms
	for side: float in [-1.0, 1.0]:
		var bob := roundf(sin(_t * 1.3 + side) * 2.0) * PX
		var p := _sc(side * 395.0, 305.0, -34.0) + Vector2(0, bob)
		var nm := "ship_a" if side < 0.0 else "ship_b"
		_spr(nm, p, -side)
		var hub := _snap(p + SkyholdPng.anchor("ship_prop") * Vector2(-side, 1.0) * PX)
		var a := _t * 14.0
		var e := Vector2(0.0, sin(a) * 22.0)
		draw_line(hub - e, hub + e, OUT, 9.0)
		draw_line(hub - e, hub + e, Color(0.92, 0.78, 0.47), 5.0)

func _turret(p: Vector2) -> void:
	var base := _sc(p.x, p.y, 0.0)
	_spr("turret", base)
	var top := _snap(_sc(p.x, p.y, 16.0))
	var a := sin(_t * 0.35 + p.x * 0.01) * 0.9 + (PI if p.x > 0.0 else 0.0)
	var dir := Vector2(cos(a), sin(a) * SIN)
	for off: float in [-9.0, 9.0]:
		var o2 := Vector2(-dir.y, dir.x) * off
		draw_line(top + o2, top + o2 + dir * 86.0, OUT, 12.0)
		draw_line(top + o2, top + o2 + dir * 86.0, Color(0.5, 0.5, 0.62), 7.0)
	draw_rect(Rect2(top - Vector2(9, 9), Vector2(18, 18)), BRONZE)

func _radar_dish() -> void:
	var top := _snap(_sc(473.0, -100.0, 119.0))
	var a := _t * 1.2
	var e := Vector2(cos(a) * 66.0, sin(a) * 20.0)
	draw_line(top - e, top + e, OUT, 14.0)
	draw_line(top - e, top + e, Color(0.92, 0.78, 0.47), 8.0)
	draw_rect(Rect2(top - Vector2(8, 8), Vector2(16, 16)), Color(0.95, 0.3, 0.25, 0.6 + 0.4 * sin(_t * 4.0)))
	for dir: float in [0.0, PI]:
		var d := Vector2(cos(_t * 0.8 + dir), sin(_t * 0.8 + dir) * 0.3)
		draw_colored_polygon(PackedVector2Array([top, top + d * 800.0 + Vector2(0, -60), top + d * 800.0 + Vector2(0, 20)]), Color(GLOW.r, GLOW.g, GLOW.b, 0.06))

func _gulls() -> void:
	for i in 6:
		var ang := _t * (0.12 + _h(i, 71) * 0.1) + float(i) * 2.1
		var p := _snap(origin + Vector2(cos(ang) * (900.0 + float(i) * 180.0), -700.0 + sin(ang * 1.3) * 260.0 - float(i) * 40.0))
		var fl := roundf(sin(_t * 7.0 + float(i))) * PX * 2.0
		draw_line(p + Vector2(-12, fl), p, Color(1, 1, 1), 3.0)
		draw_line(p, p + Vector2(12, fl), Color(1, 1, 1), 3.0)

# ---------------------------------------------------------------- the people on deck
# Soldier-model sprites (MobArt) in Skyhold colours: guards patrol the front promenade and stand at the gate, deck
# engineers shuttle between the workshops, medics stroll around the landing pad and passengers wander by the market.
var _crowd_list: Array = []

func _route_ellipse(rx: float, ry: float, n: int) -> PackedVector2Array:
	var a := PackedVector2Array()
	for i in n:
		var t := TAU * float(i) / float(n)
		a.append(Vector2(cos(t) * rx, sin(t) * ry))
	return a

func _crowd() -> Array:
	if not _crowd_list.is_empty():
		return _crowd_list
	var front := PackedVector2Array([Vector2(-500, 82), Vector2(330, 82)])
	var list: Array = [
		{"key": "guard", "pts": front, "closed": false, "spd": 15.0, "off": 0.0, "tint": Color.WHITE},
		{"key": "guard", "pts": front, "closed": false, "spd": 15.0, "off": 29.0, "tint": Color(0.95, 0.95, 1.0)},
		{"key": "guard", "pts": PackedVector2Array([Vector2(-17, 112)]), "closed": false, "spd": 0.0, "off": 0.0, "tint": Color.WHITE, "head": PI * 0.5},
		{"key": "guard", "pts": PackedVector2Array([Vector2(17, 112)]), "closed": false, "spd": 0.0, "off": 0.0, "tint": Color.WHITE, "head": PI * 0.5},
		{"key": "medic", "pts": _route_ellipse(150.0, 100.0, 14), "closed": true, "spd": 11.0, "off": 0.0, "tint": Color(1.0, 0.97, 0.92)},
		{"key": "medic", "pts": _route_ellipse(150.0, 100.0, 14), "closed": true, "spd": 11.0, "off": 40.0, "tint": Color(0.92, 0.96, 1.0)},
		{"key": "crew", "pts": PackedVector2Array([Vector2(190, -55), Vector2(350, -55)]), "closed": false, "spd": 13.0, "off": 3.0, "tint": Color.WHITE},
		{"key": "crew", "pts": PackedVector2Array([Vector2(-340, -55), Vector2(-190, -55)]), "closed": false, "spd": 13.0, "off": 7.0, "tint": Color(1.0, 0.95, 0.88)},
		{"key": "crew", "pts": PackedVector2Array([Vector2(-262, 40), Vector2(-168, 40)]), "closed": false, "spd": 12.0, "off": 1.0, "tint": Color(0.95, 0.95, 1.0)},
		{"key": "ally", "pts": PackedVector2Array([Vector2(-470, 52), Vector2(-290, 52)]), "closed": false, "spd": 9.0, "off": 0.0, "tint": Color(0.85, 0.92, 1.0)},
		{"key": "ally", "pts": PackedVector2Array([Vector2(-470, 52), Vector2(-290, 52)]), "closed": false, "spd": 8.0, "off": 21.0, "tint": Color(1.0, 0.9, 0.78)},
		{"key": "medic", "pts": PackedVector2Array([Vector2(-30, -74)]), "closed": false, "spd": 0.0, "off": 0.0, "tint": Color.WHITE, "head": PI},
		{"key": "crew", "pts": PackedVector2Array([Vector2(-8, -74)]), "closed": false, "spd": 0.0, "off": 0.0, "tint": Color.WHITE, "head": 0.0},
	]
	_crowd_list = list
	return _crowd_list

# position, heading and walking distance of one person at the current time
func _person_state(w: Dictionary) -> Dictionary:
	var pts: PackedVector2Array = w["pts"]
	var spd: float = w["spd"]
	if pts.size() < 2 or spd <= 0.0:
		return {"p": pts[0], "h": float(w.get("head", 0.0)), "d": 0.0, "moving": false}
	var path := PackedVector2Array(pts)
	if bool(w["closed"]):
		path.append(pts[0])
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var d := 0.0
	var fwd := true
	var moving := true
	var tt: float = _t + float(w["off"])
	if bool(w["closed"]):
		d = fposmod(tt * spd, total)
	else:
		var travel := total / spd
		var wait := 2.2
		var u := fposmod(tt, 2.0 * (travel + wait))
		if u < travel:
			d = u * spd
		elif u < travel + wait:
			d = total
			moving = false
		elif u < 2.0 * travel + wait:
			d = total - (u - travel - wait) * spd
			fwd = false
		else:
			d = 0.0
			fwd = false
			moving = false
	var acc := 0.0
	var p := path[0]
	var dir := Vector2.RIGHT
	for i in path.size() - 1:
		var seg := path[i].distance_to(path[i + 1])
		dir = (path[i + 1] - path[i]) / maxf(seg, 0.001)
		if d <= acc + seg or i == path.size() - 2:
			p = path[i] + dir * clampf(d - acc, 0.0, seg)
			break
		acc += seg
	if not fwd:
		dir = -dir
	return {"p": p, "h": dir.angle(), "d": d, "moving": moving}

func _people() -> void:
	var rows: Array = []
	for w: Dictionary in _crowd():
		var st := _person_state(w)
		var sp: Vector2 = st["p"]
		rows.append({"y": sp.y, "w": w, "st": st})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	for r: Dictionary in rows:
		var w: Dictionary = r["w"]
		var st: Dictionary = r["st"]
		var key := str(w["key"])
		var art: Dictionary = MobArt.frames(key, MobArt.dir_of(float(st["h"])))
		var tex_list: Array = art["tex"]
		var n := tex_list.size()
		var fr := 0
		var bob := 0.0
		if bool(st["moving"]):
			fr = int(floorf(float(st["d"]) / 3.2)) % n
		else:
			bob = roundf(sin(_t * 1.6 + float(w["off"]))) * 0.0
		var tex: Texture2D = tex_list[fr]
		var feet := _snap(_sc((st["p"] as Vector2).x, (st["p"] as Vector2).y, 0.0))
		# a small shadow thrown away from the light
		draw_set_transform(feet + Vector2(9.0, -3.0), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 11.0, Color(0.0, 0.0, 0.05, 0.38))
		var k := PX * MobArt.scale_for(key) * 0.8
		var off: Vector2 = art["off"]
		draw_set_transform(feet + Vector2(0.0, bob), 0.0, Vector2(k, k))
		draw_texture(tex, off - tex.get_size() * 0.5, w["tint"])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# blinking red and green position lights around the edge of the flight area
func _beacons() -> void:
	var lo := origin - HALF
	var hi := origin + HALF
	var step := 500.0
	var n := int(HALF.x * 2.0 / step)
	for i in n + 1:
		_beacon(Vector2(lo.x + float(i) * step, lo.y), i)
		_beacon(Vector2(lo.x + float(i) * step, hi.y), i + 1)
	for j in range(1, int(HALF.y * 2.0 / step)):
		_beacon(Vector2(lo.x, lo.y + float(j) * step), j)
		_beacon(Vector2(hi.x, lo.y + float(j) * step), j + 1)

func _beacon(p: Vector2, i: int) -> void:
	var on := 0.35 + 0.65 * maxf(sin(_t * 2.0 + float(i) * 0.9), 0.0)
	var c := Color(1.0, 0.3, 0.3) if i % 2 == 0 else Color(0.35, 1.0, 0.5)
	draw_rect(Rect2(p - Vector2(18, 18), Vector2(36, 36)), Color(c.r, c.g, c.b, 0.12 * on))
	draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(c.r, c.g, c.b, 0.9 * on))

func _labels() -> void:
	var ci := self as CanvasItem
	for s in stations:
		var c: Vector2 = s["pos"]
		var hot := _hot == str(s["id"])
		var txt := Loc.t(str(s["name"]))
		var sw := 320.0
		var r := Rect2(c + Vector2(-sw * 0.5, 100), Vector2(sw, 52))
		ci.draw_style_box(PixelUI.plate(Color(0.07, 0.05, 0.04, 0.96), Color(1.0, 0.85, 0.3) if hot else PixelUI.BRONZE, 2), r)
		PixelUI.text(ci, r.position + Vector2(0, 36), txt, 28, PixelUI.GOLD if hot else Color(1, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER, sw, 5)

func _building(s: Dictionary, hot: bool) -> void:
	var c: Vector2 = s["pos"]
	var col: Color = s["col"]
	var id := str(s["id"])
	var lift := -6.0 if hot else 0.0
	var b := c + Vector2(0, 50.0 + lift)
	_spr(str(SPRITES[id]), b)
	match id:
		"map":
			_flag(b + SkyholdPng.anchor("map_flag") * PX, Color(0.95, 0.78, 0.2), 0.0)
			var rp := b + SkyholdPng.anchor("map_ring") * PX
			draw_set_transform(_snap(rp), 0.0, Vector2(1.0, 0.4 + 0.3 * absf(sin(_t * 0.8))))
			PixelFx.ring(self, Vector2.ZERO, 66.0, Color(0.92, 0.78, 0.47), 6.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"workshop":
			for a: Vector2 in SkyholdPng.anchors("workshop_smoke"):
				_smoke(b + a * PX)
			_flag(b + SkyholdPng.anchor("workshop_flag") * PX, Color(0.35, 0.6, 0.95), 1.0)
		"stash":
			var fa: Array = SkyholdPng.anchors("stash_flags")
			for i in fa.size():
				_flag(b + (fa[i] as Vector2) * PX, Color(0.85, 0.16, 0.2), float(i))
	if hot:
		var r := 130.0 + sin(_t * 5.0) * 6.0
		_ring_flat(c + Vector2(0, 60), r * 1.3, Color(col.r, col.g, col.b, 0.95), 6.0)
		var ar := c + Vector2(0, -420 + sin(_t * 5.0) * 10.0)
		draw_colored_polygon(PackedVector2Array([ar + Vector2(-22, -26), ar + Vector2(22, -26), ar + Vector2(0, 10)]), OUT)
		draw_colored_polygon(PackedVector2Array([ar + Vector2(-15, -21), ar + Vector2(15, -21), ar + Vector2(0, 3)]), col)
