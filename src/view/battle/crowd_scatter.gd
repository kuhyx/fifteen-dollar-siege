class_name CrowdScatter
extends RefCounted
## Where each individual of a squad stands around the squad's anchor. The sim
## knows squads; the view draws heads. Every place is a fixed point of the
## unit disc, the same on every run and for the whole siege, so a man keeps
## his spot while his squad walks, shrinks or scatters.

const GOLDEN := 2.39996323


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


## A fixed number in 0..1 for (seed, salt).
static func _unit(seed_value: int, salt: int) -> float:
	return float(hash([seed_value, salt]) & 0xFFFF) / 65535.0
