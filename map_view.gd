class_name MapView
extends Control

# A miniature of an expedition (the Map Table): the terrain colours of the region, the zones as dots (red and bigger =
# strong pack), the boss lair as a pulsing skull ring and your castle at the start. Locked maps are dimmed with a padlock.
# "dungeon" draws rings instead (endless waves). Hover it to read the details.

const BOX := Vector2(300.0, 168.0)
const PAL := {
	"greenland": [Color(0.17, 0.33, 0.16), Color(0.22, 0.42, 0.2), Color(0.12, 0.26, 0.4)],
	"mudland": [Color(0.27, 0.19, 0.12), Color(0.36, 0.25, 0.15), Color(0.2, 0.12, 0.1)],
	"mountains": [Color(0.3, 0.34, 0.4), Color(0.45, 0.5, 0.58), Color(0.85, 0.9, 0.95)],
	"hell": [Color(0.2, 0.06, 0.05), Color(0.32, 0.09, 0.06), Color(1.0, 0.45, 0.1)],
	"dungeon": [Color(0.1, 0.07, 0.18), Color(0.2, 0.12, 0.34), Color(0.7, 0.45, 1.0)],
}

var map_id: String = "greenland"
var locked: bool = false
var cleared: bool = false
var _t: float = 0.0
var _blobs: Array = []

func _init() -> void:
	custom_minimum_size = BOX
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(id: String, is_locked: bool, is_cleared: bool) -> void:
	map_id = id
	locked = is_locked
	cleared = is_cleared
	_t = float(MapRun.IDS.find(id)) * 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	_blobs.clear()
	for i in 22:
		_blobs.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.05, 0.14), rng.randi() % 3])
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _p(at: Vector2) -> Vector2:
	return size * 0.5 + Vector2(at.x / 6600.0 * size.x, at.y / 4800.0 * size.y)

func _draw() -> void:
	var pal: Array = PAL.get(map_id, PAL["greenland"])
	var a: Color = pal[0]
	var b: Color = pal[1]
	var c: Color = pal[2]
	draw_rect(Rect2(Vector2.ZERO, size), a)
	for bl: Array in _blobs:
		var pos: Vector2 = (bl[0] as Vector2) * size
		var r: float = float(bl[1]) * size.x
		match map_id:
			"mountains":
				var h := r * 1.3
				draw_colored_polygon(PackedVector2Array([pos + Vector2(-r, h * 0.5), pos + Vector2(0, -h * 0.5), pos + Vector2(r, h * 0.5)]), b)
				draw_colored_polygon(PackedVector2Array([pos + Vector2(-r * 0.3, -h * 0.2), pos + Vector2(0, -h * 0.5), pos + Vector2(r * 0.3, -h * 0.2)]), c)
			"hell":
				if int(bl[2]) == 0:
					PixelFx.line(self, pos, pos + Vector2(r * 1.4, r * 0.6), Color(c.r, c.g, c.b, 0.55 + 0.25 * sin(_t * 2.0 + pos.x)), 2.0)
				else:
					PixelFx.disc(self, pos, r * 0.8, b)
			"dungeon":
				pass
			_:
				PixelFx.disc(self, pos, r, c if int(bl[2]) == 2 and map_id == "greenland" else b)
	if map_id == "dungeon":
		for i in 4:
			var ph := fmod(_t * 0.5 + float(i) * 0.25, 1.0)
			PixelFx.ring(self, size * 0.5, 14.0 + ph * 120.0, Color(c.r, c.g, c.b, 0.55 * (1.0 - ph)), 3.0)
		PixelFx.disc(self, size * 0.5, 12.0, Color(c.r, c.g, c.b, 0.9))
		PixelFx.disc(self, size * 0.5, 6.0, Color(1, 1, 1, 0.9))
	else:
		var defs: Array = MapRun.zones_of(map_id)
		for i in defs.size():
			var d: Dictionary = defs[i]
			var strong := float(d["mult"]) > 1.0
			var pp := _p(d["at"] as Vector2)
			var pulse := 0.5 + 0.5 * sin(_t * 2.0 + float(i))
			var col := Color(1.0, 0.35, 0.3) if strong else Color(1.0, 0.85, 0.35)
			PixelFx.disc(self, pp, (7.0 if strong else 5.0) + pulse * 2.0, Color(col.r, col.g, col.b, 0.22))
			PixelFx.disc(self, pp, 4.0 if strong else 3.0, col)
		var bp := _p(MapRun.BOSS_AT[map_id] as Vector2)
		var bp_pulse := 0.5 + 0.5 * sin(_t * 3.0)
		PixelFx.ring(self, bp, 11.0 + bp_pulse * 4.0, Color(1.0, 0.3, 0.25, 0.8), 2.0)
		PixelFx.disc(self, bp, 8.0, Color(0.12, 0.05, 0.05))
		draw_rect(Rect2(bp + Vector2(-4, -4), Vector2(8, 6)), Color(0.95, 0.95, 0.9))
		draw_rect(Rect2(bp + Vector2(-3, -2), Vector2(2, 2)), Color(0.1, 0.05, 0.05))
		draw_rect(Rect2(bp + Vector2(1, -2), Vector2(2, 2)), Color(0.1, 0.05, 0.05))
		var cp := size * 0.5 + Vector2(0, sin(_t * 1.6) * 2.0)
		draw_rect(Rect2(cp + Vector2(-6, -5), Vector2(12, 10)), Color(0.12, 0.1, 0.05))
		draw_rect(Rect2(cp + Vector2(-5, -4), Vector2(10, 8)), Color(1.0, 0.85, 0.3))
	if cleared:
		draw_rect(Rect2(size.x - 28, 6, 22, 22), Color(0, 0, 0, 0.6))
		draw_line(Vector2(size.x - 24, 17), Vector2(size.x - 19, 23), Color(0.5, 1.0, 0.5), 3.0)
		draw_line(Vector2(size.x - 19, 23), Vector2(size.x - 10, 10), Color(0.5, 1.0, 0.5), 3.0)
	if locked:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.62))
		var m := size * 0.5
		draw_arc(m + Vector2(0, -10), 11.0, PI, TAU, 12, Color(0.75, 0.7, 0.6), 4.0)
		draw_rect(Rect2(m + Vector2(-16, -10), Vector2(32, 26)), Color(0.75, 0.7, 0.6))
		draw_rect(Rect2(m + Vector2(-3, -1), Vector2(6, 9)), Color(0.15, 0.12, 0.1))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.03), false, 4.0)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(0.75, 0.55, 0.2), false, 2.0)
