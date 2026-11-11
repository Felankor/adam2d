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

# Called every frame by the owner. bob is the vertical hover offset in world pixels.
func update_look(tier: int, r: float, hurt: float, tm: float, bob: float, drop: float) -> void:
	if _vp == null:
		return
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
	draw_circle(Vector2.ZERO, _shadow_r * 1.2 * (1.0 - _bob / (_shadow_r * 6.0)), Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
