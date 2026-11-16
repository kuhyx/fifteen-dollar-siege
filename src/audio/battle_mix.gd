class_name BattleMix
extends RefCounted
## How loud each stem of the battle bed should be for the state of the siege.
## The bed is the player's meter with no needle: drums mean the village
## knows, the horn means the village is breaking, shaking low strings mean
## the army is. Pure arithmetic; MusicDeck glides toward these targets.
## Every threshold is a [design guess] (DOCS-audio.md).

## Index into AudioCues.STEMS.
enum { BASE, ALARM, HOPE, DREAD, ROCK }

## The alarm value where the drums start, and where they are at full level.
const ALARM_FROM := 0.05
const ALARM_FULL := 0.6
## Morale lost (1 - morale) where a side's layer starts and is at full level.
const LOST_FROM := 0.2
const LOST_FULL := 0.75
## The sneak's level under full drums, and every stem's under the band.
const BASE_UNDER_DRUMS := 0.55
const UNDER_BAND := 0.15
## How far one story (hope, dread) pushes the other down when both are told.
const RIVAL := 0.5


## Linear gains for [base, alarm, hope, dread, rock] from the snapshot's
## `alarm`, `army_morale`, `village_morale`, and whether the band is playing.
static func targets(alarm: float, army: float, village: float, rock: bool) -> PackedFloat32Array:
	var noticed := smoothstep(ALARM_FROM, ALARM_FULL, alarm)
	var hope := smoothstep(LOST_FROM, LOST_FULL, 1.0 - village)
	var dread := smoothstep(LOST_FROM, LOST_FULL, 1.0 - army)
	var out := PackedFloat32Array(
		[
			lerpf(1.0, BASE_UNDER_DRUMS, noticed),
			noticed,
			hope * (1.0 - RIVAL * dread),
			dread * (1.0 - RIVAL * hope),
			0.0,
		]
	)
	if rock:
		for layer in ROCK:
			out[layer] *= UNDER_BAND
		out[ROCK] = 1.0
	return out
