class_name CoinTray
extends Control
## The budget you can see without reading: fifteen slots in a tray. A dollar
## not spent is a gold coin, a spent one leaves an empty hole, so the tray
## empties from the right as you buy. A refused buy shakes the tray and turns
## its rim red; nothing is ever written.

const COIN_PX := 52.0
const GAP := 10.0
const PAD := 22.0
const HIGH := 96.0
const SHAKE_S := 0.4

## Gold coins lying in the tray (the rest of the fifteen slots are holes).
var coins := Loadout.BUDGET:
	set(value):
		coins = clampi(value, 0, Loadout.BUDGET)
		queue_redraw()

var _shake_left := 0.0


static func wide() -> float:
	return Loadout.BUDGET * (COIN_PX + GAP) - GAP + 2.0 * PAD


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(wide(), HIGH)
	size = custom_minimum_size
	set_process(false)


## Centre of slot `index` (0 = leftmost) on the canvas.
func slot_center(index: int) -> Vector2:
	return get_global_transform() * _slot(index).get_center()


## The refusal: a sideways shake and a red rim, for SHAKE_S seconds.
func shake() -> void:
	_shake_left = SHAKE_S
	set_process(true)
	queue_redraw()


func is_shaking() -> bool:
	return _shake_left > 0.0


func _process(delta: float) -> void:
	_shake_left = maxf(_shake_left - delta, 0.0)
	if _shake_left <= 0.0:
		set_process(false)
	queue_redraw()


func _slot(index: int) -> Rect2:
	var x := PAD + index * (COIN_PX + GAP)
	return Rect2(Vector2(x, (size.y - COIN_PX) / 2.0), Vector2.ONE * COIN_PX)


func _draw() -> void:
	var sway := Vector2(sin(_shake_left * 55.0) * 12.0 * (_shake_left / SHAKE_S), 0.0)
	var rim := Palette.BAD if is_shaking() else Palette.PANEL_PRESSED
	var trough := GlyphButton.box(Palette.PANEL.darkened(0.25), rim)
	trough.set_corner_radius_all(roundi(size.y / 2.0))
	draw_style_box(trough, Rect2(sway, size))
	var coin := UiPictograms.of(&"coin")
	var hole := UiPictograms.of(&"slot")
	for i in Loadout.BUDGET:
		var box := _slot(i)
		box.position += sway
		if i < coins:
			coin.draw(self, box)
		else:
			hole.draw(self, box.grow(-6.0), 0.35, Palette.PANEL)
