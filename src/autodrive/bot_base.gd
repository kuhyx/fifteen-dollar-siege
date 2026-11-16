class_name BotBase
extends Node
## The hands and eyes every autodrive scenario needs: frame waits (never wall
## clock), synthesized clicks and keys through the real input path, asserts
## that record the first failure, screenshot beats, and the verdict at the end.

var main: Main
var shots: BotShots
## The first failed assert ("" = none so far). Later steps do not run.
var failure := ""


## Waits `count` process frames (bot time is frames: load only slows the run).
func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Waits until `condition` holds; fails after `limit` frames.
func wait_for(condition: Callable, limit: int, what: String) -> bool:
	for i in limit:
		if condition.call():
			return true
		await get_tree().process_frame
	return check(false, "timed out after %d frames waiting for %s" % [limit, what])


## Records `what` as the failure when `ok` is false. Returns `ok`.
func check(ok: bool, what: String) -> bool:
	if not ok and failure == "":
		failure = what
		printerr("AUTODRIVE FAIL: %s" % what)
	return ok


## Waits for the named screen and lets its layout settle.
func on_screen(screen: StringName) -> bool:
	var there := func() -> bool: return main.screen_name == screen
	if not await wait_for(there, 300, "the %s screen" % screen):
		return false
	await frames(3)
	return true


## A left click in the middle of `control`, as window pixels a mouse would send.
func click(control: Control) -> void:
	InputSynth.canvas_tap(MOUSE_BUTTON_LEFT, control.get_global_rect().get_center())
	await frames(2)


func click_at(canvas_point: Vector2) -> void:
	InputSynth.canvas_tap(MOUSE_BUTTON_LEFT, canvas_point)
	await frames(2)


func press_escape() -> void:
	InputSynth.key_tap(KEY_ESCAPE)
	await frames(2)


## `control` is visible, has a size and lies wholly inside the viewport.
func inside(control: Control, what: String) -> bool:
	var view := get_viewport().get_visible_rect()
	var rect := control.get_global_rect()
	var ok := control.is_visible_in_tree() and rect.size.x > 1.0 and rect.size.y > 1.0
	return check(ok and view.encloses(rect), "%s is not inside the viewport: %s" % [what, rect])


## Every control of `controls` (name -> Control) passes `inside`.
func all_inside(controls: Dictionary, what: String) -> bool:
	for id: Variant in controls:
		if not inside(controls[id], "%s %s" % [what, id]):
			return false
	return true


## One screenshot beat; fails on a blank frame or an unwritable file.
func shot(label: String) -> bool:
	var why: String = await shots.take(label, get_viewport())
	return check(why == "", why)


## Writes the verdict, prints the RESULT line and quits with 0 or 1.
func finish(summary: String) -> void:
	var passed := failure == ""
	var verdict := "PASS %s" % summary if passed else "FAIL %s" % failure
	if not BotReport.write_verdict(main.options.result_file, verdict):
		printerr("AUTODRIVE FAIL: cannot write %s" % main.options.result_file)
		passed = false
	print("RESULT autodrive %s %s" % ["PASS" if passed else "FAIL", summary])
	RenderingServer.render_loop_enabled = true
	get_tree().quit(0 if passed else 1)
