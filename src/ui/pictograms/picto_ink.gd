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
const WOOD := Color(0.68, 0.48, 0.3)
const VIOLET := Color(0.68, 0.52, 0.96)
## The shaded side of a coin, a flame's core.
const DEEP_GOLD := Color(0.74, 0.55, 0.14)
const SLATE := Color(0.34, 0.37, 0.46)


static func all() -> Array[Color]:
	return [LIGHT, GREY, DARK, GOLD, BLUE, ORANGE, GREEN, RED, WOOD, VIOLET, DEEP_GOLD, SLATE]
