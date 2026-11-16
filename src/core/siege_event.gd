class_name SiegeEvent
extends RefCounted
## Names of the events a SiegeSnapshot carries in `events` (`kind` field).
## Frozen contract between the sim (emits), the view (VFX) and the audio
## director (SFX): add new names here first, never rename one.
## Every event is {kind: StringName, pos: Vector2, ...optional data}.

## The player gave an order. Data: `command` (SiegeSim.Command).
const COMMAND := &"command"
## The village noticed the army (first moment the alarm goes up).
const ALARM := &"alarm"
## The church bell rings while the alarm spreads.
const BELL_RING := &"bell_ring"

## Ranged and melee. Data: `team` (SiegeSnapshot.Team of the attacker).
const SLING_VOLLEY := &"sling_volley"
const ARROW_VOLLEY := &"arrow_volley"
const MELEE_CLASH := &"melee_clash"

## Squad morale. Data: `team`.
const SQUAD_ROUT := &"squad_rout"
const SQUAD_RALLY := &"squad_rally"
const SQUAD_WIPED := &"squad_wiped"

## Buff specials.
const SHOTGUN_BLAST := &"shotgun_blast"
const PUMPKIN_LAUNCH := &"pumpkin_launch"
## Data: `from` (Vector2 launch point) so the view can draw the arc.
const PUMPKIN_SPLAT := &"pumpkin_splat"
const HEAL := &"heal"
const WASP_SWARM := &"wasp_swarm"
const MOOSE_CHARGE := &"moose_charge"
const CART_CRASH := &"cart_crash"
const MONSTER_SMASH := &"monster_smash"
const TRUMPET_CALL := &"trumpet_call"
const BAND_RIFF := &"band_riff"
## An invisible squad became visible (it attacked or the potion ran out).
const REVEAL := &"reveal"

## Before the first tick: the night-before and prep beats, in order.
const UFO_ABDUCT := &"ufo_abduct"
const PEP_TALK := &"pep_talk"

## Progress of holding the village centre. Data: `progress` (0..1).
const CENTRE_HELD := &"centre_held"
## The siege ended.
const VICTORY := &"victory"
const COMBUST := &"combust"

## Every name above, for tests and for audio/VFX coverage checks.
const ALL: Array[StringName] = [
	COMMAND,
	ALARM,
	BELL_RING,
	SLING_VOLLEY,
	ARROW_VOLLEY,
	MELEE_CLASH,
	SQUAD_ROUT,
	SQUAD_RALLY,
	SQUAD_WIPED,
	SHOTGUN_BLAST,
	PUMPKIN_LAUNCH,
	PUMPKIN_SPLAT,
	HEAL,
	WASP_SWARM,
	MOOSE_CHARGE,
	CART_CRASH,
	MONSTER_SMASH,
	TRUMPET_CALL,
	BAND_RIFF,
	REVEAL,
	UFO_ABDUCT,
	PEP_TALK,
	CENTRE_HELD,
	VICTORY,
	COMBUST,
]
