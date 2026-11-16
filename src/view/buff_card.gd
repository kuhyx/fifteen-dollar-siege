class_name BuffCard
extends Button
## One buff on the loadout screen: a pictogram and its price as coins. No
## words: the source text is the accessibility label only. PLACEHOLDER art:
## every card shows the same star, tinted per card, until the art agent draws
## one pictogram per buff id.

const SIZE := Vector2(150, 150)
const COIN_PX := 22.0
const SHAKE_S := 0.3

var def: BuffDef
var bought := false:
	set(value):
		bought = value
		queue_redraw()
## Cannot be bought with the dollars left (drawn dim; a click shakes).
var out_of_reach := false:
	set(value):
		out_of_reach = value
		queue_redraw()

var _tint := Color.WHITE
var _shake_left := 0.0


static func make(p_def: BuffDef, index: int) -> BuffCard:
	var card := BuffCard.new()
	card.def = p_def
	card.name = "Card_%s" % p_def.id
	card.custom_minimum_size = SIZE
	card.accessibility_name = p_def.source_text
	card._tint = Color.from_hsv(fmod(index * 0.381966, 1.0), 0.45, 0.95)
	card.add_theme_stylebox_override("normal", GlyphButton.box(Palette.PANEL))
	card.add_theme_stylebox_override("hover", GlyphButton.box(Palette.PANEL_HOVER))
	card.add_theme_stylebox_override("pressed", GlyphButton.box(Palette.PANEL_PRESSED))
	card.add_theme_stylebox_override("focus", GlyphButton.box(Palette.PANEL_HOVER, Palette.INK))
	return card


## The refusal cue: a short sideways shake and a red flash (no words).
func shake() -> void:
	_shake_left = SHAKE_S
	set_process(true)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_shake_left = maxf(_shake_left - delta, 0.0)
	if _shake_left <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var sway := sin(_shake_left * 60.0) * 8.0 * (_shake_left / SHAKE_S)
	var fade := 0.35 if out_of_reach and not bought else 1.0
	var art := Rect2(Vector2(size.x / 2.0 - 42.0 + sway, 14.0), Vector2(84, 84))
	var tint := Palette.BAD if _shake_left > 0.0 else _tint
	draw_texture_rect(Glyphs.texture(&"buff"), art, false, Color(tint, fade))
	var row := def.price * COIN_PX + (def.price - 1) * 4.0
	var x := size.x / 2.0 - row / 2.0 + sway
	for i in def.price:
		var coin := Rect2(
			Vector2(x + i * (COIN_PX + 4.0), size.y - COIN_PX - 14.0), Vector2.ONE * COIN_PX
		)
		draw_texture_rect(Glyphs.texture(&"coin"), coin, false, Color(Palette.COIN, fade))
	if bought:
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Palette.GOOD, false, 6.0)
		var mark := Rect2(Vector2(size.x - 44.0, 8.0), Vector2(36, 36))
		draw_texture_rect(Glyphs.texture(&"check"), mark, false, Palette.GOOD)
