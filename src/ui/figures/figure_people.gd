class_name FigurePeople
extends RefCounted
## The human figures: the army's men (dressed by the loadout's look), the
## village's four kinds, and the buff specials that walk on two legs. No real
## person: the emperor is a small man in a bicorne.

const HUMANS: Array[int] = [
	SiegeSnapshot.Kind.MEN,
	SiegeSnapshot.Kind.VILLAGERS,
	SiegeSnapshot.Kind.MILITIA,
	SiegeSnapshot.Kind.RETINUE,
	SiegeSnapshot.Kind.ARCHERS,
	SiegeSnapshot.Kind.BAT_MEN,
	SiegeSnapshot.Kind.SHOTGUNNER,
	SiegeSnapshot.Kind.EMPEROR,
	SiegeSnapshot.Kind.TRUMPET_BOY,
	SiegeSnapshot.Kind.MEDICS,
]
## The kinds that wear what the loadout bought ("every man in your army").
const DRESSED: Array[int] = [
	SiegeSnapshot.Kind.MEN, SiegeSnapshot.Kind.BAT_MEN, SiegeSnapshot.Kind.SHOTGUNNER
]


static func build(kind: int, look: FigureLook, detail: bool) -> FigureBuilder:
	var b := FigureBuilder.make(detail)
	match kind:
		SiegeSnapshot.Kind.MEN:
			_soldier(b, look, FigureGear.club)
		SiegeSnapshot.Kind.BAT_MEN:
			b.scale = 1.1
			_soldier(b, look, FigureGear.bat)
		SiegeSnapshot.Kind.SHOTGUNNER:
			_soldier(b, look, FigureGear.shotgun)
			if detail:
				b.bar(Vector2(-0.6, -2.1), Vector2(0.6, -0.9), 0.18, WorldPalette.WOOD_DARK)
		SiegeSnapshot.Kind.VILLAGERS:
			b.scale = 0.92
			FigureParts.villager(b, WorldPalette.CLOTH, WorldPalette.VILLAGE)
		SiegeSnapshot.Kind.MILITIA:
			FigureParts.villager(b, WorldPalette.VILLAGE, WorldPalette.VILLAGE_DARK)
			_armed(b, WorldPalette.VILLAGE_DARK, FigureGear.pitchfork)
		SiegeSnapshot.Kind.RETINUE:
			_retinue(b)
		SiegeSnapshot.Kind.ARCHERS:
			_archer(b)
		SiegeSnapshot.Kind.EMPEROR:
			_emperor(b)
		SiegeSnapshot.Kind.TRUMPET_BOY:
			b.scale = 0.7
			FigureParts.man(b, WorldPalette.ARMY, WorldPalette.ARMY_DARK)
			b.swing = 1.0
			FigureGear.trumpet(b)
			FigureParts.arm(b, WorldPalette.ARMY, Vector2(0.9, -2.6))
			b.swing = 0.0
		SiegeSnapshot.Kind.MEDICS:
			_medic(b)
	return b


## Draws the weapon and the arm that holds it, tagged for the swing.
static func _armed(b: FigureBuilder, sleeve: Color, weapon: Callable) -> void:
	b.swing = 1.0
	b.gear = 1.0
	weapon.call(b)
	b.gear = 0.0
	FigureParts.arm(b, sleeve)
	b.swing = 0.0


static func _soldier(b: FigureBuilder, look: FigureLook, weapon: Callable) -> void:
	FigureParts.back_arm(b, WorldPalette.ARMY.darkened(0.18))
	FigureParts.legs(b, WorldPalette.STEEL_DARK if look.knight else WorldPalette.ARMY_DARK)
	if look.knight:
		FigureGear.plate(b)
	else:
		FigureParts.block(b, WorldPalette.ARMY)
	if look.cardboard:
		FigureGear.cardboard(b)
	if look.booze:
		FigureGear.canteen(b)
	if look.helmet:
		FigureGear.football_helmet(b)
	elif look.knight:
		FigureGear.knight_helm(b)
	else:
		FigureParts.head(b)
		FigureParts.hair(b)
	_armed(b, WorldPalette.STEEL if look.knight else WorldPalette.ARMY, weapon)


