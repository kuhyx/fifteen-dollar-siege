class_name BuffCard
extends Button
## One buff in the shop: its pictogram over its price as coin slots. A ghost
## coin per dollar while it is for sale, gold coins once they have landed, a
## green frame and a check when bought, dimmed when the dollars left do not
## reach. No words: the source sentence is the accessibility label only.
## The bot, the tests and the dev tools read `def`, `bought`, `out_of_reach`.

const SIZE := Vector2(160, 160)
const ART := Rect2(30, 8, 100, 100)
const COIN_PX := 24.0
const COIN_GAP := 4.0
const SHAKE_S := 0.3
const POP_S := 0.2
## How far a card out of reach is mixed toward its panel.
const DIM := 0.66

var def: BuffDef
var bought := false:
	set(value):
		bought = value
		queue_redraw()
## Cannot be bought with the dollars left (drawn dim; a click is refused).
var out_of_reach := false:
	set(value):
		out_of_reach = value
		queue_redraw()
## On show in the preview (hovered, tapped once or focused): a light frame.
var shown := false:
	set(value):
		shown = value
		queue_redraw()
## Price slots holding a gold coin right now.
var coins_in := 0:
	set(value):
		coins_in = value
		queue_redraw()

var _shake_left := 0.0
var _from_touch := false


static func make(p_def: BuffDef) -> BuffCard:
	var card := BuffCard.new()
	card.def = p_def
	card.name = "Card_%s" % p_def.id
	card.custom_minimum_size = SIZE
	card.size = SIZE
	card.pivot_offset = SIZE / 2.0
	card.accessibility_name = p_def.source_text
	card.add_theme_stylebox_override("normal", GlyphButton.box(Palette.PANEL))
	card.add_theme_stylebox_override("hover", GlyphButton.box(Palette.PANEL_HOVER))
	card.add_theme_stylebox_override("pressed", GlyphButton.box(Palette.PANEL_PRESSED))
	card.add_theme_stylebox_override("focus", GlyphButton.box(Palette.CLEAR, Palette.INK))
	return card


## The refusal cue on the card: a short sideways shake, its coins flash red.
func shake() -> void:
	_shake_left = SHAKE_S
	set_process(true)


## A bounce: up for a buy, a dip for a sell.
func pop(up: bool) -> void:
	scale = Vector2.ONE * (1.12 if up else 0.9)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, POP_S).set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)


## Centre of price slot `index` on the canvas (coins fly to and from it).
func slot_center(index: int) -> Vector2:
	return get_global_transform() * _slot(index).get_center()


## True when the last press came from a finger (and forgets it).
func take_touch() -> bool:
	var was := _from_touch
	_from_touch = false
	return was


func _ready() -> void:
	set_process(false)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		_from_touch = click.device == InputEvent.DEVICE_ID_EMULATION
	elif event is InputEventKey or event is InputEventJoypadButton:
		_from_touch = false


func _process(delta: float) -> void:
	_shake_left = maxf(_shake_left - delta, 0.0)
	if _shake_left <= 0.0:
		set_process(false)
	queue_redraw()


func _slot(index: int) -> Rect2:
	var row := def.price * COIN_PX + (def.price - 1) * COIN_GAP
	var x := (size.x - row) / 2.0 + index * (COIN_PX + COIN_GAP)
	return Rect2(Vector2(x, size.y - COIN_PX - 14.0), Vector2.ONE * COIN_PX)


func _draw() -> void:
	var sway := Vector2(sin(_shake_left * 60.0) * 7.0 * (_shake_left / SHAKE_S), 0.0)
	var dim := out_of_reach and not bought
	var art := Rect2(ART.position + sway, ART.size)
	BuffPictograms.of(def.id).draw(self, art, DIM if dim else 0.0, Palette.PANEL)
	var coin := UiPictograms.of(&"coin")
	for i in def.price:
		var box := _slot(i)
		box.position += sway
		if i < coins_in:
			coin.draw(self, box)
		elif _shake_left > 0.0:
			coin.draw_flat(self, box, Palette.BAD)
		else:
			coin.draw(self, box, 0.82 if dim else 0.55, Palette.PANEL)
	if bought:
		draw_style_box(GlyphButton.box(Palette.CLEAR, Palette.GOOD), Rect2(Vector2.ZERO, size))
		UiPictograms.of(&"check").draw(self, Rect2(size.x - 44.0, 8.0, 34.0, 34.0))
	elif shown:
		draw_style_box(GlyphButton.box(Palette.CLEAR, Palette.DIM), Rect2(Vector2.ZERO, size))
