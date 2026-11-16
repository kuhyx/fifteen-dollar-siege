class_name SiegeMods
extends RefCounted
## What a loadout changes, worked out once per siege: army-wide and village-wide
## factors plus which specials take the field. The systems read these fields and
## never ask the loadout again.

const B = preload("res://src/core/buff_tuning.gd")

# --- the army ---
var men := 100
## Break-point scale (strangers 0.6; drill, a leader and music raise it).
var cohesion := SiegeTuning.COHESION_STRANGERS
## Factor on every morale shock the army takes.
var shock := 1.0
var start_morale := SiegeTuning.ARMY_MORALE
## A bonus that fades over BuffTuning.PEP_FADE_S.
var pep := 0.0
var sling_acc := 1.0
var sling_range := SiegeTuning.SLING_RANGE_M
var melee := 1.0
## Factors on the damage the army takes.
var melee_hurt := 1.0
var ranged_hurt := 1.0
var friendly_hurt := 1.0
var friendly_fire := SiegeTuning.FRIENDLY_FIRE
var speed := 1.0
var tire := 1.0
## How much further off the army is noticed.
var noise := 1.0
var ignore_orders := 0.0
## Seconds the army is held at the start to be lined up.
var drill_s := 0.0
var cardboard := false
var invisible_squads := 0
var bat_squads := 0
var cart_squads := 0
var catapults := 0
var medic_squads := 0
var moose := 0
var shotgun := false
var emperor := false
var trumpet := false
var band := false
var monster := false
var wasps := false

# --- the village ---
var abducted := 0
var village_morale := SiegeTuning.VILLAGE_MORALE
var village_fatigue := 0.0
## Factor on the distance at which the village notices the army.
var detect := 1.0
## Factor on the time the alarm needs to spread, and squads need to arm.
var spread := 1.0
var reaction := 1.0
var bow_acc := 1.0
var deaf_share := 0.0


static func of(loadout: Loadout) -> SiegeMods:
	var m := SiegeMods.new()
	m.read(loadout)
	return m


## Fills every field from `loadout` (call once, on a fresh object).
func read(loadout: Loadout) -> void:
	men = SiegeSim.army_size(loadout)
	_size_and_drill(loadout)
	_body(loadout)
	_village(loadout)
	_specials(loadout)


func _size_and_drill(loadout: Loadout) -> void:
	if loadout.has(&"fifty_men"):
		cohesion *= B.FIFTY_COHESION
		noise *= B.FIFTY_NOISE
	if loadout.has(&"double_men"):
		cohesion *= B.DOUBLE_COHESION
		noise *= B.DOUBLE_NOISE
	if loadout.has(&"prep_hour"):
		cohesion *= B.PREP_HOUR_COHESION
		shock *= B.PREP_HOUR_SHOCK
		sling_acc *= B.PREP_HOUR_ACC
	if loadout.has(&"prep_ten_minutes"):
		cohesion *= B.PREP_TEN_COHESION
		sling_acc *= B.PREP_TEN_ACC
	if loadout.has(&"pep_talk"):
		pep = B.PEP_MORALE
	if loadout.has(&"emperor"):
		emperor = true
		cohesion *= B.EMPEROR_COHESION
		drill_s = B.EMPEROR_DRILL_S
	if loadout.has(&"trumpet_boy"):
		trumpet = true
		noise *= B.TRUMPET_NOISE
	if loadout.has(&"rock_band"):
		band = true
		cohesion *= B.BAND_COHESION


func _body(loadout: Loadout) -> void:
	if loadout.has(&"booze"):
		shock *= B.BOOZE_SHOCK
		sling_acc *= B.BOOZE_ACC
		melee *= B.BOOZE_MELEE
		friendly_fire *= B.BOOZE_FRIENDLY_FIRE
		ignore_orders = B.BOOZE_IGNORE
		start_morale += B.BOOZE_MORALE
	if loadout.has(&"stew"):
		tire *= B.STEW_TIRE
		start_morale += B.STEW_MORALE
	if loadout.has(&"knight_armor"):
		speed *= B.KNIGHT_SPEED
		tire *= B.KNIGHT_TIRE
		melee_hurt *= B.KNIGHT_MELEE_HURT
		shock *= B.KNIGHT_SHOCK
		ranged_hurt *= B.KNIGHT_RANGED_HURT
		sling_acc *= B.KNIGHT_ACC
	if loadout.has(&"football_helmets"):
		melee_hurt *= B.HELMET_MELEE_HURT
		ranged_hurt *= B.HELMET_RANGED_HURT
		friendly_hurt *= B.HELMET_FRIENDLY_HURT
		shock *= B.HELMET_SHOCK
		sling_range *= B.HELMET_SLING_RANGE
	if loadout.has(&"cardboard_armor"):
		cardboard = true
		start_morale += B.CARDBOARD_MORALE


func _village(loadout: Loadout) -> void:
	if loadout.has(&"abduction"):
		abducted = B.ABDUCTED
		village_morale += B.ABDUCT_MORALE
		detect *= B.ABDUCT_DETECT
	if loadout.has(&"deaf_villagers"):
		deaf_share = B.DEAF_SHARE
		spread *= B.DEAF_SPREAD
	if loadout.has(&"sleepless_village"):
		detect /= B.SLEEPLESS_DETECT
		reaction *= B.SLEEPLESS_REACTION
		spread *= B.SLEEPLESS_REACTION
		bow_acc *= B.SLEEPLESS_ACC
		village_fatigue = B.SLEEPLESS_FATIGUE


func _specials(loadout: Loadout) -> void:
	if loadout.has(&"invisibility_potions"):
		invisible_squads = B.INVISIBLE_SQUADS
	if loadout.has(&"metal_bats"):
		bat_squads = 1
	if loadout.has(&"golf_carts"):
		cart_squads = B.CART_SQUADS
		noise *= B.CART_NOISE
	if loadout.has(&"pumpkin_catapults"):
		catapults = B.CATAPULTS
	if loadout.has(&"medics"):
		medic_squads = B.MEDIC_SQUADS
	if loadout.has(&"moose"):
		moose = B.MOOSE
	shotgun = loadout.has(&"shotgun")
	monster = loadout.has(&"stitched_monster")
	wasps = loadout.has(&"wasps")