## The lord's man: mail, a surcoat in the village colour, helm, shield, spear.
static func _retinue(b: FigureBuilder) -> void:
	FigureParts.back_arm(b, WorldPalette.STEEL_DARK)
	FigureParts.legs(b, WorldPalette.STEEL_DARK)
	FigureParts.tunic(b, WorldPalette.STEEL_DARK)
	b.shape([-0.28, -2.14, 0.28, -2.14, 0.6, -0.36, -0.6, -0.36], WorldPalette.VILLAGE)
	FigureParts.head(b)
	b.gear = 1.0
	FigureGear.nasal_helm(b)
	b.gear = 0.0
	_armed(b, WorldPalette.STEEL_DARK, FigureGear.spear)
	b.gear = 1.0
	FigureGear.shield(b)
	b.gear = 0.0


static func _archer(b: FigureBuilder) -> void:
	b.gear = 1.0
	b.bar(Vector2(-0.5, -1.2), Vector2(-0.86, -2.7), 0.34, WorldPalette.WOOD_DARK)
	if b.detail:
		b.bar(Vector2(-0.8, -2.6), Vector2(-0.98, -3.1), 0.1, WorldPalette.CLOTH)
		b.bar(Vector2(-0.66, -2.62), Vector2(-0.7, -3.16), 0.1, WorldPalette.CLOTH)
	b.gear = 0.0
	FigureParts.villager(b, WorldPalette.VILLAGE_DARK, WorldPalette.VILLAGE)
	_armed(b, WorldPalette.VILLAGE, FigureGear.bow)


## A small man in a wide two-cornered hat, one hand in his coat.
static func _emperor(b: FigureBuilder) -> void:
	b.scale = 0.8
	FigureParts.legs(b, WorldPalette.WHITE)
	b.box(-0.5, -0.5, 1.04, 0.5, WorldPalette.SOOT)
	FigureParts.block(b, WorldPalette.ARMY_DARK)
	b.shape([-0.3, -2.14, 0.3, -2.14, 0.0, -1.3], WorldPalette.WHITE)
	b.gear = 1.0
	b.box(-1.0, -2.24, 0.42, 0.22, WorldPalette.BRASS)
	b.box(0.58, -2.24, 0.42, 0.22, WorldPalette.BRASS)
	b.gear = 0.0
	FigureParts.head(b)
	b.gear = 1.0
	var hat := [-1.4, -2.96, -0.9, -3.34, 0.0, -3.9, 0.9, -3.34, 1.4, -2.96, 0.5, -3.1, -0.5, -3.1]
	b.shape(hat if b.detail else [-1.4, -2.96, 0.0, -3.9, 1.4, -2.96], WorldPalette.SOOT)
	if b.detail:
		b.disc(Vector2(0.24, -3.42), Vector2.ONE * 0.14, WorldPalette.BRASS)
		b.bar(Vector2(0.5, -1.92), Vector2(0.06, -1.5), 0.3, WorldPalette.ARMY_DARK.darkened(0.2))
	b.gear = 0.0


## A long white coat, the army's armband, a kit with the heal cross.
static func _medic(b: FigureBuilder) -> void:
	FigureParts.back_arm(b, WorldPalette.WHITE.darkened(0.2))
	FigureParts.legs(b, WorldPalette.ARMY_DARK)
	b.shape([-0.84, -2.14, 0.84, -2.14, 0.72, -0.5, -0.72, -0.5], WorldPalette.WHITE)
	FigureParts.head(b)
	b.slice(FigureParts.HEAD, Vector2.ONE * 0.66, PI * 1.02, PI * 1.98, WorldPalette.WHITE)
	if b.detail:
		b.box(-0.1, -3.3, 0.2, 0.4, Palette.GOOD)
		b.box(-0.2, -3.2, 0.4, 0.2, Palette.GOOD)
	_armed(b, WorldPalette.WHITE, FigureGear.medkit)
	b.swing = 1.0
	b.bar(Vector2(0.62, -1.8), Vector2(0.8, -1.63), 0.36, WorldPalette.ARMY)
	b.swing = 0.0
