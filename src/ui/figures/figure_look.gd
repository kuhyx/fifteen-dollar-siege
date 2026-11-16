class_name FigureLook
extends RefCounted
## What the army wears, read from the loadout: the buffs a player can SEE on
## his men. Knight armour, football helmets and cardboard armour change the
## figure; booze makes it sway; metal bats arm the BAT_MEN.

var knight := false
var helmet := false
var cardboard := false
var booze := false
var bats := false


static func of(loadout: Loadout) -> FigureLook:
	var look := FigureLook.new()
	look.knight = loadout.has(&"knight_armor")
	look.helmet = loadout.has(&"football_helmets")
	look.cardboard = loadout.has(&"cardboard_armor")
	look.booze = loadout.has(&"booze")
	look.bats = loadout.has(&"metal_bats")
	return look


## The same key for two looks that draw the same figure.
func key() -> String:
	return "%d%d%d%d" % [int(knight), int(helmet), int(cardboard), int(booze)]


## How much the men sway (the crowd shader's `wobble`).
func wobble() -> float:
	return 1.0 if booze else 0.0
