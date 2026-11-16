class_name FigureBeasts
extends RefCounted
## The buff specials that are not people: the stitched monster, the moose and
## the wasps. Side views facing +x, feet (or the ground under a wasp) at the
## origin.

const MONSTER_SCALE := 1.6


static func build(kind: int, detail: bool) -> FigureBuilder:
	var b := FigureBuilder.make(detail)
	match kind:
		SiegeSnapshot.Kind.MONSTER:
			_monster(b)
		SiegeSnapshot.Kind.MOOSE:
			_moose(b)
		SiegeSnapshot.Kind.WASPS:
			_wasp(b)
	return b


## Twice a man: a square head with a flat top, neck bolts, a stitched brow,
## a coat too small for him and both arms out in front.
static func _monster(b: FigureBuilder) -> void:
	b.scale = MONSTER_SCALE
	FigureParts.legs(b, WorldPalette.MONSTER_COAT.darkened(0.25))
	b.box(-0.6, -0.34, 0.74, 0.34, WorldPalette.SOOT)
	b.box(0.04, -0.34, 0.74, 0.34, WorldPalette.SOOT)
	FigureParts.block(b, WorldPalette.MONSTER_COAT)
	b.box(-0.58, -3.44, 1.16, 1.3, WorldPalette.MONSTER)
	b.box(-0.64, -3.6, 1.28, 0.34, WorldPalette.SOOT)
	if b.detail:
		b.box(-0.84, -2.42, 0.26, 0.2, WorldPalette.STEEL)
		b.box(0.58, -2.42, 0.26, 0.2, WorldPalette.STEEL)
		b.box(-0.05, -3.06, 0.62, 0.1, WorldPalette.SOOT)
		b.disc(Vector2(0.3, -2.86), Vector2(0.09, 0.1), WorldPalette.SOOT)
		b.bar(Vector2(-0.4, -3.2), Vector2(-0.4, -2.7), 0.06, WorldPalette.SOOT)
		for y: float in [-3.1, -2.95, -2.8]:
			b.bar(Vector2(-0.52, y), Vector2(-0.28, y), 0.05, WorldPalette.SOOT)
		b.box(-0.2, -2.14, 0.4, 1.3, WorldPalette.SOOT)
	b.swing = 1.0
	b.gear = 1.0
	b.bar(Vector2(0.4, -1.95), Vector2(1.6, -2.05), 0.4, WorldPalette.MONSTER_COAT.lightened(0.1))
	b.box(1.5, -2.3, 0.5, 0.5, WorldPalette.MONSTER)
	b.box(0.7, -2.26, 0.3, 0.42, WorldPalette.ARMY)
	b.swing = 0.0
	b.gear = 0.0


## A tall, humped deer with a long drooping nose and shovel antlers.
static func _moose(b: FigureBuilder) -> void:
	for x: float in [-1.5, 0.9]:
		b.bar(Vector2(x, -2.2), Vector2(x - 0.2, 0.0), 0.34, WorldPalette.MOOSE_DARK)
	b.disc(Vector2(-0.3, -2.7), Vector2(1.9, 0.98), WorldPalette.MOOSE)
	b.disc(Vector2(0.9, -3.25), Vector2(0.95, 0.8), WorldPalette.MOOSE)
	b.shape([1.2, -3.7, 2.3, -4.0, 2.5, -3.2, 1.5, -2.5], WorldPalette.MOOSE)
	var skull := [2.0, -4.25, 2.7, -4.3, 3.5, -3.6, 3.5, -3.05, 2.9, -2.95, 2.2, -3.3]
	b.shape(skull, WorldPalette.MOOSE)
	b.disc(Vector2(3.3, -3.3), Vector2(0.32, 0.3), WorldPalette.MOOSE_DARK)
	for x: float in [-1.1, 1.3]:
		b.bar(Vector2(x, -2.2), Vector2(x + 0.15, 0.0), 0.36, WorldPalette.MOOSE)
	var antler := [2.1, -4.2, 1.4, -5.1, 1.9, -5.0, 2.0, -5.6, 2.4, -5.05, 2.8, -5.5, 2.9, -4.85]
	antler.append_array([3.4, -5.0, 2.95, -4.35])
	b.gear = 1.0
	b.shape(
		antler if b.detail else [2.0, -4.2, 1.5, -5.4, 3.3, -5.2, 2.95, -4.3], WorldPalette.ANTLER
	)
	b.gear = 0.0
	if b.detail:
		b.shape([2.4, -3.1, 2.75, -3.0, 2.5, -2.45], WorldPalette.MOOSE_DARK)
		b.disc(Vector2(2.6, -3.95), Vector2(0.09, 0.1), WorldPalette.SOOT)
		b.shape([1.85, -4.2, 1.6, -4.6, 2.1, -4.3], WorldPalette.MOOSE_DARK)
		b.shape([-2.15, -2.9, -2.45, -2.5, -2.1, -2.5], WorldPalette.MOOSE_DARK)


## One paper wasp, much bigger than life so a swarm reads at any zoom.
static func _wasp(b: FigureBuilder) -> void:
	if not b.detail:
		b.shape([-0.55, -0.6, -0.1, -0.86, 0.3, -0.6, -0.1, -0.34], WorldPalette.BRASS)
		b.shape([0.26, -0.78, 0.6, -0.6, 0.26, -0.42], WorldPalette.SOOT)
		return
	b.disc(Vector2(-0.1, -1.0), Vector2(0.4, 0.17), WorldPalette.WING, -0.4)
	b.disc(Vector2(0.12, -0.98), Vector2(0.34, 0.15), WorldPalette.WING, 0.3)
	b.disc(Vector2(-0.18, -0.6), Vector2(0.42, 0.26), WorldPalette.BRASS)
	b.box(-0.34, -0.85, 0.12, 0.5, WorldPalette.SOOT)
	b.box(-0.1, -0.86, 0.12, 0.52, WorldPalette.SOOT)
	b.shape([-0.56, -0.68, -0.86, -0.6, -0.56, -0.52], WorldPalette.SOOT)
	b.disc(Vector2(0.38, -0.6), Vector2(0.22, 0.21), WorldPalette.SOOT)
