extends RefCounted
## The pinned checks of the quick balance gate (scripts/balance_gate.sh,
## tools/sim/balance_gate.gd). WRITTEN BY tools/sim/find_pins.gd from the
## balance search of sim SIM_HASH: after a tuning change run the search again
## and then find_pins.gd --write. Every check uses seeds 1000, 1001, ...
##   EMPTY     the empty loadout wins at most EMPTY_MAX_WINS of EMPTY_SEEDS (< 5 %)
##   BEST      the best loadout found wins BEST_MIN_WINS of BEST_SEEDS (85 %)
##   SAMPLE    SAMPLE loadouts of the random sample from SAMPLE_FROM on, one
##             siege each, win 25-45 %
##   CONTEXTS  buff -> a loadout without it; buying the buff on top wins more
##             of the first SEEDS sieges
##   COMMAND   the scripted commander wins at least COMMAND_MARGIN more of
##             COMMAND_SEEDS sieges of this loadout than Watch mode does

const SIM_HASH := "07d46f192f9a"
const SEEDS := 12
const EMPTY_SEEDS := 40
const EMPTY_MAX_WINS := 1
const BEST := "double_men+invisibility_potions+stitched_monster"
const BEST_SEEDS := 30
const BEST_MIN_WINS := 26
const SAMPLE := 40
const SAMPLE_FROM := 23
const SAMPLE_MIN_WINS := 10
const SAMPLE_MAX_WINS := 18
const CONTEXTS := {
	"invisibility_potions": "fifty_men",
	"knight_armor": "fifty_men",
	"double_men": "fifty_men",
	"abduction": "fifty_men",
	"stitched_monster": "double_men",
	"wasps": "double_men",
	"medics": "double_men",
	"deaf_villagers": "shotgun+trumpet_boy+wasps",
	"shotgun": "double_men",
	"emperor": "shotgun+trumpet_boy+wasps",
	"fifty_men": "double_men",
	"golf_carts": "abduction+football_helmets+prep_hour",
	"prep_hour": "double_men",
	"pumpkin_catapults": "shotgun+trumpet_boy+wasps",
	"rock_band": "double_men",
	"football_helmets": "double_men",
	"moose": "double_men",
	"metal_bats": "booze+cardboard_armor+double_men+fifty_men",
	"sleepless_village": "booze+cardboard_armor+double_men+fifty_men",
	"trumpet_boy": "booze+double_men+fifty_men+pep_talk",
	"booze": "shotgun+trumpet_boy+wasps",
	"pep_talk": "booze+cardboard_armor+double_men+fifty_men",
	"cardboard_armor": "invisibility_potions+knight_armor+pumpkin_catapults+stew",
	"stew": "booze+cardboard_armor+double_men+wasps",
	"prep_ten_minutes": "booze+cardboard_armor+deaf_villagers+golf_carts+pep_talk",
}
const COMMAND := "fifty_men+shotgun"
const COMMAND_SEEDS := 16
const COMMAND_MARGIN := 2
