class_name CoinTex
extends RefCounted

# A small gold coin icon drawn in code (Mario/Sonic style), used instead of the word "coins".
static var _tex: ImageTexture

static func get_texture() -> ImageTexture:
	if _tex == null:
		_tex = _make()
	return _tex

static func _make() -> ImageTexture:
	# painted on a 16x16 pixel grid, shown twice as big
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var nx := (float(x) + 0.5 - 8.0) / 7.5
			var ny := (float(y) + 0.5 - 8.0) / 7.5
			var r2 := nx * nx + ny * ny
			if r2 > 1.0:
				continue
			var col := Color(1.0, 0.84, 0.18)
			if r2 > 0.80:
				col = Color(0.30, 0.17, 0.04)
			elif r2 > 0.58:
				col = Color(0.85, 0.58, 0.08) if (nx + ny) > -0.3 else Color(1.0, 0.92, 0.45)
			elif absf(nx) < 0.17 and absf(ny) < 0.45:
				col = Color(0.85, 0.6, 0.1)
			elif nx + ny < -0.45 and r2 < 0.5:
				col = Color(1.0, 0.96, 0.62)
			img.set_pixel(x, y, col)
	img.resize(32, 32, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)
