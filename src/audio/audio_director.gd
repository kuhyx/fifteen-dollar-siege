class_name AudioDirector
extends Node
## All the game's sound, as one node that `Main` owns (DOCS-audio.md section 4):
## music follows Main's signals (MusicDeck); menus get a cue per action; the
## battle has ONE entry point, `AudioDirector.on_snapshot(snapshot, view_rect)`
## (`view_rect`: the part of the MAP on screen, in metres: events sound left to
## right and quieter outside it); `FunCue` cues join the battle voices through
## `fun`. A bot (--autodrive) and a GUT run are muted on both buses; with no
## audio files every call is a quiet no-op. Volume: `set_music_volume`,
## `set_sfx_volume`, `set_muted`, `toggle_muted` (saved through SaveStore).
## `heard` counts the battle and fun cues asked for, per cue.

## Seconds one band riff keeps the rock loop over the bed [design guess].
const ROCK_HOLD_S := 8.0
## Louder per doubling of same-kind events in one snapshot, up to a cap.
const CROWD_DB := 1.5
const CROWD_MAX_DB := 4.0
## Quieter per view-width an event is outside the view, up to a cap.
const OFF_VIEW_DB := 9.0
const OFF_VIEW_MAX_DB := 12.0
const LOG_SIZE := 64

static var _live: AudioDirector

var bank := AudioBank.new()
var settings := AudioSettings.new()
var music := MusicDeck.new()
## Battle voices (they stop with the pause) and menu voices (they do not).
var pool := SfxPool.new()
var ui_pool := SfxPool.new()
var limiter := RateLimiter.new()
## True for a bot or a test run: both buses muted whatever is saved.
var silent := false
## Real seconds since boot. Cue gaps are measured on it (tests move it).
var clock_s := 0.0
## Menu cues that sounded, newest last (tests and the dev tools read it).
var ui_log: Array[StringName] = []
var heard := {}
## The process frame of the last menu cue (a press that cued does not click as well).
var ui_frame := -1

var _main: Main
var _rng := RandomNumberGenerator.new()
var _lab := LabSounds.new()
var _clicks: MenuClicks  # kept: its signal hooks do not hold it
var _view := Rect2()


## The director of the running game, null when there is none.
static func live() -> AudioDirector:
	return _live


## The battle's entry point: call once for every new snapshot.
static func on_snapshot(snapshot: SiegeSnapshot, view_rect: Rect2) -> void:
	if _live != null and snapshot != null:
		_live._take(snapshot, view_rect)


func _enter_tree() -> void:
	_live = self


func _exit_tree() -> void:
	AudioExit.settle(self)
	if _live == self:
		_live = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = get_parent() as Main
	_rng.seed = 15
	AudioBuses.ensure()
	settings = AudioSettings.load_saved()
	silent = SaveStore.running_tests() or (_main != null and _main.options.autodrive != &"")
	AudioBuses.apply(settings, silent)
	bank.load_all()
	add_child(music)
	music.setup(bank)
	pool.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(pool)
	add_child(ui_pool)
	if _main != null:
		_follow(_main)


func _process(delta: float) -> void:
	clock_s += delta
	if _main != null and _main.screen_name == &"lab":
		_lab.count(self, _main.screen.get("result"))


## Plays a menu cue (pitch 1 = as rendered).
func ui(cue: StringName, pitch: float = 1.0) -> void:
	ui_frame = Engine.get_process_frames()
	if not AudioCues.CUES.has(cue) or not limiter.allow(cue, clock_s, _of(cue, "gap", 0.05)):
		return
	ui_log.append(cue)
	if ui_log.size() > LOG_SIZE:
		ui_log.pop_front()
	_start(ui_pool, cue, {"pitch": pitch})


## A delight's cue (`FunCue`): on the battle voices, so a pause stops it; panned
## by `at` (map metres) against the view the battle last gave, the middle with
## none; counted in `heard` like every battle cue.
func fun(cue: StringName, pitch: float = 1.0, at: Vector2 = Vector2.INF) -> void:
	heard[cue] = int(heard.get(cue, 0)) + 1
	if not AudioCues.CUES.has(cue) or not limiter.allow(cue, clock_s, _of(cue, "gap", 0.05)):
		return
	var how := {"pitch": pitch}
	if at.is_finite():
		how["x"] = _screen_x(at.x, _view)
	_start(pool, cue, how)


func set_music_volume(linear: float) -> void:
	settings.music = clampf(linear, 0.0, 1.0)
	_keep()


func set_sfx_volume(linear: float) -> void:
	settings.sfx = clampf(linear, 0.0, 1.0)
	_keep()


func set_muted(on: bool) -> void:
	settings.muted = on
	_keep()


