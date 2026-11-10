class_name CoinTex
extends RefCounted

# A small gold coin icon drawn in code (Mario/Sonic style), used instead of the word "coins".
static var _tex: ImageTexture

static func get_texture() -> ImageTexture:
	if _tex == null:
		_tex = _make()
	return _tex

static func _make() -> ImageTexture:
	var w := 32
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	for y in w:
		for x in w:
			var nx := (x + 0.5 - 16.0) / 15.0
			var ny := (y + 0.5 - 16.0) / 15.5
			var r2 := nx * nx + ny * ny
			if r2 > 1.0:
				continue
			var col := Color(1.0, 0.84, 0.18)
			if r2 > 0.90:
				col = Color(0.55, 0.33, 0.02)
			elif r2 > 0.66:
				col = Color(0.85, 0.58, 0.08)
			elif absf(nx) < 0.15 and absf(ny) < 0.5:
				col = Color(0.85, 0.6, 0.1)
			elif nx < -0.1 and ny < -0.1 and r2 < 0.45:
				col = Color(1.0, 0.95, 0.55)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
