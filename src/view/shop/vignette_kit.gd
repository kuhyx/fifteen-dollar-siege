class_name VignetteKit
extends RefCounted
## The cast and props the buff vignettes share, drawn with a VignettePen in
## stage units (192 x 128, the floor at y = 104): a little person who walks,
## falls and flies, a house, and the marks that stand in for words (a star for
## a hit, a heart for courage, a plus for more).

const FLOOR := 104.0
const ARMY := Palette.ARMY
const FOLK := Palette.VILLAGE
## Ground tufts repeat this often: scroll by a multiple of it per loop.
const TUFT_GAP := 48.0


## 0 before `from`, 1 after `to`, eased in between.
static func ramp(u: float, from: float, to: float) -> float:
	return smoothstep(from, to, u)


## 1 at `at`, falling to 0 `width` away on both sides.
static func pulse(u: float, at: float, width: float) -> float:
	return maxf(0.0, 1.0 - absf(u - at) / width)


## The ground, with tufts that slide left by `scroll` (walking on the spot).
static func ground(p: VignettePen, scroll := 0.0) -> void:
	p.rect(Rect2(0, FLOOR, VignettePen.STAGE.x, VignettePen.STAGE.y - FLOOR), Palette.GROUND)
	for i in 5:
		var x := fposmod(i * TUFT_GAP + 20.0 - scroll, VignettePen.STAGE.x + TUFT_GAP) - 24.0
		p.line(
			Vector2(x, FLOOR + 9), Vector2(x + 10, FLOOR + 9), 2.0, Palette.GROUND.lightened(0.12)
		)


## A little person standing on `foot`; returns the centre of the head.
## `stride` swings the legs (radians), `lean` tips the body (radians).
static func man(
	p: VignettePen, foot: Vector2, tint: Color, stride := 0.0, size := 1.0, lean := 0.0
) -> Vector2:
	var up := Vector2.UP.rotated(lean) * size
	var side := Vector2.RIGHT.rotated(lean) * size
	var hip := foot + up * 9.0
	var swing := sin(stride) * 4.0
	p.line(hip, foot + side * swing, 3.2 * size, tint)
	p.line(hip, foot - side * swing, 3.2 * size, tint)
	p.line(hip + up * 2.5, hip + up * 10.0, 8.5 * size, tint)
	var head := hip + up * 17.5
	p.disc(head, 4.8 * size, tint)
	return head


## An arm from the shoulder under `head` to `hand`.
static func arm(p: VignettePen, head: Vector2, hand: Vector2, tint: Color, size := 1.0) -> void:
	p.line(head + Vector2(0, 7.5 * size), hand, 2.8 * size, tint)


## A person thrown through the air: centred on `at`, spun by `turn`.
static func tumble(p: VignettePen, at: Vector2, tint: Color, turn: float, size := 1.0) -> void:
	man(p, at + Vector2.DOWN.rotated(turn) * 13.0 * size, tint, 0.9, size, turn)


## Only the outline of a person, dashed: he cannot be seen.
static func ghost(p: VignettePen, foot: Vector2, stride: float) -> void:
	var tint := Color(PictoInk.LIGHT, 0.85)
	var swing := sin(stride) * 4.0
	var hip := foot + Vector2(0, -9)
	p.line(hip, foot + Vector2(swing, 0), 0.9, tint)
	p.line(hip, foot - Vector2(swing, 0), 0.9, tint)
	for turn: float in [0.0, 90.0, 180.0, 270.0]:
		p.arc(foot + Vector2(0, -26.5), 4.6, turn + 10.0, turn + 60.0, 1.0, tint)
	for y: float in [-21.0, -15.0]:
		p.line(foot + Vector2(-4.2, y), foot + Vector2(-4.2, y + 3.5), 1.0, tint)
		p.line(foot + Vector2(4.2, y), foot + Vector2(4.2, y + 3.5), 1.0, tint)


## A village house standing on `at`.
static func house(p: VignettePen, at: Vector2, size := 1.0) -> void:
	p.rect(Rect2(at + Vector2(-14, -20) * size, Vector2(28, 20) * size), Palette.BUILDING)
	var roof := [-18.0 * size, -19.0 * size, 0.0, -36.0 * size, 18.0 * size, -19.0 * size]
	p.poly(roof, PictoInk.WOOD.darkened(0.25), at)
	p.rect(Rect2(at + Vector2(-3.5, -11) * size, Vector2(7, 11) * size), Palette.PANEL)


