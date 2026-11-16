class_name CrowdScatter
extends RefCounted
## Where each individual of a squad stands around the squad's anchor. The sim
## knows squads; the view draws heads. Every place is a fixed point of the
## unit disc, the same on every run and for the whole siege, so a man keeps
## his spot while his squad walks, shrinks or scatters.

const GOLDEN := 2.39996323
## Metres a figure keeps from a wall, and how many buildings the shader knows.
const MARGIN_M := 0.8
const MAX_BLOCKS := 64
## How much wider or tighter a squad stands in a state [design guess].
const FLEE_SPREAD := 1.6
const FIGHT_SPREAD := 0.9
const MOVE_SPREAD := 1.1


## `capacity` places in the unit disc, evenly spread (a sunflower), sorted
## back to front so a figure nearer the viewer is drawn over one behind it.
static func homes(entity: int, capacity: int) -> PackedVector2Array:
	var places: Array[Vector2] = []
	var turn := _unit(entity, 1) * TAU
	for k in capacity:
		var reach := sqrt((k + 0.5) / capacity) if capacity > 1 else 0.0
		places.append(Vector2.from_angle(k * GOLDEN + turn) * reach)
	places.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	return PackedVector2Array(places)


## One animation phase (0..1) per individual, so a squad never moves in step.
static func phases(entity: int, capacity: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in capacity:
		out.append(_unit(entity * 7919 + k, 2))
	return out


## Who falls first: every index once, in a fixed shuffled order. With `alive`
## heads left, the first capacity - alive entries are down.
static func fall_order(entity: int, capacity: int) -> PackedInt32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([entity, capacity, 3])
	var order: Array[int] = []
	for k in capacity:
		order.append(k)
	for k in range(capacity - 1, 0, -1):
		var other := rng.randi_range(0, k)
		var kept := order[k]
		order[k] = order[other]
		order[other] = kept
	return PackedInt32Array(order)


## The disc a squad of `heads` fills, `spacing` metres apart.
static func radius(spacing: float, heads: int) -> float:
	return spacing * sqrt(float(maxi(heads, 0)))


## The factor a squad's disc takes in `state`.
static func state_spread(state: int) -> float:
	match state:
		SiegeSnapshot.State.FLEE:
			return FLEE_SPREAD
		SiegeSnapshot.State.FIGHT:
			return FIGHT_SPREAD
		SiegeSnapshot.State.MOVE:
			return MOVE_SPREAD
	return 1.0


## Where a figure that would stand at `point` really stands: off every block
## (x, y, width, height in metres), by the shortest way out. The crowd shader
## does the same sums (crowd.gdshader `cleared`); keep the two in step.
static func clear_of(point: Vector2, blocks: PackedVector4Array) -> Vector2:
	var spot := point
	for _round in 3:
		for block in blocks:
			var low := Vector2(block.x, block.y) - Vector2.ONE * MARGIN_M
			var high := Vector2(block.x + block.z, block.y + block.w) + Vector2.ONE * MARGIN_M
			if spot.x <= low.x or spot.x >= high.x or spot.y <= low.y or spot.y >= high.y:
				continue
			var gap := Vector4(spot.x - low.x, high.x - spot.x, spot.y - low.y, high.y - spot.y)
			var least := minf(minf(gap.x, gap.y), minf(gap.z, gap.w))
			if least == gap.x:
				spot.x = low.x
			elif least == gap.y:
				spot.x = high.x
			elif least == gap.z:
				spot.y = low.y
			else:
				spot.y = high.y
	return spot


## A fixed number in 0..1 for (seed, salt).
static func _unit(seed_value: int, salt: int) -> float:
	return float(hash([seed_value, salt]) & 0xFFFF) / 65535.0
