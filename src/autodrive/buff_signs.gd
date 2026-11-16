class_name BuffSigns
extends RefCounted
## What the player must be able to SEE and HEAR of each of the 25 buffs, read
## from the battle screen's own state (not from the sim): the buff's chip, the
## kind of figure that joins, the look the army wears, the effect of its
## event, the men on the field, and the cue the audio director got for that
## event. A buff with no entry here has no figure or event of its own; MOMENTS
## holds what the view shows for it instead (nothing is chip-only any more).
## Signs are `[kind, events, look, heads, state]`; -1 / "" / 0 mean none.

const K := SiegeSnapshot.Kind
const E = preload("res://src/core/siege_event.gd")
const NONE := -1

const SIGNS := {
	&"invisibility_potions": [NONE, [], &"", 0, SiegeSnapshot.State.HIDDEN],
	&"knight_armor": [NONE, [], &"knight", 0, NONE],
	&"double_men": [NONE, [], &"", 200, NONE],
	&"abduction": [K.UFO, [E.UFO_ABDUCT], &"", 0, NONE],
	&"stitched_monster": [K.MONSTER, [E.MONSTER_SMASH], &"", 0, NONE],
	&"wasps": [K.WASPS, [E.WASP_SWARM], &"", 0, NONE],
	&"medics": [K.MEDICS, [E.HEAL], &"", 0, NONE],
	&"shotgun": [K.SHOTGUNNER, [E.SHOTGUN_BLAST], &"", 0, NONE],
	&"emperor": [K.EMPEROR, [], &"", 0, NONE],
	&"fifty_men": [NONE, [], &"", 150, NONE],
	&"golf_carts": [K.GOLF_CARTS, [E.CART_CRASH], &"", 0, NONE],
	&"pumpkin_catapults": [K.CATAPULT, [E.PUMPKIN_LAUNCH, E.PUMPKIN_SPLAT], &"", 0, NONE],
	&"rock_band": [K.ROCK_BAND, [E.BAND_RIFF], &"", 0, NONE],
	&"football_helmets": [NONE, [], &"helmet", 0, NONE],
	&"moose": [K.MOOSE, [E.MOOSE_CHARGE], &"", 0, NONE],
	&"metal_bats": [K.BAT_MEN, [], &"", 0, NONE],
	&"trumpet_boy": [K.TRUMPET_BOY, [E.TRUMPET_CALL], &"", 0, NONE],
	&"booze": [NONE, [], &"booze", 0, NONE],
	&"pep_talk": [NONE, [E.PEP_TALK], &"", 0, NONE],
	&"cardboard_armor": [NONE, [], &"cardboard", 0, NONE],
}

## The view's own moments a buff must also show (BattleEffects.seen kinds):
## the buffs that were once only a chip, and the looks that were faint.
const MOMENTS := {
	&"stew": [&"badge", &"steam"],
	&"prep_hour": [&"clock"],
	&"prep_ten_minutes": [&"clock"],
	&"sleepless_village": [&"badge"],
	&"deaf_villagers": [&"badge"],
	&"double_men": [&"count"],
	&"fifty_men": [&"count"],
	&"knight_armor": [&"glint"],
	&"football_helmets": [&"glint"],
	&"cardboard_armor": [&"scrap"],
	&"booze": [&"hic"],
	&"metal_bats": [&"ping"],
}


static func is_stat_only(id: StringName) -> bool:
	return not SIGNS.has(id)


## Why the signs of `id` are not all on screen yet ("" when they are).
static func missing(battle: BattleScreen, id: StringName) -> String:
	if not battle.hud.chips.ids.has(id):
		return "no chip"
	for moment: StringName in MOMENTS.get(id, []):
		if int(battle.effects.seen.get(moment, 0)) == 0:
			return "no %s moment yet" % moment
	if is_stat_only(id):
		return ""
	var sign: Array = SIGNS[id]
	if sign[0] != NONE and not _kind_in_view(battle, sign[0]):
		return "no %s in view" % SiegeSnapshot.Kind.keys()[sign[0]]
	for event: StringName in sign[1]:
		if int(battle.effects.seen.get(event, 0)) == 0:
			return "no %s effect yet" % event
		var cue := AudioCues.for_event({"kind": event})
		if cue == &"" or int(AudioDirector.live().heard.get(cue, 0)) == 0:
			return "no %s cue yet" % event
	if sign[2] != &"" and not _look_applied(battle, sign[2]):
		return "the %s look is not on the men" % sign[2]
	if sign[3] > 0 and _army_heads(battle) != sign[3]:
		return "%d men on the field, want %d" % [_army_heads(battle), sign[3]]
	if sign[4] != NONE and not _army_state_seen(battle, sign[4]):
		return "no army squad in state %d" % sign[4]
	return ""


static func _kind_in_view(battle: BattleScreen, kind: int) -> bool:
	var window := Rect2(Vector2.ZERO, battle.size)
	for squad in battle.crowd.squads:
		if squad.kind == kind and squad.alive > 0:
			if window.has_point(battle.map_to_canvas(squad.anchor)):
				return true
	return false


static func _look_applied(battle: BattleScreen, look: StringName) -> bool:
	var worn := battle.crowd.look
	var on: bool = {
		&"knight": worn.knight,
		&"helmet": worn.helmet,
		&"cardboard": worn.cardboard,
		&"booze": worn.booze
	}[look]
	for squad in battle.crowd.squads:
		if squad.kind == K.MEN and squad.team == SiegeSnapshot.Team.ARMY:
			var sway: float = squad.material.get_shader_parameter("wobble")
			var dressed := squad.spec == FigureLibrary.spec(K.MEN, worn)
			return on and dressed and (look != &"booze" or sway > 0.0)
	return false


static func _army_heads(battle: BattleScreen) -> int:
	var heads := 0
	for i in battle.shot.entity_count():
		if battle.shot.ent_team[i] == SiegeSnapshot.Team.ARMY and battle.shot.ent_kind[i] == K.MEN:
			heads += battle.shot.ent_count[i]
	return heads


static func _army_state_seen(battle: BattleScreen, state: int) -> bool:
	for squad in battle.crowd.squads:
		if squad.team == SiegeSnapshot.Team.ARMY and squad.state == state and squad.alive > 0:
			return true
	return false
