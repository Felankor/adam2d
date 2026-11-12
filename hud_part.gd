class_name HudPart
extends Control

# One movable piece of the HUD. It is as big as the HUD canvas, so the Hud can draw an element with its normal
# coordinates; the HUD editor only moves / scales / fades this node.
var hud: Hud
var id: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if hud != null:
		hud.draw_part(id, self)
