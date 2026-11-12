class_name CastleArt
extends RefCounted

# The five castle tiers (village, town, city, fortress, capital) as small lit 3D models, seen from the same tilted
# camera as the map and painted into pixel-art sprites by MobArt.Scene3. One art pixel = 2 world pixels at body
# radius 60. Scene units are art pixels: x to the right, y towards the viewer, z up. Island top surface is z = 4.

const W := 210
const H := 310
const GY := 155.0            # picture row of the ground point (0, 0, 0)
const TOP := 11.0            # height of the grass surface
const TIERS := 10

# flag cloth anchors per tier: [x, y, z (top of the pole), cloth colour]
static func flags(tier: int) -> Array:
	var gold := Color(0.95, 0.78, 0.2)
	var red := Color(0.85, 0.16, 0.2)
	match tier:
		0:
			return [[-4.4, -19.6, 58.8, gold]]
		1:
			return [[0.0, -12.2, 138.8, red]]
		2:
			return [[0.0, -16.3, 174.8, red]]
		3:
			return [[0.0, -16.4, 194.8, Color(0.7, 0.12, 0.18)]]
		4:
			return [[0.0, -20.8, 200.0, red]]
		5:
			return [[0.0, -12.8, 125.0, red]]
		6:
			return [[0.0, -14.4, 171.0, red]]
		7:
			return [[0.0, -16.0, 149.0, red]]
		8:
			return [[0.0, -6.4, 200.0, red]]
	return [[0.0, -8.0, 160.0, Color(0.8, 0.1, 0.1)]]

static var _tex: Dictionary = {}

# pre-baked, detailed castle picture for a tier
static func tex(tier: int) -> Texture2D:
	if not _tex.has(tier):
		var img := Image.new()
		img.load_png_from_buffer(Marshalls.base64_to_raw(CastlePng.DATA[tier]))
		_tex[tier] = ImageTexture.create_from_image(img)
	return _tex[tier]

# where a scene point lands, in art pixels, relative to the middle of the island top (0, 0, TOP)
static func screen_of(x: float, y: float, z: float) -> Vector2:
	var ph := deg_to_rad(MobArt.ELEV)
	return Vector2(x, y * sin(ph) - (z - TOP) * cos(ph))

# picture row of the island top centre (used to seat the sprite on the castle's position)
static func top_row() -> float:
	return GY - TOP * cos(deg_to_rad(MobArt.ELEV))

static func _P(l: Array) -> Array:
	return MobArt._P(l)

static var _stone: Array = []
static var _dstone: Array = []
static var _sand: Array = []
static var _red: Array = []
static var _blue: Array = []
static var _gold: Array = []
static var _wood: Array = []
static var _leaf: Array = []
static var _dark: Array = []
static var _glow: Array = []

static func _pals() -> void:
	if not _stone.is_empty():
		return
	_stone = _P(["1c1c26", "34344a", "54546a", "7a7a92", "a2a2b8"])
	_dstone = _P(["12121a", "22222e", "383848", "50505e", "6c6c7c"])
	_sand = _P(["3a2c1c", "5e4a30", "8c7450", "b89c6c", "dcc48e"])
	_red = _P(["34100e", "5e1c18", "8e2c24", "c04438", "e07860"])
	_blue = _P(["0e1632", "1a2a5e", "2c4896", "486cc4", "78a0e8"])
	_gold = _P(["4a2e06", "86580a", "c08c18", "e8b82a", "fff0a0"])
	_wood = _P(["2a1a0c", "4a2e18", "6e4826"])
	_leaf = _P(["0e2a12", "1c4a1e", "2e7a2c", "4aa83c", "7ad060"])
	_dark = _P(["06060a", "0e0e14", "16161e"])
	_glow = [Color.html("ffd060")]

static func _island(s: MobArt.Scene3, grass: Array) -> void:
	var soil := _P(["1a100a", "2e1c10", "4a2e1a"])
	var rock := _P(["12101a", "221e2a", "383240", "544c58", "746a78"])
	var rock2 := _P(["0e0c14", "1a1620", "2a2430", "403846"])
	var crys := _P(["103a68", "2078c0", "70d0ff", "e8ffff"])
	s.ell(Vector3(0, 0, 3.0), Vector3(40, 40, 2.6), grass)
	s.ell(Vector3(0, 0, 0.6), Vector3(40.5, 40.5, 3.2), soil)
	s.ell(Vector3(0, 0, -8), Vector3(37, 37, 12), rock)
	s.ell(Vector3(1, -1, -30), Vector3(28, 28, 22), rock2)
	s.ell(Vector3(-1, 1, -56), Vector3(17, 17, 28), rock2)
	s.ell(Vector3(0, 0, -84), Vector3(7, 7, 16), rock2)
	for p: Vector3 in [Vector3(-24, 22, -14), Vector3(22, 26, -16), Vector3(0, 30, -30)]:
		s.ell(p, Vector3(2.4, 2.4, 5.0), crys, Basis(Vector3(0, 1, 0), 0.4))

