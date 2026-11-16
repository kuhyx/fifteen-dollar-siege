class_name FigureMachines
extends RefCounted
## The buff specials on wheels or in the air: golf carts, the pumpkin
## catapult and the UFO. Side views facing +x, the ground at y = 0.

## The catapult's axle: its throwing arm swings about this point.
const CATAPULT_PIVOT := Vector2(0.2, -2.6)


static func build(kind: int, detail: bool) -> FigureBuilder:
	var b := FigureBuilder.make(detail)
	match kind:
		SiegeSnapshot.Kind.GOLF_CARTS:
			_cart(b)
		SiegeSnapshot.Kind.CATAPULT:
			_catapult(b)
		SiegeSnapshot.Kind.UFO:
			_ufo(b)
	return b


## A white cart with the army's stripe, a roof on two posts, a driver and a
## bag of clubs at the back.
static func _cart(b: FigureBuilder) -> void:
	b.gear = 1.0
	b.box(-2.1, -2.7, 0.42, 1.2, WorldPalette.WOOD)
	if b.detail:
		b.bar(Vector2(-2.0, -2.7), Vector2(-2.15, -3.2), 0.1, WorldPalette.STEEL)
		b.bar(Vector2(-1.8, -2.7), Vector2(-1.72, -3.25), 0.1, WorldPalette.STEEL)
	b.bar(Vector2(-1.9, -1.5), Vector2(-1.8, -3.45), 0.13, WorldPalette.STEEL_DARK)
	b.bar(Vector2(1.45, -1.5), Vector2(1.3, -3.45), 0.13, WorldPalette.STEEL_DARK)
	b.gear = 0.0
	b.box(-0.82, -2.25, 0.26, 1.05, WorldPalette.ARMY_DARK)
	b.shape([-0.36, -2.35, 0.5, -2.35, 0.56, -1.3, -0.46, -1.3], WorldPalette.ARMY)
	b.disc(Vector2(0.1, -2.8), Vector2.ONE * 0.46, WorldPalette.SKIN)
	b.slice(Vector2(0.1, -2.8), Vector2.ONE * 0.5, PI * 0.8, PI * 1.82, WorldPalette.HAIR)
	var hull := [-2.1, -1.5, -2.0, -0.7, 2.1, -0.7, 2.2, -1.1, 1.5, -1.5, 1.2, -1.5, 1.0, -1.2]
	hull.append_array([-0.9, -1.2, -1.0, -1.5])
	b.shape(hull, WorldPalette.WHITE)
	b.box(-2.0, -1.02, 4.12, 0.18, WorldPalette.ARMY)
	b.box(-2.2, -3.62, 3.9, 0.24, WorldPalette.WHITE)
	for x: float in [-1.3, 1.3]:
		b.disc(Vector2(x, -0.46), Vector2.ONE * 0.46, WorldPalette.SOOT)
		if b.detail:
			b.disc(Vector2(x, -0.46), Vector2.ONE * 0.18, WorldPalette.STEEL)
	if b.detail:
		b.bar(Vector2(0.4, -1.9), Vector2(1.05, -1.78), 0.24, WorldPalette.ARMY.darkened(0.15))
		b.bar(Vector2(1.05, -1.45), Vector2(1.16, -2.0), 0.12, WorldPalette.SOOT)
		b.disc(Vector2(0.36, -2.82), Vector2(0.08, 0.1), WorldPalette.SOOT)


## A wooden frame on small wheels; the arm is cocked back with a pumpkin in
## its cup and swings about the axle when it shoots.
static func _catapult(b: FigureBuilder) -> void:
	b.box(-2.2, -0.62, 4.4, 0.36, WorldPalette.WOOD_DARK)
	b.bar(Vector2(-0.7, -0.5), CATAPULT_PIVOT, 0.28, WorldPalette.WOOD)
	b.bar(Vector2(1.1, -0.5), CATAPULT_PIVOT, 0.28, WorldPalette.WOOD)
	for x: float in [-1.6, 1.6]:
		b.disc(Vector2(x, -0.46), Vector2.ONE * 0.46, WorldPalette.WOOD)
		if b.detail:
			b.disc(Vector2(x, -0.46), Vector2.ONE * 0.16, WorldPalette.WOOD_DARK)
	b.swing = 1.0
	b.gear = 1.0
	b.bar(Vector2(0.95, -3.0), Vector2(-2.2, -1.5), 0.22, WorldPalette.WOOD)
	b.box(0.75, -3.4, 0.6, 0.6, WorldPalette.STEEL_DARK)
	b.shape([-2.75, -1.5, -1.85, -1.5, -2.0, -1.15, -2.6, -1.15], WorldPalette.WOOD_DARK)
	b.disc(Vector2(-2.3, -1.92), Vector2(0.52, 0.46), WorldPalette.PUMPKIN)
	if b.detail:
		b.disc(Vector2(-2.3, -1.92), Vector2(0.2, 0.44), WorldPalette.PUMPKIN.darkened(0.14))
		b.box(-2.36, -2.56, 0.14, 0.22, WorldPalette.STEM)
	b.swing = 0.0
	b.gear = 0.0
	b.disc(CATAPULT_PIVOT, Vector2.ONE * 0.22, WorldPalette.STEEL_DARK)


## A saucer: a glass dome on a wide hull with a row of lights.
static func _ufo(b: FigureBuilder) -> void:
	if b.detail:
		b.disc(Vector2(0.0, -0.2), Vector2(2.0, 0.34), Color(Palette.GOOD, 0.22))
	b.slice(Vector2(0.0, -3.5), Vector2(1.7, 1.5), PI, TAU, WorldPalette.GLASS)
	b.disc(Vector2(0.0, -3.2), Vector2(4.3, 0.95), WorldPalette.HULL)
	b.disc(Vector2(0.0, -2.9), Vector2(2.5, 0.5), WorldPalette.STEEL_DARK)
	b.gear = 1.0
	for i in 5:
		var tint := Palette.GOOD if i % 2 == 0 else WorldPalette.BRASS
		b.disc(Vector2(-3.0 + 1.5 * i, -3.3), Vector2.ONE * (0.24 if b.detail else 0.3), tint)
	if b.detail:
		b.disc(Vector2(-0.5, -4.2), Vector2(0.3, 0.5), Color(WorldPalette.WHITE, 0.55), 0.5)
	b.gear = 0.0
