class_name PictoInk
extends RefCounted
## The one palette every pictogram and vignette is drawn in: the game's own
## colours (Palette) plus the few hues the buffs need. A pictogram never
## invents a colour: tests/test_pictograms.gd checks every layer against `all`.

const LIGHT := Palette.INK
const GREY := Palette.DIM
## Dark detail on a light shape (eyes, slits). Close to the card, not black.
const DARK := Palette.PANEL
const GOLD := Palette.COIN
const BLUE := Palette.ARMY
const ORANGE := Palette.VILLAGE
const GREEN := Palette.GOOD
const RED := Palette.BAD
const WOOD := Palette.PICTO_WOOD
const VIOLET := Palette.VIOLET
## The shaded side of a coin, a flame's core.
const DEEP_GOLD := Palette.DEEP_GOLD
const SLATE := Palette.SLATE


static func all() -> Array[Color]:
	return [LIGHT, GREY, DARK, GOLD, BLUE, ORANGE, GREEN, RED, WOOD, VIOLET, DEEP_GOLD, SLATE]