## A four-pointed star: a hit, a gleam.
static func star(p: VignettePen, at: Vector2, r: float, tint: Color) -> void:
	if r <= 0.2:
		return
	var flat := []
	for i in 8:
		var spoke := Vector2.from_angle(TAU * i / 8.0) * (r if i % 2 == 0 else r * 0.32)
		flat.append_array([spoke.x, spoke.y])
	p.poly(flat, tint, at)


## A heart: courage going up.
static func heart(p: VignettePen, at: Vector2, r: float) -> void:
	if r <= 0.2:
		return
	p.disc(at + Vector2(-r * 0.5, -r * 0.3), r * 0.58, PictoInk.RED)
	p.disc(at + Vector2(r * 0.5, -r * 0.3), r * 0.58, PictoInk.RED)
	p.poly([-r * 1.02, 0, r * 1.02, 0, 0, r * 1.15], PictoInk.RED, at)


## A plus: more of something, or a cure.
static func plus(p: VignettePen, at: Vector2, r: float, tint: Color) -> void:
	if r <= 0.2:
		return
	p.line(at - Vector2(r, 0), at + Vector2(r, 0), r * 0.55, tint)
	p.line(at - Vector2(0, r), at + Vector2(0, r), r * 0.55, tint)


## A music note.
static func note(p: VignettePen, at: Vector2, size: float, tint: Color) -> void:
	p.disc(at, size, tint)
	p.line(at + Vector2(size * 0.8, 0), at + Vector2(size * 0.8, -size * 3.4), size * 0.5, tint)
	var top := at + Vector2(size * 0.8, -size * 3.4)
	p.line(top, top + Vector2(size * 1.8, size * 0.7), size * 0.5, tint)


## A wasp in flight; `flap` beats its wings.
static func wasp(p: VignettePen, at: Vector2, flap: float) -> void:
	p.oval(at + Vector2(-1.5, -2.2 - absf(sin(flap)) * 1.2), 2.4, 1.2, PictoInk.LIGHT)
	p.oval(at, 3.2, 1.9, PictoInk.GOLD)
	p.line(at + Vector2(-0.6, -1.6), at + Vector2(-0.6, 1.6), 0.7, PictoInk.DARK)
	p.line(at + Vector2(-2.6, 0.2), at + Vector2(-4.6, 0.8), 0.6, PictoInk.LIGHT)


## A pumpkin of radius r.
static func pumpkin(p: VignettePen, at: Vector2, r: float) -> void:
	p.rect(Rect2(at + Vector2(-0.8, -r - 2.0), Vector2(1.6, 2.6)), PictoInk.GREEN)
	p.oval(at, r * 1.12, r, PictoInk.ORANGE)
	p.line(at + Vector2(-r * 0.35, -r * 0.7), at + Vector2(-r * 0.4, r * 0.7), 0.5, PictoInk.WOOD)
	p.line(at + Vector2(r * 0.35, -r * 0.7), at + Vector2(r * 0.4, r * 0.7), 0.5, PictoInk.WOOD)


## A gold pie slice of a clock face: `share` of a whole turn from the top.
static func wedge(p: VignettePen, at: Vector2, r: float, share: float) -> void:
	if share <= 0.002:
		return
	var flat := [0.0, 0.0]
	var steps := maxi(2, ceili(40.0 * share))
	for i in steps + 1:
		var spoke := Vector2.from_angle(TAU * share * i / steps - PI / 2.0) * r
		flat.append_array([spoke.x, spoke.y])
	p.poly(flat, PictoInk.GOLD, at)


## A stone thrown from `from` that hits `target` at u = `at_u` and bounces off.
static func stone(p: VignettePen, u: float, from: Vector2, target: Vector2, at_u: float) -> void:
	var before := ramp(u, at_u - 0.25, at_u)
	var after := ramp(u, at_u, at_u + 0.3)
	var spot := from.lerp(target, before)
	if after > 0.0:
		spot = target + Vector2(26.0 * after, -sin(after * PI) * 22.0 + after * (FLOOR - target.y))
	if u > at_u - 0.25 and after < 1.0:
		p.disc(spot, 2.2, PictoInk.GREY)
	star(p, target, 7.0 * pulse(u, at_u + 0.02, 0.07), PictoInk.GOLD)
