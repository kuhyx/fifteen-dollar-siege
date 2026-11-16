class_name ResultStars
extends Control
## The win's rating over the result scene: three stars pop in one after
## another (a spark, a rising chime each), the unearned ones stay outlines
## with the coins they ask for as a seven-segment number. Nothing to read
## but pictures and numbers; a loss shows none.

## Real seconds before the first star, and between two.
const FIRST_S := 0.45
const STEP_S := 0.5
const POP_S := 0.28
const STAR_PX := 150.0
const GAP := 40.0

var earned := 0
var age := 0.0
## Stars that have popped in so far (tests and the bots read it).
var shown := 0


static func wide() -> float:
	return 3.0 * STAR_PX + 2.0 * GAP


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_earned: int) -> void:
	earned = p_earned
	visible = earned > 0
	set_process(visible)


func _process(delta: float) -> void:
	age += delta
	while shown < earned and age >= FIRST_S + shown * STEP_S:
		FunCue.play(&"fun_star", 1.0 + 0.12 * shown)
		shown += 1
	queue_redraw()


func _draw() -> void:
	for i in 3:
		var box := Rect2(Vector2(i * (STAR_PX + GAP), 0.0), Vector2.ONE * STAR_PX)
		var since := age - (FIRST_S + i * STEP_S)
		if i < earned:
			if since < 0.0:
				UiPictograms.of(&"star_off").draw(self, box)
				continue
			var pop := clampf(since / POP_S, 0.0, 1.0)
			var grown := 0.4 + 0.6 * ease(pop, 0.3) + 0.25 * sin(pop * PI)
			var lit := Rect2(box.get_center() - box.size * grown / 2.0, box.size * grown)
			UiPictograms.of(&"star").draw(self, lit)
			_sparks(box.get_center(), since)
		else:
			UiPictograms.of(&"star_off").draw(self, box)
			_cap(box, StarRating.cap_of(i))


## A ring of sparks that leaves a star as it lands.
func _sparks(centre: Vector2, since: float) -> void:
	if since > 0.9:
		return
	var out := since / 0.9
	for k in 8:
		var at := centre + Vector2.from_angle(TAU * k / 8.0 + 0.4) * (STAR_PX * (0.45 + 0.5 * out))
		draw_circle(at, 7.0 * (1.0 - out), Color(Palette.COIN, 1.0 - out))


## The coins an unearned star asks for: a coin and a number under it.
func _cap(box: Rect2, dollars: int) -> void:
	if dollars < 0:
		return
	var coin := Rect2(
		box.position + Vector2(box.size.x * 0.12, box.size.y + 6.0), Vector2.ONE * 40.0
	)
	UiPictograms.of(&"coin").draw(self, coin)
	SevenSegment.draw_number(self, dollars, coin.position + Vector2(52.0, 2.0), 36.0, Palette.INK)
