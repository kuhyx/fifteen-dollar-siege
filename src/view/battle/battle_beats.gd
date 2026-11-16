class_name BattleBeats
extends RefCounted
## The staged moments around the siege. BEFORE the first tick: the sim's
## pre-battle events (the UFO the night before, the pep talk) play one after
## the other while the clock stands still, and each can be skipped. AFTER the
## decision: the payoff holds the screen for a while, so the flag on the
## church or the flames on the army are seen before the result opens.

signal beat_began(event: Dictionary)
## `skipped` is true when the player cut it short.
signal beat_ended(kind: StringName, skipped: bool)
signal payoff_done

## The events that are staged when they come before the first tick.
const STAGED: Array[StringName] = [SiegeEvent.UFO_ABDUCT, SiegeEvent.PEP_TALK]
## The map box the camera shows for a beat, around the event [design guess].
const FRAMES := {
	SiegeEvent.UFO_ABDUCT: Rect2(-86.0, -66.0, 172.0, 100.0),
	SiegeEvent.PEP_TALK: Rect2(-60.0, -48.0, 124.0, 88.0),
}
## Real seconds of the payoff nobody can skip: the moment is seen first.
const SKIP_AFTER_S := 0.3
## Metres around the army the lose payoff shows.
const ARMY_PAD_M := 30.0
## Metres around the church the win payoff shows [design guess].
const CHURCH_BOX := Rect2(-70.0, -62.0, 150.0, 96.0)
## The largest box church and army may share at a win: the auto camera's
## whole view [design guess].
const BOTH_MAX_M := Vector2(300.0, 170.0)

## Beats still to play, in the sim's order.
var queue: Array[Dictionary] = []
## The beat on stage ({} when none).
var current: Dictionary = {}

var _beat_left := 0.0
var _payoff_left := 0.0
var _payoff_total := 0.0
var _payoff_on := false


static func stages(event: Dictionary) -> bool:
	return STAGED.has(event.get("kind", &""))


func add(event: Dictionary) -> void:
	queue.append(event)


## True while a beat plays or waits: the sim must not step.
func staging() -> bool:
	return not current.is_empty() or not queue.is_empty()


## Plays the beats: starts the next one, ends the one whose time is up.
func update(delta: float) -> void:
	if current.is_empty():
		if queue.is_empty():
			return
		current = queue.pop_front()
		_beat_left = BattleEffects.life_of(current["kind"])
		beat_began.emit(current)
		return
	_beat_left -= delta
	if _beat_left <= 0.0:
		_end(false)


## Cuts the beat on stage short; the next one starts on the next frame.
func skip() -> void:
	if not current.is_empty():
		_end(true)


## Drops every beat still to come and cuts the one on stage short.
func skip_all() -> void:
	queue.clear()
	skip()


## The map box the camera should hold for the beat on stage (or, before the
## first one starts, for the beat that is next).
func beat_box() -> Rect2:
	var beat := current
	if beat.is_empty() and not queue.is_empty():
		beat = queue[0]
	var around: Rect2 = FRAMES.get(beat.get("kind", &""), Rect2(-150.0, -100.0, 300.0, 200.0))
	var at: Vector2 = beat.get("pos", Vector2.ZERO)
	return Rect2(at + around.position, around.size)


## Starts the payoff: `seconds` of show before `payoff_done`.
func start_payoff(seconds: float) -> void:
	_payoff_total = maxf(seconds, 0.001)
	_payoff_left = _payoff_total
	_payoff_on = true


## True when a press may cut the payoff short (it has had its first look).
func payoff_skippable() -> bool:
	return _payoff_on and _payoff_total - _payoff_left >= SKIP_AFTER_S


## Ends the payoff now: the result opens at once.
func skip_payoff() -> void:
	if _payoff_on:
		_payoff_left = 0.0
		tick_payoff(0.0)


## Any key, click, touch or pad button going down (not a key held down).
static func is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	return (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
		or (event is InputEventJoypadButton and event.pressed)
	)


func tick_payoff(delta: float) -> void:
	if not _payoff_on:
		return
	_payoff_left -= delta
	if _payoff_left <= 0.0:
		_payoff_on = false
		payoff_done.emit()


## 0 at the decision, 1 when the result may open.
func payoff_progress() -> float:
	if _payoff_total <= 0.0:
		return 0.0
	return clampf(1.0 - _payoff_left / _payoff_total, 0.0, 1.0)


## What the camera shows during the payoff: the army (what is left of it) at
## a loss; at a win the church with its flag AND the army that took it, when
## both fit one view (the village breaks wherever the army stands, often far
## from the church): the last blow is not cut away.
static func payoff_box(won: bool, plan: MapPlan, shot: SiegeSnapshot) -> Rect2:
	var army := _army_box(shot, won)
	if won:
		var church := Rect2(plan.bell + CHURCH_BOX.position, CHURCH_BOX.size)
		var both := church.merge(army) if army.has_area() else church
		return both if both.size.x <= BOTH_MAX_M.x and both.size.y <= BOTH_MAX_M.y else church
	return army if army.has_area() else plan.map.bounds


## The box around the army's squads (the living ones only when `living`).
static func _army_box(shot: SiegeSnapshot, living: bool) -> Rect2:
	var box := Rect2()
	var found := false
	for i in shot.entity_count():
		if shot.ent_team[i] == SiegeSnapshot.Team.ARMY and (shot.ent_count[i] > 0 or not living):
			box = box.expand(shot.ent_pos[i]) if found else Rect2(shot.ent_pos[i], Vector2.ZERO)
			found = true
	return box.grow(ARMY_PAD_M) if found else Rect2()


func _end(skipped: bool) -> void:
	var kind: StringName = current["kind"]
	current = {}
	beat_ended.emit(kind, skipped)
