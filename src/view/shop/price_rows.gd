class_name PriceRows
extends Control
## The shop's shelves: one band per price, 5 dollars at the top down to 1,
## each marked at its left end with a pile of that many coins. The cards of a
## price stand on its band, so the grouping reads from the layout alone.

const CARD := BuffCard.SIZE
const CARD_GAP := 14.0
const ROW_PITCH := 181.0
const TAB_W := 64.0
const BAND_PAD := 8.0
const COIN_PX := 26.0

## Price -> cards on that band so far.
var _taken: Dictionary = {}
## Price -> cards the band has to hold.
var _room: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for def in BuffCatalog.all():
		_room[def.price] = int(_room.get(def.price, 0)) + 1


## Where the next card of `price` stands, in this control's space.
func next_spot(price: int) -> Vector2:
	var column: int = _taken.get(price, 0)
	_taken[price] = column + 1
	return Vector2(TAB_W + BAND_PAD + column * (CARD.x + CARD_GAP), row_top(price))


## Top of the cards of `price`: the dearest row is first.
func row_top(price: int) -> float:
	return BAND_PAD + (_dearest() - price) * ROW_PITCH


## The band of `price` behind its cards.
func band(price: int) -> Rect2:
	var cards: int = _room.get(price, 0)
	var wide := TAB_W + 2.0 * BAND_PAD + cards * (CARD.x + CARD_GAP) - CARD_GAP
	return Rect2(0, row_top(price) - BAND_PAD, wide, CARD.y + 2.0 * BAND_PAD)


func _dearest() -> int:
	var top := 0
	for price: int in _room:
		top = maxi(top, price)
	return top


func _draw() -> void:
	var coin := UiPictograms.of(&"coin")
	var shelf := GlyphButton.box(Palette.PANEL.darkened(0.3))
	for price: int in _room:
		var box := band(price)
		draw_style_box(shelf, box)
		var pile_h := COIN_PX + (price - 1) * COIN_PX * 0.55
		var top := box.get_center().y - pile_h / 2.0
		for i in price:
			var corner := Vector2(
				(TAB_W - COIN_PX) / 2.0 + 4.0, top + (price - 1 - i) * COIN_PX * 0.55
			)
			coin.draw(self, Rect2(corner, Vector2.ONE * COIN_PX))
