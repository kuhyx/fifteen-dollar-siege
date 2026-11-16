class_name ShopDice
extends Node
## The shop's dice: a button that sells everything back and buys a random
## legal loadout card by card, so the coins fly (the shop's own buy and sell
## cues ring a rising ladder) while the dice rattle. One more try with a
## different fifteen dollars, with no thinking needed.

const BUTTON := Vector2(100, 100)
const AT := Vector2(1780, 22)
## Real seconds between two cards, and the rattle's pace and tilt.
const STEP_S := 0.11
const RATTLE_HZ := 7.0
const TILT := 0.3

var button: PictoButton
var rolls := 0
var rolling := false

var _shop: LoadoutScreen
var _rng := RandomNumberGenerator.new()
var _age := 0.0


func setup(shop: LoadoutScreen, frame: ScreenFrame) -> void:
	_shop = shop
	_rng.randomize()
	button = PictoButton.make(UiPictograms.of(&"dice"), "Roll a random loadout", BUTTON)
	frame.place(button, Rect2(AT, BUTTON))
	button.pivot_offset = BUTTON / 2.0
	button.pressed.connect(roll)
	KeyHint.attach(button, MenuKeys.PICKS[1])


func roll() -> void:
	if rolling:
		return
	rolling = true
	rolls += 1
	var goal := LoadoutDice.roll(_rng, _shop.loadout.ids)
	FunCue.play(&"fun_dice")
	var tween := create_tween()
	for id in _shop.loadout.ids.duplicate():
		tween.tween_callback(_shop.toggle.bind(id))
		tween.tween_interval(STEP_S * 0.5)
	for id in goal:
		tween.tween_callback(_shop.toggle.bind(id))
		tween.tween_interval(STEP_S)
	tween.tween_callback(_done)


func _done() -> void:
	rolling = false
	button.rotation = 0.0


func _process(delta: float) -> void:
	_age += delta
	if rolling:
		button.rotation = sin(_age * TAU * RATTLE_HZ) * TILT
