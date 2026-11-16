class_name FigureLibrary
extends RefCounted
## Every figure of the battle, built once in code and kept: asking again
## builds nothing (`builds` counts, the frame gate reads it). `warm` builds
## them all up front so no figure is ever made on first sight.

const BEASTS: Array[int] = [
	SiegeSnapshot.Kind.MONSTER, SiegeSnapshot.Kind.MOOSE, SiegeSnapshot.Kind.WASPS
]
## Kind -> [spacing m, bob, shake, lean, swing, buzz m, hover m, down turn].
## All [design guess], tuned by eye on the showcase frames.
const MOVES := {
	SiegeSnapshot.Kind.MEN: [1.45, 0.38, 0.09, 0.42, 0.9, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.VILLAGERS: [1.4, 0.34, 0.07, 0.5, 0.0, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.MILITIA: [1.45, 0.36, 0.09, 0.42, 0.7, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.RETINUE: [1.5, 0.3, 0.07, 0.3, 0.5, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.ARCHERS: [1.5, 0.34, 0.05, 0.42, 0.22, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.BAT_MEN: [1.6, 0.36, 0.1, 0.4, 1.1, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.SHOTGUNNER: [1.6, 0.36, 0.12, 0.4, 0.12, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.EMPEROR: [1.6, 0.2, 0.04, 0.3, 0.0, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.TRUMPET_BOY: [1.3, 0.42, 0.05, 0.5, 0.15, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.MEDICS: [1.5, 0.36, 0.05, 0.45, 0.3, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.MONSTER: [4.0, 0.3, 0.14, 0.2, 0.55, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.MOOSE: [4.4, 0.55, 0.12, 0.16, 0.0, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.WASPS: [0.6, 0.1, 0.1, 0.0, 0.0, 0.9, 0.3, 3.1],
	SiegeSnapshot.Kind.GOLF_CARTS: [3.8, 0.1, 0.08, 0.1, 0.0, 0.0, 0.0, 2.6],
	SiegeSnapshot.Kind.CATAPULT: [5.2, 0.04, 0.05, 0.0, 1.5, 0.0, 0.0, 0.45],
	SiegeSnapshot.Kind.ROCK_BAND: [3.4, 0.28, 0.08, 0.2, 0.7, 0.0, 0.0, 1.5],
	SiegeSnapshot.Kind.UFO: [9.0, 0.0, 0.1, 0.12, 0.0, 0.0, 0.5, 0.5],
}

## Figures built so far (not asked for: built).
static var builds := 0

static var _cache: Dictionary = {}
static var _flame: FigureSpec


## The figure of `kind`; the army's men also depend on the look.
static func spec(kind: int, look: FigureLook) -> FigureSpec:
	var key := str(kind)
	if FigurePeople.DRESSED.has(kind):
		key += ":" + look.key()
	if not _cache.has(key):
		_cache[key] = _build(kind, look)
	return _cache[key]


## Builds every kind for this look now (the battle screen calls it on entry).
static func warm(look: FigureLook) -> void:
	for kind: int in SiegeSnapshot.Kind.values():
		spec(kind, look)
	flame()


## The flame that sits on a burning figure (the lose payoff).
static func flame() -> FigureSpec:
	if _flame == null:
		builds += 1
		_flame = FigureSpec.from(-1, [_flame_shape(true)], [_flame_shape(false)])
	return _flame


static func _build(kind: int, look: FigureLook) -> FigureSpec:
	builds += 1
	var nears: Array[FigureBuilder] = []
	var fars: Array[FigureBuilder] = []
	if kind == SiegeSnapshot.Kind.ROCK_BAND:
		for player in FigureBand.PLAYERS:
			nears.append(FigureBand.build(player, true))
			fars.append(FigureBand.build(player, false))
	else:
		nears.append(_one(kind, look, true))
		fars.append(_one(kind, look, false))
	var out := FigureSpec.from(kind, nears, fars)
	var row: Array = MOVES[kind]
	out.spacing = row[0]
	out.motion = Vector4(row[1], row[2], row[3], row[4])
	out.buzz = row[5]
	out.hover = row[6]
	out.down_turn = row[7]
	out.pivot = FigureParts.PIVOT * nears[0].scale
	if kind == SiegeSnapshot.Kind.CATAPULT:
		out.pivot = FigureMachines.CATAPULT_PIVOT
	if kind == SiegeSnapshot.Kind.ROCK_BAND:
		out.whole_near = FigureBand.whole(true).mesh()
		out.whole_far = FigureBand.whole(false).mesh()
	return out


static func _one(kind: int, look: FigureLook, detail: bool) -> FigureBuilder:
	if FigurePeople.HUMANS.has(kind):
		return FigurePeople.build(kind, look, detail)
	if BEASTS.has(kind):
		return FigureBeasts.build(kind, detail)
	return FigureMachines.build(kind, detail)


static func _flame_shape(detail: bool) -> FigureBuilder:
	var b := FigureBuilder.make(detail)
	var outer := [0.0, -3.5, 0.5, -2.4, 0.95, -1.3, 0.8, -0.4, 0.0, 0.0, -0.8, -0.4, -0.95, -1.3]
	outer.append_array([-0.45, -2.1, -0.3, -2.9])
	b.shape(outer if detail else [0.0, -3.5, 0.95, -1.2, 0.0, 0.0, -0.95, -1.2], WorldPalette.FLAME)
	b.shape([0.05, -2.5, 0.6, -1.1, 0.0, -0.15, -0.6, -1.1], WorldPalette.FLAME_MID)
	if detail:
		b.shape([0.0, -1.5, 0.3, -0.7, 0.0, -0.25, -0.3, -0.7], WorldPalette.FLAME_CORE)
	return b
