class_name PixelCastle
extends Node2D

# Gives the vector castle art a pixel-art look. BaseArt draws the castle into a tiny
# SubViewport (about 4 world pixels per pixel), then a shader limits the colours and
# adds a dark 1-pixel outline, and the result is shown with nearest-neighbour scaling.
# The hover bob moves in whole-pixel steps, like an old console game.
# Set ENABLED to false to go back to the smooth vector castle.
const ENABLED := true
const PIXEL := 4.0
const LEVELS := 7.0
const ART3D := true           # tiers 0-4 use the lit 3D castle models (CastleArt); false = the old vector castles

const SHADER_CODE := """
shader_type canvas_item;
uniform float levels = 7.0;
uniform vec4 outline_color : source_color = vec4(0.05, 0.04, 0.09, 1.0);
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) {
		float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (n > 0.9) {
			COLOR = outline_color;
		} else {
			COLOR = vec4(0.0);
		}
	} else {
		COLOR = vec4(floor(c.rgb * levels + 0.5) / levels, 1.0);
	}
}
"""

static var _material: ShaderMaterial

class Painter extends Node2D:
	var tier: int = 0
	var r: float = 60.0
	var tm: float = 0.0
	var hurt: float = 0.0
	func _draw() -> void:
		BaseArt.draw_all(self, tier, r, tm, hurt)

var _vp: SubViewport
var _painter: Painter
var _sprite: Sprite2D
var _tier: int = -1
var _r: float = -1.0
var _drop: float = 0.0
var _bob: float = 0.0
var _shadow_r: float = 0.0
var _spr3: Sprite2D
var _flags: FlagLayer
var _chains: ChainLayer
var _use3d: bool = false

# Waving flag cloth on top of the 3D castle (the poles are part of the model).
class FlagLayer extends Node2D:
	var tier: int = 0
	var s: float = 2.0
	var bob: float = 0.0
	var tm: float = 0.0
	func _draw() -> void:
		for f: Array in CastleArt.flags(tier):
			var p := CastleArt.screen_of(float(f[0]), float(f[1]), float(f[2]))
			var base := Vector2(p.x, 11.0 + p.y) * s + Vector2(0.0, bob)
			var col: Color = f[3]
			for i in 7:
				var wave := roundf(sin(tm * 5.0 + float(i) * 0.75) * 0.9 + float(i) * 0.12)
				var x := roundf(base.x + float(i) * s)
				var y := roundf(base.y + wave * s)
				draw_rect(Rect2(x, y, ceilf(s), ceilf(s * 2.0)), col.lightened(0.15))
				draw_rect(Rect2(x, y + ceilf(s * 2.0), ceilf(s), ceilf(s * 2.0)), col.darkened(0.22))
				draw_rect(Rect2(x, y - ceilf(s * 0.6), ceilf(s), ceilf(s * 0.6)), Color(0.05, 0.04, 0.09))
				draw_rect(Rect2(x, y + ceilf(s * 4.0), ceilf(s), ceilf(s * 0.6)), Color(0.05, 0.04, 0.09))

# Iron shackle chains hanging from the sides of the Eye of End; they sway and swing as the castle hovers.
class ChainLayer extends Node2D:
	var s: float = 2.0
	var bob: float = 0.0
	var tm: float = 0.0
	const ANCHORS := [[-86.0, 2.0, -4.0, -1.0], [86.0, 2.0, -4.0, 1.0], [-70.0, 48.0, -6.0, -1.0], [70.0, 48.0, -6.0, 1.0]]
	const LINKS := 14
	const OUT := Color(0.05, 0.03, 0.02)
	func _draw() -> void:
		for k in ANCHORS.size():
			var a: Array = ANCHORS[k]
			var p := CastleArt.screen_of(float(a[0]), float(a[1]), float(a[2]))
			var base := Vector2(p.x, 11.0 + p.y) * s + Vector2(0.0, bob)
			var sg: float = a[3]
			var ph := float(k) * 1.7
			var last := base
			for i in LINKS + 1:
				var t := float(i) / float(LINKS)
				var sway := sin(tm * 1.3 + ph + t * 2.2) * t * 4.0 + sin(tm * 0.7 + ph) * t * t * 3.0
				var pos := base + Vector2((t * 8.0 * sg + sway) * s, t * 62.0 * s + sin(tm * 1.6 + ph) * t * 2.0 * s)
				pos = Vector2(roundf(pos.x / s) * s, roundf(pos.y / s) * s)
				var vert := i % 2 == 0
				var w := (2.0 if vert else 4.0) * s
				var h := (4.0 if vert else 2.0) * s
				var r := Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h))
				draw_rect(r.grow(s * 0.6), OUT)
				draw_rect(r, Color(0.42, 0.3, 0.16) if vert else Color(0.3, 0.2, 0.1))
				draw_rect(Rect2(r.position, Vector2(s, r.size.y)) if vert else Rect2(r.position, Vector2(r.size.x, s)), Color(0.78, 0.58, 0.24))
				last = pos
			# open iron cuff with a bolt at the end
			var c := last + Vector2(0.0, 5.0 * s)
			draw_arc(c, 5.0 * s, 0.0, TAU, 14, OUT, s * 3.2)
			draw_arc(c, 5.0 * s, 0.6, TAU - 0.6, 14, Color(0.55, 0.4, 0.2), s * 1.8)
			draw_rect(Rect2(c + Vector2(-s, -6.0 * s), Vector2(2.0 * s, 2.0 * s)), Color(0.85, 0.65, 0.25))

