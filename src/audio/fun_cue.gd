class_name FunCue
extends RefCounted
## One call for the view's small rewards (a tally bell, a heartbeat, a glint):
## it asks the running director and does nothing when there is none (a test,
## a headless tool). `at` is where it happens, in map metres, when the cue should
## sound there (left to right across the view); without it the cue is central.
## The cue names are `AudioCues.FUN`.


static func play(cue: StringName, pitch: float = 1.0, at: Vector2 = Vector2.INF) -> void:
	var director := AudioDirector.live()
	if director != null:
		director.fun(cue, pitch, at)
