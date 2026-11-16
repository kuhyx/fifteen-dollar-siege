class_name BattleEffects
extends Node2D
## Every event of the siege, made visible. `spawn` turns one sim event into
## a live effect (a painter from the Fx* files, a life, a target) and into
## what it changes for longer: the rally flag, the centre ring, the flag on
## the church, a scattering or burning crowd. A name in SiegeEvent.ALL
## without a recipe (FxRecipes) fails tests/view/test_effects.gd. Lives inside the
## world node: map metres.

## Live effects at once: more than this and the oldest goes [design guess].
const MAX_LIVE := 72
## The effects measure their own drawing: over this many milliseconds a
## frame they shed the oldest short ones until they fit again, so a storm of
## events (or a slow machine) costs effects, never frames (lesson L12).
const DRAW_BUDGET_MS := 1.0
const MIN_LIVE := 12
## Effects longer than this are staged moments and are never shed.
const SHED_BELOW_S := 2.4
## Metres a shot looks for its target.
const DEFAULT_REACH := 60.0
## Real seconds for the win flag to climb its pole [design guess].
const FLAG_RISE_S := 1.4

## The latest snapshot: targets are found in it.
var shot := SiegeSnapshot.new()
var crowd: CrowdLayer
var live: Array[BattleFx] = []
## Where the rally flag stands (Vector2.INF: nowhere).
var rally := Vector2.INF
## 0..1 of the hold on the village centre.
var centre_progress := 0.0
## True once the army's flag is going up on the church.
var flag_up := false
var alarmed := false
## _draw calls so far (tests read it).
var draws := 0

var _plan: MapPlan
var _meter: FrameMeter
var _clock := 0.0
var _rally_age := 0.0
var _flag_raised := 0.0
var _spawned := 0
var _room := MAX_LIVE


static func handles(kind: StringName) -> bool:
	return FxRecipes.all().has(kind)


## Real seconds the effect of `kind` lasts (0 for an unknown one).
static func life_of(kind: StringName) -> float:
	return FxRecipes.all()[kind][1] if handles(kind) else 0.0


func setup(plan: MapPlan, p_crowd: CrowdLayer, meter: FrameMeter) -> void:
	_plan = plan
	crowd = p_crowd
	_meter = meter


## One sim event becomes one live effect, plus whatever it changes for longer.
func spawn(event: Dictionary) -> void:
	var kind: StringName = event.get("kind", &"")
	if not handles(kind):
		return
	var recipe: Array = FxRecipes.all()[kind]
	var fx := BattleFx.new()
	_spawned += 1
	fx.kind = kind
	fx.painter = recipe[0]
	fx.life = recipe[1]
	fx.pos = event.get("pos", Vector2.ZERO)
	fx.team = int(event.get("team", SiegeSnapshot.Team.ARMY))
	fx.seed_value = hash([kind, _spawned])
	fx.data = event
	fx.to = _aim(fx, recipe[2])
	_react(fx)
	live.append(fx)
	_shed()
	queue_redraw()


## Plants the rally flag at once (the screen calls it on the player's click;
## the sim's own `command` event confirms it a tick later).
func plant(at: Vector2) -> void:
	if rally != at:
		_rally_age = 0.0
	rally = at


## A soft ring at `at`: "click the map" (the rally button's hint).
func pulse(at: Vector2) -> void:
	var fx := BattleFx.new()
	fx.kind = &"hint"
	fx.painter = FxSignals.order
	fx.life = 0.9
	fx.pos = at
	fx.to = at
	live.append(fx)
	queue_redraw()


## Takes the effects of `kind` off the stage (a skipped beat).
func drop(kind: StringName) -> void:
	live = live.filter(func(fx: BattleFx) -> bool: return fx.kind != kind)
	queue_redraw()


func has_rally() -> bool:
	return rally != Vector2.INF


## 0..1 of the win flag's way up its pole.
func flag_raised() -> float:
	return _flag_raised


func clear() -> void:
	live.clear()
	queue_redraw()


