class_name BotShots
extends RefCounted
## Screenshot beats of the autodrive. Drawing stays off between beats (software
## GL makes every frame slow); a beat draws exactly one frame, reads it back,
## fails on a blank one and saves it as <dir>/NN_<label>.png when a dir is set.

## Beats taken so far (also the NN of the file name).
var count := 0
## Beats that really drew a frame (0 headless).
var rendered := 0

var _dir := ""


func _init(dir: String) -> void:
	_dir = dir
	if _dir != "":
		DirAccess.make_dir_recursive_absolute(_dir)


## "" when the beat is fine, else why not. Headless has nothing to read back.
func take(label: String, viewport: Viewport) -> String:
	count += 1
	if DisplayServer.get_name() == "headless":
		return ""  # nothing is drawn, so there is no frame to wait for
	rendered += 1
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	var image := viewport.get_texture().get_image()
	if FrameStats.is_blank(image):
		return "frame '%s' is blank" % label
	if _dir == "":
		return ""
	var path := "%s/%02d_%s.png" % [_dir, count, label]
	return "" if image.save_png(path) == OK else "cannot save %s" % path


## One drawn frame read back and not saved (null headless): the bot compares
## frames with and without a layer (FrameDiff).
func grab(viewport: Viewport) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	return viewport.get_texture().get_image()
