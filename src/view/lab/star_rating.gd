class_name StarRating
extends RefCounted
## The stars of a won siege: one for the win, a second when the army was
## bought for at most TWO_AT dollars, a third for at most THREE_AT. A cheaper
## win is a harder one, so a win asks for "again, with less" and a loss for
## "a different fifteen dollars". [design guess]

const TWO_AT := 10
## Measured (30 random loadouts under each cap, 8 seeds each): at most 10
## dollars wins 15 % on average and 75 % at best; at most 6 dollars 3.8 % and
## 37.5 %; at most 5 dollars 0.8 % and 12.5 %: a third star at 5 would ask the
## near-impossible, at 6 it is hard but findable (golf carts and booze).
const THREE_AT := 6


## 0 for a loss, else 1 to 3.
static func of(outcome: int, loadout: Loadout) -> int:
	if outcome != SiegeSim.Outcome.WIN:
		return 0
	var spent := loadout.cost()
	return 3 if spent <= THREE_AT else (2 if spent <= TWO_AT else 1)


## The dollar cap the star `index` (0 to 2) asks for; -1 for the first (the win).
static func cap_of(index: int) -> int:
	return [-1, TWO_AT, THREE_AT][clampi(index, 0, 2)]