static func _house(s: MobArt.Scene3, x: float, y: float, w: float, d: float, h: float, wall: Array, roof: Array) -> void:
	s.box(Vector3(x, y, TOP + h * 0.5), Vector3(w * 0.5, d * 0.5, h * 0.5), wall)
	s.cone(Vector3(x, y, TOP + h + w * 0.28), w * 0.74, w * 0.28, roof)
	s.box(Vector3(x - w * 0.16, y + d * 0.5, TOP + h * 0.55), Vector3(0.9, 0.3, 1.3), _glow)
	s.box(Vector3(x + w * 0.1, y + d * 0.5, TOP + h * 0.2), Vector3(1.0, 0.3, 1.6), _dark)

static func _tower(s: MobArt.Scene3, x: float, y: float, r: float, h: float, wall: Array, roof: Array, roof_h: float) -> void:
	s.cyl(Vector3(x, y, TOP + h * 0.5), r, h * 0.5, wall)
	s.cyl(Vector3(x, y, TOP + h + 0.8), r + 1.1, 0.9, wall)         # corbel under the roof / crown
	if roof_h > 0.0:
		s.cone(Vector3(x, y, TOP + h + 1.6 + roof_h * 0.5), r + 1.6, roof_h * 0.5, roof)
	else:
		for i in 8:
			var a := TAU * float(i) / 8.0
			s.box(Vector3(x + cos(a) * (r + 0.6), y + sin(a) * (r + 0.6), TOP + h + 2.6), Vector3(1.0, 1.0, 1.3), wall)
	s.box(Vector3(x - r * 0.25, y + r * 0.96, TOP + h * 0.72), Vector3(0.8, 0.3, 1.6), _glow)
	if h > 24.0:
		s.box(Vector3(x + r * 0.3, y + r * 0.9, TOP + h * 0.4), Vector3(0.8, 0.3, 1.6), _glow)

static func _wall(s: MobArt.Scene3, x1: float, x2: float, y: float, h: float, wall: Array, thick: float = 2.2) -> void:
	s.box(Vector3((x1 + x2) * 0.5, y, TOP + h * 0.5), Vector3((x2 - x1) * 0.5, thick, h * 0.5), wall)
	var n := int((x2 - x1) / 5.0)
	for i in n:
		s.box(Vector3(x1 + 2.5 + 5.0 * float(i), y, TOP + h + 1.0), Vector3(1.4, thick * 0.9, 1.2), wall)

static func _side_wall(s: MobArt.Scene3, x: float, y1: float, y2: float, h: float, wall: Array) -> void:
	s.box(Vector3(x, (y1 + y2) * 0.5, TOP + h * 0.5), Vector3(2.2, (y2 - y1) * 0.5, h * 0.5), wall)

static func _gate(s: MobArt.Scene3, x: float, y: float, w: float, h: float) -> void:
	s.box(Vector3(x, y + 0.4, TOP + h * 0.5), Vector3(w * 0.5, 0.6, h * 0.5), _dark)
	s.cyl(Vector3(x, y + 0.4, TOP + h), w * 0.5, 0.5, _dark)

static func _flagpole(s: MobArt.Scene3, x: float, y: float, apex: float) -> void:
	s.box(Vector3(x, y, apex + 3.5), Vector3(0.45, 0.45, 4.5), _wood)

static func _tree(s: MobArt.Scene3, x: float, y: float, sc: float) -> void:
	s.box(Vector3(x, y, TOP + 2.2 * sc), Vector3(0.9 * sc, 0.9 * sc, 2.2 * sc), _wood)
	s.ell(Vector3(x, y, TOP + 6.0 * sc), Vector3(4.2 * sc, 4.2 * sc, 4.6 * sc), _leaf)

