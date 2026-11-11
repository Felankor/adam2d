class_name BackdropGrid
extends Node2D

# An endless battlefield: 3x3 mirrored copies of one Backdrop that follow the
# camera. Mirroring every other tile keeps the colors and edges seamless.
const TILE_SCALE := 1.5

var _tiles: Array[Backdrop] = []
var _cell: Vector2i = Vector2i(1000000, 1000000)

func _init() -> void:
	for i in 9:
		var t := Backdrop.new()
		_tiles.append(t)
		add_child(t)

func _ready() -> void:
	add_to_group("backdrops")

func setup(biome: int) -> void:
	for t in _tiles:
		t.biome = biome
		t.queue_redraw()

func follow(cam: Vector2) -> void:
	var size := Backdrop.SIZE * TILE_SCALE
	var cell := Vector2i(floori(cam.x / size.x), floori(cam.y / size.y))
	if cell == _cell:
		return
	_cell = cell
	var i := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cx := cell.x + dx
			var cy := cell.y + dy
			var sx := -1.0 if (cx & 1) != 0 else 1.0
			var sy := -1.0 if (cy & 1) != 0 else 1.0
			var t := _tiles[i]
			i += 1
			t.scale = Vector2(sx, sy) * TILE_SCALE
			t.position = Vector2(float(cx) * size.x + (size.x if sx < 0.0 else 0.0), float(cy) * size.y + (size.y if sy < 0.0 else 0.0))
