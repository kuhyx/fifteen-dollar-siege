class_name SiegeState
extends RefCounted
## Everything that changes during one siege: parallel packed arrays (index =
## entity, for the whole siege), the alarm, the standing order, team morale and
## the event queue. Plain data; the Siege* systems are static functions over it.

## Entity flags (bits of `flag`).
const F_ALERTED := 1  # heard or saw the alarm
const F_ARMED := 2  # village fighter: armed and mustered
const F_DEAF := 4
const F_NO_RALLY := 8  # will not come back from this rout
const F_GONE := 16  # left the field or hid for good
const F_IGNORE := 32  # drunk: ignoring the standing order
const F_CHARGING := 64  # sprinting into contact: the first exchange hits harder
const F_RIDING := 128  # rides golf carts
const F_INVISIBLE := 256
const F_FIGHTER := 512
const F_WAVERS := 1024
const F_TARGET := 2048
const F_HOLDING := 4096  # at its place by the rally flag: recovers faster
const F_LINE := 16384  # a line squad of the army
const F_SLINGS := 32768  # carries slingshots
const F_SPOOKED := 8192  # has already seen the monster up close
const NO_ORDER := -1

var map := SiegeMap.new()
var mods := SiegeMods.new()
var rng := RandomNumberGenerator.new()
var grid := SiegeGrid.new()
var tick := 0
var outcome := 0
## True in Lab runs: events are not recorded (they never change the state).
var quiet := false
var events: Array[Dictionary] = []

## The standing player order (SiegeSim.Command) or NO_ORDER: the default plan.
var order := NO_ORDER
var order_pos := Vector2.ZERO

var alarm := 0.0
var alarm_on := false
var alarm_tick := 0
var bell_tick := 0

## Team morale relative to the start (1 = fresh); the side breaks at its
## SiegeTuning.*_BREAK. `*_base` is the start value the ratio is taken from.
var army_morale := 1.0
var village_morale := 1.0
## The lowest the village's morale has been so far (same scale).
var village_low := 1.0
var army_base := 0.0
var village_base := 0.0
## Morale every squad of the side gets from its living leaders and music.
var army_aura := 0.0
var village_aura := 0.0
var lord_fell := false
## True while a medic squad of the army stands (not routed).
var medics_up := false
var hold_s := 0.0
## Middle of the army squads that still stand; `standing` = how many. The
## followers (leaders, medics, crews) form up around `anchor`.
var front := Vector2.ZERO
var anchor := Vector2.ZERO
var standing := 0
## Fear the first shotgun blast left in every villager who heard it (fades).
var fear := 0.0
## Heads in the plaza this decision step: the army's and the armed defenders'.
var plaza_army := 0
var plaza_village := 0
## Entities with a routine of their own (SiegeSpecials, SiegeBeasts), the
## leaders whose presence is an aura (-1: not in this siege), the retinue.
var specials := PackedInt32Array()
var emperor := -1
var trumpet := -1
var band := -1
var retinue := PackedInt32Array()
## The army entity the village moves against (-1: none in reach).
var threat := -1
## Tick of the first melee and of the first shotgun blast (-1: not yet).
var contact_tick := -1
var blast_tick := -1
## Pumpkins in the air: {tick, pos, from}.
var pumpkins: Array[Dictionary] = []