func _init() -> void:
	z_index = -1                # the owner must have z_index = 1, so this lands on the normal layer

func _ready() -> void:
	if _material == null:
		var sh := Shader.new()
		sh.code = SHADER_CODE
		_material = ShaderMaterial.new()
		_material.shader = sh
		_material.set_shader_parameter("levels", LEVELS)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_painter = Painter.new()
	_painter.scale = Vector2(1.0 / PIXEL, 1.0 / PIXEL)
	_vp.add_child(_painter)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.material = _material
	_sprite.scale = Vector2(PIXEL, PIXEL)
	add_child(_sprite)
	_sprite.texture = _vp.get_texture()
	_spr3 = Sprite2D.new()
	_spr3.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr3.visible = false
	add_child(_spr3)
	_flags = FlagLayer.new()
	_flags.visible = false
	add_child(_flags)
	_chains = ChainLayer.new()
	_chains.visible = false
	add_child(_chains)

# Called every frame by the owner. bob is the vertical hover offset in world pixels.
func update_look(tier: int, r: float, hurt: float, tm: float, bob: float, drop: float) -> void:
	if _vp == null:
		return
	if ART3D and tier < CastleArt.TIERS:
		_update_3d(tier, r, hurt, tm, bob, drop)
		return
	if _use3d:
		_use3d = false
		_spr3.visible = false
		_flags.visible = false
		_chains.visible = false
		_sprite.visible = true
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_tier = -1
	if tier != _tier or not is_equal_approx(r, _r):
		_tier = tier
		_r = r
		var n := int(ceil(r * 5.6 / PIXEL))
		_vp.size = Vector2i(n, n)
		_painter.position = Vector2(float(n) * 0.5, float(n) * 0.5)
		_painter.r = r
		_painter.tier = tier
	_painter.hurt = hurt
	_painter.tm = tm
	_painter.queue_redraw()
	_bob = roundf(bob / PIXEL) * PIXEL
	_sprite.position = Vector2(0.0, _bob)
	_drop = drop
	_shadow_r = r
	queue_redraw()

func _draw() -> void:
	if _shadow_r <= 0.0:
		return
	# the shadow stays on the ground and shrinks as the castle rises
	draw_set_transform(Vector2(6.0, _drop), 0.0, Vector2(1.0, 0.28))
	PixelFx.disc(self, Vector2.ZERO, _shadow_r * 1.2 * (1.0 - _bob / (_shadow_r * 6.0)), Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# One lit 3D model per tier, painted once and then only scaled, bobbed and tinted.
func _update_3d(tier: int, r: float, hurt: float, tm: float, bob: float, drop: float) -> void:
	if not _use3d:
		_use3d = true
		_sprite.visible = false
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_spr3.visible = true
		_flags.visible = true
	var tex: Texture2D = CastleArt.tex(tier)
	if _spr3.texture != tex:
		_spr3.texture = tex
		_spr3.offset = Vector2(0.0, 11.0 - (CastleArt.top_row() - float(CastleArt.H) * 0.5))
	var sc := r / 48.0                   # one art pixel on screen
	_spr3.scale = Vector2(sc, sc)
	_bob = roundf(bob / sc) * sc
	_spr3.position = Vector2(0.0, _bob)
	_spr3.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.3, 0.3), clampf(hurt, 0.0, 1.0) * 0.6)
	_flags.tier = tier
	_flags.s = sc
	_flags.bob = _bob
	_flags.tm = tm
	_flags.queue_redraw()
	_chains.visible = tier == CastleArt.TIERS - 1
	if _chains.visible:
		_chains.s = sc
		_chains.bob = _bob
		_chains.tm = tm
		_chains.queue_redraw()
	_drop = drop
	_shadow_r = r
	queue_redraw()