## Flips the mute and returns the new state.
func toggle_muted() -> bool:
	set_muted(not settings.muted)
	return settings.muted


func _keep() -> void:
	AudioBuses.apply(settings, silent)
	settings.save()


func _follow(main: Main) -> void:
	main.screen_changed.connect(_on_screen)
	main.siege_started.connect(func(_mode: StringName, _l: Loadout, _s: int) -> void: ui(&"ui_go"))
	main.siege_ended.connect(
		func(outcome: int, _clock: float) -> void: music.ending(outcome == SiegeSim.Outcome.WIN)
	)
	main.lab_finished.connect(func(result: Dictionary) -> void: _lab.done(self, result))
	main.loadout_changed.connect(_on_loadout_changed)
	if main.pause_menu != null:
		main.pause_menu.toggled.connect(_on_pause)
	_clicks = MenuClicks.new(self, main)


func _on_screen(screen_name: StringName) -> void:
	_lab.reset()
	if screen_name == &"battle":
		music.show_battle()
	elif screen_name != &"result" or music.scene != &"ending":
		music.show_hub()
	var screen := _main.screen
	if screen.has_signal(&"mode_picked"):
		screen.connect(&"mode_picked", func(_mode: StringName) -> void: ui(&"ui_mode"))
	if screen.has_signal(&"refused"):
		screen.connect(&"refused", func(_id: StringName) -> void: ui(&"ui_refuse"))


## The fuller the spend, the higher the coins ring.
func _on_loadout_changed(_id: StringName, bought: bool, cost: int) -> void:
	ui(&"ui_buy" if bought else &"ui_unbuy", 0.92 + 0.2 * cost / Loadout.BUDGET)


func _on_pause(open: bool) -> void:
	music.duck(open)
	ui(&"ui_pause" if open else &"ui_resume")


func _take(shot: SiegeSnapshot, view: Rect2) -> void:
	_view = view
	music.steer(shot.alarm, shot.army_morale, shot.village_morale)
	# Same-kind events of one snapshot become ONE sound at their middle.
	var groups := {}
	for event in shot.events:
		var cue := AudioCues.for_event(event)
		if cue == &"":
			continue
		heard[cue] = int(heard.get(cue, 0)) + 1
		if event.get("kind") == SiegeEvent.BAND_RIFF:
			music.band(ROCK_HOLD_S)
		var group: Dictionary = groups.get(cue, {"count": 0, "sum": Vector2.ZERO, "event": event})
		group["count"] += 1
		group["sum"] += event.get("pos", Vector2.ZERO) as Vector2
		groups[cue] = group
	for cue: StringName in groups:
		if limiter.allow(cue, clock_s, _of(cue, "gap", 0.1)):
			_place(cue, groups[cue], view)


func _place(cue: StringName, group: Dictionary, view: Rect2) -> void:
	var count: int = group["count"]
	var where: Vector2 = group["sum"] / count
	var across := _across(where.x, view)
	var outside := maxf(maxf(-across, across - 1.0), 0.0)
	var db := _of(cue, "db", 0.0)
	db += minf(CROWD_MAX_DB, CROWD_DB * log(count) / log(2.0))
	db -= minf(OFF_VIEW_MAX_DB, OFF_VIEW_DB * outside)
	var x := _screen_x(where.x, view)
	_start(pool, cue, {"x": x, "db": db, "pitch": AudioCues.pitch_for(group["event"])})


## Where map x is across `view` (0 left edge, 1 right edge, 0.5 with no view).
func _across(map_x: float, view: Rect2) -> float:
	return 0.5 if view.size.x <= 0.0 else (map_x - view.position.x) / view.size.x


## The speaker position (canvas x) of map x: the screen's width follows the view.
func _screen_x(map_x: float, view: Rect2) -> float:
	var screen := get_viewport().get_visible_rect()
	return screen.position.x + clampf(_across(map_x, view), 0.0, 1.0) * screen.size.x


func _start(voices: SfxPool, cue: StringName, how: Dictionary) -> void:
	var files: Array = AudioCues.CUES[cue]["files"]
	var spread := _of(cue, "jitter", 0.0)
	how["pitch"] = float(how.get("pitch", 1.0)) * (1.0 + _rng.randf_range(-spread, spread))
	how["db"] = float(how.get("db", _of(cue, "db", 0.0)))
	how["rank"] = int(_of(cue, "rank", 0.0))
	how["voices"] = int(_of(cue, "voices", 1.0))
	how["now"] = clock_s
	voices.play(cue, bank.stream(files[_rng.randi() % files.size()]), how)


func _of(cue: StringName, field: String, fallback: float) -> float:
	return AudioCues.value(cue, field, fallback)
