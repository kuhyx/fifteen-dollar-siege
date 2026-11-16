class_name AudioExit
extends RefCounted
## Godot prints "resources still in use at exit" when a sound was playing as
## the game quit. A stopped player hands its playback to the audio server,
## which frees it on its next mix step; at exit no step is left, so the
## playback keeps its stream (found with `godot --verbose`: the hub loop).
## Letting the mixer take two or three steps first leaves nothing behind.
## A GUT run frees a director in nearly every test and never needs this.

## The Dummy driver mixes a 1024-frame buffer every 23 ms; two steps free a
## stopped playback, a few more make sure on a loaded machine.
const SETTLE_MS := 100


## Called as the director leaves the tree: stops every voice, then waits.
static func settle(director: Node) -> void:
	if SaveStore.running_tests():
		return
	var stopped := 0
	for node in director.find_children("*", "", true, false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
			node.call("stop")
			stopped += 1
	if stopped > 0:
		OS.delay_msec(SETTLE_MS)
