class_name RateLimiter
extends RefCounted
## Keeps one cue from starting again too soon. A hundred sling volleys in a
## second must stay a handful of sounds; each cue has its own clock, so a
## bell is never held back by the slings. Pure: the caller brings the time.

var _last := {}


## True (and the start is noted) when `gap_s` has passed since this cue's
## last allowed start.
func allow(cue: StringName, now_s: float, gap_s: float) -> bool:
	if now_s - float(_last.get(cue, -INF)) < gap_s:
		return false
	_last[cue] = now_s
	return true


func reset() -> void:
	_last.clear()
