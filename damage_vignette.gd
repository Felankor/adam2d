class_name DamageVignette
extends Control

# Red glow around the screen edges and corners that fades out smoothly when the base is hit.
var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0

func flash(strength: float = 1.0) -> void:
	if _tween != null:
		_tween.kill()
	modulate.a = clampf(strength, 0.0, 1.0)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var s := Settings.WORLD_SIZE
	var d := 280.0
	var edge := Color(0.9, 0.0, 0.0, 0.6)
	var clear := Color(0.9, 0.0, 0.0, 0.0)
	var cols := PackedColorArray([edge, edge, clear, clear])
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x - d, d), Vector2(d, d)]), cols)
	draw_polygon(PackedVector2Array([Vector2(0, s.y), Vector2(s.x, s.y), Vector2(s.x - d, s.y - d), Vector2(d, s.y - d)]), cols)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, s.y), Vector2(d, s.y - d), Vector2(d, d)]), cols)
	draw_polygon(PackedVector2Array([Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - d, s.y - d), Vector2(s.x - d, d)]), cols)
