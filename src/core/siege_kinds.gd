class_name SiegeKinds
extends RefCounted
## What each SiegeSnapshot.Kind is in the fight, one table per number, indexed
## by the kind. Rows: MEN, VILLAGERS, MILITIA, RETINUE, ARCHERS, BAT_MEN,
## SHOTGUNNER, EMPEROR, TRUMPET_BOY, MEDICS, MONSTER, MOOSE, WASPS, GOLF_CARTS,
## CATAPULT, ROCK_BAND, UFO. Sources: DOCS-design-sim.md.

## Roles, as the SiegeState flags an entity of the kind starts with.
## A man who must stand for his side to hold, wavers, and can be aimed at:
const MAN := SiegeState.F_FIGHTER | SiegeState.F_WAVERS | SiegeState.F_TARGET
## A line squad: follows the default plan and the orders, carries slingshots.
const LINE := MAN | SiegeState.F_LINE | SiegeState.F_SLINGS
const AIMED_AT := SiegeState.F_TARGET

## Melee strength per head (a man with a wooden club = 1).
const MELEE: Array[float] = [
	1.0, 0.0, 1.3, 1.8, 0.6, 3.0, 0.6, 0.3, 0.0, 0.2, 22.0, 6.0, 0.0, 1.0, 0.5, 0.0, 0.0
]
## Blows it takes to put one head down (mail against clubs: 1 / 0.75).
const TOUGH: Array[float] = [
	1.0, 1.0, 1.0, 1.33, 1.0, 1.5, 1.0, 1.0, 1.0, 1.0, 12.0, 6.0, 1e9, 1.0, 1.0, 1.0, 1e9
]
## March speed in metres per second.
const SPEED: Array[float] = [
	3.4, 2.2, 3.2, 2.9, 3.2, 3.4, 3.4, 3.0, 3.2, 3.2, 3.0, 8.3, 6.0, 3.4, 2.0, 0.0, 20.0
]
## Nobody strikes the boy with the trumpet, the wasps or the UFO; the medics
## waver but are not counted among the fighters.
const ROLES: Array[int] = [
	LINE,
	0,
	MAN,
	MAN,
	MAN,
	LINE,
	MAN,
	AIMED_AT,
	0,
	3072,
	AIMED_AT,
	AIMED_AT,
	0,
	LINE,
	MAN,
	AIMED_AT,
	0
]


## The SiegeState flags an entity of this kind starts with.
static func flags(kind: int) -> int:
	return ROLES[kind]
