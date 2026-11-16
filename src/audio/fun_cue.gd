class_name FunCue
extends RefCounted
## One call for the view's small rewards (a tally bell, a heartbeat, a glint):
## it asks the running director and does nothing when there is none (a test,
## a headless tool). The cue names are `AudioCues.FUN`.


static func play(cue: StringName, pitch: float = 1.0) -> void:
	var director := AudioDirector.live()
	if director != null:
		director.ui(cue, pitch)