# --- what a snapshot shows ---
var pos := PackedVector2Array()
var kind := PackedInt32Array()
var team := PackedByteArray()
var count := PackedInt32Array()
var state := PackedByteArray()
var facing := PackedFloat32Array()
# --- logic only ---
var start := PackedInt32Array()
var morale := PackedFloat32Array()
## Morale ceiling: the start value, lowered by every rout.
var cap := PackedFloat32Array()
var fatigue := PackedFloat32Array()
var goal := PackedVector2Array()
var speed := PackedFloat32Array()
## 0 stand, 1 walk, 2 march, 3 sprint (drives fatigue).
var pace := PackedByteArray()
## The enemy this entity fights or closes with (-1: none).
var foe := PackedInt32Array()
var reload := PackedFloat32Array()
var ammo := PackedInt32Array()
## Lightly wounded men a medic can put back on their feet.
var hurt := PackedInt32Array()
## Village: alarm level it hears at, then seconds left to arm. Others: a timer.
var wait := PackedFloat32Array()
## Army: place in the formation. Village: muster spot or refuge.
var slot := PackedVector2Array()
var flag := PackedInt32Array()
## Tick of the last hit taken, and tick until which wasps daze the squad.
var hit := PackedInt32Array()
var daze := PackedInt32Array()
## Per-kind counter (moose charges left, tick of the last clash event...).
var note := PackedInt32Array()
## Enemy squads in melee with this one in the current decision step.
var mobbed := PackedByteArray()


func clock_s() -> float:
	return tick * SiegeTuning.STEP_S


## Whole ticks in `seconds`.
static func ticks(seconds: float) -> int:
	return roundi(seconds / SiegeTuning.STEP_S)


## Adds an entity; returns its index.
func add(at: Vector2, p_kind: int, p_team: int, heads: int, p_morale: float) -> int:
	pos.append(at)
	kind.append(p_kind)
	team.append(p_team)
	count.append(heads)
	state.append(SiegeSnapshot.State.IDLE)
	facing.append(0.0 if p_team == SiegeSnapshot.Team.ARMY else PI)
	start.append(heads)
	morale.append(p_morale)
	cap.append(p_morale)
	fatigue.append(0.0)
	goal.append(at)
	speed.append(0.0)
	pace.append(0)
	foe.append(-1)
	reload.append(0.0)
	ammo.append(0)
	hurt.append(0)
	wait.append(0.0)
	slot.append(Vector2.ZERO)
	flag.append(SiegeKinds.flags(p_kind))
	hit.append(-1000)
	daze.append(-1)
	note.append(0)
	mobbed.append(0)
	return pos.size() - 1


func emit(event: StringName, at: Vector2) -> void:
	if not quiet:
		events.append({"kind": event, "pos": at})


## An event with extra data (`data` gets `kind` and `pos` added).
func emit_with(event: StringName, at: Vector2, data: Dictionary) -> void:
	if quiet:
		return
	data["kind"] = event
	data["pos"] = at
	events.append(data)


## Break-point scale of entity i: strangers, or neighbours at home / away.
func cohesion(i: int) -> float:
	if team[i] == SiegeSnapshot.Team.ARMY:
		return mods.cohesion
	if flag[i] & F_DEAF != 0:
		return BuffTuning.DEAF_COHESION
	if map.in_village(pos[i]):
		return SiegeTuning.COHESION_HOME
	return SiegeTuning.COHESION_AWAY


## A morale shock of `base` (at cohesion 1, rested) to entity i.
func jolt(i: int, base: float) -> void:
	if flag[i] & F_WAVERS == 0:
		return
	var amount := base / cohesion(i) * (1.0 + SiegeTuning.FATIGUE_SHOCK * fatigue[i])
	if team[i] == SiegeSnapshot.Team.ARMY:
		amount *= mods.shock
	morale[i] = maxf(morale[i] - amount, 0.0)


## The same shock to every standing fighter of `p_team` within `reach` of `at`
## (reach <= 0: the whole side), except `skip`. A deaf squad does not hear a
## `heard` shock.
func jolt_team(p_team: int, at: Vector2, reach: float, base: float, skip: int, heard: bool) -> void:
	var reach2 := reach * reach
	for i in pos.size():
		if team[i] != p_team or count[i] <= 0 or i == skip or flag[i] & F_GONE != 0:
			continue
		if heard and flag[i] & F_DEAF != 0:
			continue
		if reach <= 0.0 or at.distance_squared_to(pos[i]) <= reach2:
			jolt(i, base)


## A whole number of casualties (or hits) from an expected value.
func sample(expected: float) -> int:
	var whole := int(expected)
	if rng.randf() < expected - whole:
		whole += 1
	return whole