static func paint(tier: int) -> MobArt.Cv:
	_pals()
	var s := MobArt.Scene3.new(0.0)
	s.lt = Vector3(-0.5, 0.5, 0.7).normalized()          # light from the upper left and the front, so the walls facing us are lit
	_island(s, _leaf if tier < 3 else _P(["0c2214", "16402a", "226e3c", "34a04c", "5ccc6c"]))
	match tier:
		0:
			_tree(s, -33, 8, 1.0)
			_tree(s, 31, -6, 1.1)
			_house(s, -17, 7, 11, 9, 8, _sand, _red)
			_house(s, 17, 9, 12, 10, 9, _sand, _red)
			_house(s, -1, -9, 15, 12, 13, _sand, _red)
			_flagpole(s, -1, -9, 25.4)
		1:
			_wall(s, -34, 34, 22, 7, _stone)
			_side_wall(s, -34, -14, 22, 7, _stone)
			_side_wall(s, 34, -14, 22, 7, _stone)
			_wall(s, -34, 34, -14, 7, _stone)
			_gate(s, 0, 24.2, 8, 8)
			_house(s, -22, 8, 12, 10, 8, _sand, _red)
			_house(s, 22, 8, 12, 10, 8, _sand, _red)
			_tower(s, 0, -6, 8.5, 34, _stone, _blue, 15)
			_flagpole(s, 0, -6, 54.6)
		2:
			_wall(s, -34, 34, 22, 11, _stone)
			_side_wall(s, -34, -16, 22, 11, _stone)
			_side_wall(s, 34, -16, 22, 11, _stone)
			_wall(s, -34, 34, -16, 11, _stone)
			_gate(s, 0, 24.2, 9, 10)
			for p: Vector2 in [Vector2(-34, 22), Vector2(34, 22), Vector2(-34, -16), Vector2(34, -16)]:
				_tower(s, p.x, p.y, 6.0, 30, _stone, _blue, 12)
			_tower(s, -16, 2, 5.5, 36, _stone, _blue, 12)
			_tower(s, 16, 2, 5.5, 36, _stone, _blue, 12)
			_tower(s, 0, -4, 10.0, 48, _stone, _blue, 20)
			_flagpole(s, 0, -4, 73.6)
			_flagpole(s, -34, 22, 47.6)
			_flagpole(s, 34, 22, 47.6)
		3:
			var st := _dstone
			_wall(s, -36, 36, 22, 14, st, 2.8)
			_side_wall(s, -36, -18, 22, 14, st)
			_side_wall(s, 36, -18, 22, 14, st)
			_wall(s, -36, 36, -18, 14, st, 2.8)
			_gate(s, 0, 24.8, 10, 11)
			for p: Vector2 in [Vector2(-36, 22), Vector2(36, 22), Vector2(-36, -18), Vector2(36, -18)]:
				_tower(s, p.x, p.y, 7.0, 40, st, _blue, 0.0)
			_tower(s, -18, 0, 6.0, 42, st, _blue, 14)
			_tower(s, 18, 0, 6.0, 42, st, _blue, 14)
			_tower(s, 0, -4, 11.0, 50, st, _blue, 22)
			# cannons poking out of the front towers
			s.cap(Vector3(-36, 24, TOP + 36), Vector3(-42, 32, TOP + 33), 1.6, _dark)
			s.cap(Vector3(36, 24, TOP + 36), Vector3(42, 32, TOP + 33), 1.6, _dark)
			_flagpole(s, 0, -4, 77.6)
			_flagpole(s, -18, 0, 61.6)
			_flagpole(s, 18, 0, 61.6)
		_:
			var st := _stone
			_wall(s, -36, 36, 22, 14, st, 2.8)
			_side_wall(s, -36, -18, 22, 14, st)
			_side_wall(s, 36, -18, 22, 14, st)
			_wall(s, -36, 36, -18, 14, st, 2.8)
			s.box(Vector3(0, 22, TOP + 12.5), Vector3(36, 3.0, 0.7), _gold)         # gold band along the front wall
			_gate(s, 0, 24.8, 10, 11)
			for p: Vector2 in [Vector2(-36, 22), Vector2(36, 22), Vector2(-36, -18), Vector2(36, -18)]:
				_tower(s, p.x, p.y, 6.5, 44, st, _blue, 16)
			for sx: float in [-1.0, 1.0]:
				_tower(s, sx * 22.0, 2, 6.0, 56, st, _gold, 18)
				_tower(s, sx * 9.0, 12, 5.0, 40, st, _blue, 13)
			_tower(s, 0, -4, 11.0, 60, st, _gold, 26)
			_flagpole(s, 0, -4, 91.6)
			_flagpole(s, -22, 2, 79.6)
			_flagpole(s, 22, 2, 79.6)
	return s.render(W, H, GY)
