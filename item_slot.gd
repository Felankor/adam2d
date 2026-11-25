class_name ItemSlot
extends Control

# One square inventory slot: a dark inset box that holds a stack of one item (icon + count). Hover shows the item's
# details; the owner listens to `clicked` (left = 1, right = 2 mouse button index).
signal clicked(button: int)

const SLOT := 78.0

var item: String = ""
var count: int = 0
var _hot: bool = false
var _foot: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(SLOT, SLOT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(id: String, n: int, foot: String = "") -> void:
	item = id
	count = n
	_foot = foot
	if id != "":
		Tip.attach(self, Items.name_of(id), Items.desc_of(id) + "\n\n" + Items.drop_of(id), id, foot)
	queue_redraw()

func _ready() -> void:
	mouse_entered.connect(func() -> void:
		_hot = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hot = false
		queue_redraw())

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and item != "":
		var b := (ev as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_LEFT or b == MOUSE_BUTTON_RIGHT:
			clicked.emit(b)
			accept_event()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var edge := Color(1.0, 0.85, 0.3) if (_hot and item != "") else Color(0.5, 0.31, 0.14)
	draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.02, 0.015))
	draw_rect(Rect2(3, 3, w - 6, h - 6), edge)
	draw_rect(Rect2(6, 6, w - 12, h - 12), Color(0.1, 0.075, 0.055))
	# inset look: shadow along the top and left, a light edge along the bottom and right
	draw_rect(Rect2(6, 6, w - 12, 4), Color(0.045, 0.032, 0.024))
	draw_rect(Rect2(6, 6, 4, h - 12), Color(0.045, 0.032, 0.024))
	draw_rect(Rect2(6, h - 10, w - 12, 4), Color(0.2, 0.145, 0.095))
	draw_rect(Rect2(w - 10, 6, 4, h - 12), Color(0.2, 0.145, 0.095))
	if item == "":
		return
	var tint := Items.color_of(item)
	draw_rect(Rect2(10, 10, w - 20, h - 20), Color(tint.r, tint.g, tint.b, 0.16 if not _hot else 0.28))
	var isz := w - 26.0
	Icons.draw(self, item, Vector2(13, 11), isz / 64.0, false)
	if count > 1:
		PixelUI.text(self, Vector2(0, h - 11), "%d" % count, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, w - 9.0, 5)
