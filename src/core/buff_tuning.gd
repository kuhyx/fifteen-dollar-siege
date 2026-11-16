class_name BuffTuning
extends RefCounted
## Numbers of the 25 buffs. Every constant has a row in DOCS-design-sim.md
## "Sources"; a value the research could not source is a [design guess] there.

# --- army size ---
## More strangers: cohesion factor and how much further off the column is noticed.
const FIFTY_COHESION := 0.97
const FIFTY_NOISE := 1.07
const DOUBLE_COHESION := 0.93
const DOUBLE_NOISE := 1.15

# --- prep time, speeches, drink, food ---
const PREP_HOUR_COHESION := 1.15
const PREP_HOUR_SHOCK := 0.95
const PREP_HOUR_ACC := 1.1
const PREP_TEN_COHESION := 1.03
const PREP_TEN_ACC := 1.03
const PEP_MORALE := 0.1
const PEP_FADE_S := 120.0
const BOOZE_SHOCK := 0.77
const BOOZE_ACC := 0.85
const BOOZE_MELEE := 0.95
const BOOZE_FRIENDLY_FIRE := 3.0
## Chance that a drunk squad ignores a new order.
const BOOZE_IGNORE := 0.25
const STEW_TIRE := 0.95

# --- armour ---
const KNIGHT_SPEED := 0.85
const KNIGHT_TIRE := 1.3
const KNIGHT_MELEE_HURT := 0.4
const KNIGHT_RANGED_HURT := 0.5
const KNIGHT_ACC := 0.9
const HELMET_MELEE_HURT := 0.8
const HELMET_RANGED_HURT := 0.75
const HELMET_FRIENDLY_HURT := 0.3
## Risk compensation: helmeted men stop to sling less often.
const HELMET_SLING_RANGE := 0.7
const CARDBOARD_HURT := 0.95
const CARDBOARD_S := 20.0
const CARDBOARD_MORALE := 0.03

# --- the village the night before ---
const ABDUCTED := 100
const ABDUCT_BEAM := 20
const ABDUCT_MORALE := -0.2
## A spooked village keeps watch: it notices from further off.
const ABDUCT_DETECT := 1.3
const DEAF_SHARE := 0.2
const DEAF_SPREAD := 1.3
## A deaf squad cannot hear its neighbours: no home-ground steadiness.
const DEAF_COHESION := 1.0
const DEAF_DELAY_MIN_S := 30.0
const DEAF_DELAY_MAX_S := 60.0
const SLEEPLESS_DETECT := 1.5
const SLEEPLESS_REACTION := 1.15
const SLEEPLESS_ACC := 0.9
const SLEEPLESS_FATIGUE := 0.1

# --- leaders and music ---
const EMPEROR_AURA := 0.11
const EMPEROR_COHESION := 1.1
const EMPEROR_DRILL_S := 4.0
const EMPEROR_FALL_SHOCK := 0.25
const TRUMPET_AURA := 0.08
const TRUMPET_PERIOD_S := 8.0
const TRUMPET_CALL := 0.03
const TRUMPET_RALLY := 0.1
const TRUMPET_M := 80.0
const TRUMPET_NOISE := 1.4
const TRUMPET_FALL_SHOCK := 0.15
const BAND_AURA := 0.08
const BAND_COHESION := 1.1
const BAND_PERIOD_S := 6.0
const BAND_HEADS := 5

# --- special weapons ---
const INVISIBLE_SQUADS := 5
const POTION_S := 75.0
const AMBUSH_SHOCK := 0.4
const AMBUSH_DAMAGE := 3.0
## Men who appear out of thin air startle everyone this near.
const REVEAL_M := 20.0
const REVEAL_FOE_SHOCK := 0.1
const REVEAL_FRIEND_SHOCK := 0.05
const BAT_MORALE := 0.25
const SHOTGUN_SHELLS := 50
const SHOTGUN_NEAR_M := 18.0
const SHOTGUN_FAR_M := 27.0
const SHOTGUN_NEAR_DOWN := 1.0
const SHOTGUN_FAR_DOWN := 0.4
const SHOTGUN_RELOAD_S := 4.0
const SHOTGUN_FEAR := 0.1
const SHOTGUN_FEAR_M := 150.0
const SHOTGUN_FEAR_S := 30.0
const SHOTGUN_FEAR_FLOOR := 0.02
const CATAPULTS := 2
const CATAPULT_CREW := 5
const CATAPULT_MIN_M := 50.0
const CATAPULT_MAX_M := 110.0
const CATAPULT_RELOAD_S := 8.0
const PUMPKIN_FLIGHT_S := 2.5
const PUMPKIN_SCATTER_M := 14.0
const PUMPKIN_SPLASH_M := 9.0
const PUMPKIN_DOWN := 0.4
const PUMPKIN_SHOCK := 0.12
## The crew holds its fire while a friend stands this near the target.
const PUMPKIN_SAFE_M := 14.0
const CART_SQUADS := 6
const CART_SPEED := 6.7
const CART_NOISE := 1.6
const CART_CRASH_DOWN := 1.0
const CART_CRASH_SHOCK := 0.15
const CART_CRASH_SELF := 0.1

# --- medics ---
const MEDIC_SQUADS := 2
const MEDIC_REACH_M := 30.0
const MEDIC_TOUCH_M := 8.0
const HEAL_S := 3.0
const HEAL_MORALE := 0.2

# --- creatures ---
const MONSTER_FEAR_M := 40.0
## Morale a village squad loses the first time it sees the monster up close.
const MONSTER_FEAR := 0.15
## Chance per decision that the monster turns on whoever is nearest.
const MONSTER_BERSERK := 0.04
const MONSTER_BERSERK_S := 3.0
const MOOSE := 3
const MOOSE_PICK_S := 4.0
const MOOSE_BLUFF := 0.3
const MOOSE_FRIENDLY := 0.15
const MOOSE_DOWN := 1.5
const MOOSE_SHOCK := 0.25
const MOOSE_CHARGES := 5
const MOOSE_REACH_M := 60.0
const WASPS := 300
const WASP_RELEASE_M := 35.0
const WASP_CLOUD_M := 10.0
const WASP_STING := 0.05
const WASP_HOP_S := 3.0
const WASP_HOP_M := 45.0
const WASP_LOSS_PER_S := 5
## Melee strength of a squad swatting at wasps.
const WASP_DAZE := 0.3
const UFO_SPEED := 20.0
