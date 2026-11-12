class_name BackdropGrid
extends Node2D

# An endless battlefield: 3x3 copies of one Backdrop that follow the camera. The picture repeats
# seamlessly (no mirroring, so the light and shadows always fall the same way).
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
	Backdrop.request(biome)
	for t in _tiles:
		t.biome = biome
		t.queue_redraw()

# The terrain is built on a background thread; show it as soon as it is ready.
func _process(_delta: float) -> void:
	Backdrop.poll()
	for t in _tiles:
		t.refresh()

func follow(cam: Vector2) -> void:
	var size := Backdrop.SIZE * TILE_SCALE
	var cell := Vector2i(floori(cam.x / size.x), floori(cam.y / size.y))
	if cell == _cell:
		return
	_cell = cell
	var i := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := _tiles[i]
			i += 1
			t.scale = Vector2(TILE_SCALE, TILE_SCALE)
			t.position = Vector2(float(cell.x + dx) * size.x, float(cell.y + dy) * size.y)