## Ages everything by `delta` real seconds.
func advance(delta: float) -> void:
	_clock += delta
	_rally_age += delta
	if flag_up:
		_flag_raised = minf(_flag_raised + delta / FLAG_RISE_S, 1.0)
	for fx in live:
		fx.age += delta
	live = live.filter(func(fx: BattleFx) -> bool: return fx.age < fx.life)
	if not live.is_empty() or has_rally() or flag_up or centre_progress > 0.0:
		queue_redraw()


## Drops the oldest short effects until at most `_room` are live.
func _shed() -> void:
	var extra := live.size() - _room
	var kept: Array[BattleFx] = []
	for fx in live:
		if extra > 0 and fx.life < SHED_BELOW_S:
			extra -= 1
		else:
			kept.append(fx)
	live = kept


func _draw() -> void:
	draws += 1
	var started := Time.get_ticks_usec()
	if _meter != null:
		_meter.begin()
	if _plan != null:
		FxMarks.centre_ring(self, _plan.map.village_center, centre_progress)
	if has_rally():
		FxMarks.rally_flag(self, rally, _rally_age)
	for fx in live:
		fx.painter.call(self, fx)
	if flag_up and _plan != null:
		FxMarks.win_flag(self, _plan.bell, _flag_raised, _clock)
	if _meter != null:
		_meter.end()
	var took := (Time.get_ticks_usec() - started) / 1000.0
	if took > DRAW_BUDGET_MS:
		_room = maxi(MIN_LIVE, live.size() * 3 / 4)
		_shed()
	elif took < DRAW_BUDGET_MS / 2.0:
		_room = mini(_room + 1, MAX_LIVE)


## What the event changes beyond its own effect.
func _react(fx: BattleFx) -> void:
	match fx.kind:
		SiegeEvent.COMMAND:
			if int(fx.data.get("command", -1)) == SiegeSim.Command.RALLY:
				plant(fx.pos)
			else:
				rally = Vector2.INF
			fx.to = _middle(SiegeSnapshot.Team.ARMY, fx.pos)
		SiegeEvent.CENTRE_HELD:
			centre_progress = clampf(float(fx.data.get("progress", 0.0)), 0.0, 1.0)
		SiegeEvent.VICTORY:
			flag_up = true
			fx.pos = _plan.map.village_center if _plan != null else fx.pos
		SiegeEvent.ALARM:
			alarmed = true
		SiegeEvent.BELL_RING:
			fx.pos = _plan.bell if _plan != null else fx.pos
		SiegeEvent.PUMPKIN_SPLAT:
			fx.to = fx.data.get("from", fx.pos + Vector2(-60.0, 0.0))
		SiegeEvent.UFO_ABDUCT:
			if _plan != null:
				fx.data = {"bounds": _plan.map.bounds}
	if crowd == null:
		return
	match fx.kind:
		SiegeEvent.SQUAD_ROUT:
			crowd.scatter(fx.pos, fx.team)
		SiegeEvent.MONSTER_SMASH:
			crowd.scatter(fx.pos, 1 - fx.team)
		SiegeEvent.PEP_TALK:
			crowd.cheer(1.2)
		SiegeEvent.COMBUST:
			crowd.ignite(SiegeSnapshot.Team.ARMY)


## Where the effect points: the nearest enemy within `reach`, else straight
## at the other side's ground (the village for the army, the camp for it).
func _aim(fx: BattleFx, reach: float) -> Vector2:
	if reach <= 0.0:
		return fx.pos
	var best := Vector2.INF
	for i in shot.entity_count():
		if shot.ent_team[i] == fx.team or shot.ent_count[i] <= 0:
			continue
		var gap := shot.ent_pos[i].distance_to(fx.pos)
		if gap <= reach and gap < best.distance_to(fx.pos):
			best = shot.ent_pos[i]
	if best != Vector2.INF:
		return best
	var home := Vector2.ZERO
	if _plan != null:
		home = _plan.map.village_center if fx.team == SiegeSnapshot.Team.ARMY else _plan.camp
	return fx.pos + (home - fx.pos).limit_length(reach * 0.7)


## The middle of `team`'s entities (`fallback` when it has none).
func _middle(team: int, fallback: Vector2) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for i in shot.entity_count():
		if shot.ent_team[i] == team and shot.ent_count[i] > 0:
			sum += shot.ent_pos[i]
			count += 1
	return sum / count if count > 0 else fallback
