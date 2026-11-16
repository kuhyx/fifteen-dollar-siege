class_name DangerEdge
extends Control
## The army's nerve, felt at the screen's edge: below `DANGER_BELOW` morale a
## red frame pulses with a heartbeat (lub, dub), deeper the closer the rout;
## back above `CALM_ABOVE` a gold flash relieves it, once. No word, no bar:
## colour, motion and sound.

const DANGER_BELOW := 0.3
const CALM_ABOVE := 0.45
## Real seconds between two heartbeats, and between lub and dub.
const BEAT_S := 0.9
const DUB_S := 0.17
## How fast the red frame fades in (levels a second) and the relief fades out.
const RISE_PER_S := 2.0
const RELIEF_S := 0.9
## The share of the red that stays between two beats.
const GLOW := 0.4
const RINGS := 10
## Fraction of the shorter side the frame reaches in.
const DEPTH := 0.2

## Heartbeats sounded and reliefs flashed so far (tests and the bots read them).
var beats := 0
var reliefs := 0

var _danger := false
var _level := 0.0
var _since := BEAT_S
var _pulse := 0.0
var _relief := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## The red frame's strength now, 0..1.
func intensity() -> float:
	return _level * (GLOW + (1.0 - GLOW) * _pulse)


func show_state(shot: SiegeSnapshot, delta: float) -> void:
	var morale := shot.army_morale
	if not _danger and morale < DANGER_BELOW:
		_danger = true
	elif _danger and morale > CALM_ABOVE:
		_danger = false
		reliefs += 1
		_relief = 1.0
		FunCue.play(&"fun_star", 1.3)
	var goal := clampf((DANGER_BELOW - morale) / DANGER_BELOW, 0.0, 1.0) if _danger else 0.0
	_level = move_toward(_level, goal, RISE_PER_S * delta)
	_since += delta
	if _danger and _since >= BEAT_S:
		_since = 0.0
		beats += 1
		FunCue.play(&"fun_heartbeat")
	_pulse = _shape(_since) if _danger else 0.0
	_relief = maxf(_relief - delta / RELIEF_S, 0.0)
	if intensity() > 0.0 or _relief > 0.0 or visible:
		queue_redraw()


## Lub at the beat, a softer dub a moment after, then quiet.
func _shape(since: float) -> float:
	var lub := exp(-since * 9.0)
	var dub := 0.6 * exp(-maxf(since - DUB_S, 0.0) * 9.0) if since >= DUB_S else 0.0
	return clampf(maxf(lub, dub), 0.0, 1.0)


func _draw() -> void:
	var strength := intensity()
	var tint := Palette.BAD
	if _relief > 0.0:
		strength = maxf(strength, _relief * 0.7)
		tint = Palette.COIN if intensity() < _relief * 0.7 else Palette.BAD
	if strength <= 0.01:
		return
	var depth := minf(size.x, size.y) * DEPTH
	for ring in RINGS:
		var inset := depth * ring / RINGS
		var fall := 1.0 - float(ring) / RINGS
		var box := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
		draw_rect(box, Color(tint, strength * fall * fall * 0.85), false, depth / RINGS + 1.0)
