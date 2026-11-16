class_name ScreenFrame
extends Control
## The 1920 x 1080 design area of a menu screen, centred in whatever the
## window gives. On a 16:9 window it is the whole window, so every control
## placed inside it is inside the viewport; wider or taller windows only add
## margin. The top corners stay free: the menu button (left) and the dev
## camera glyph (right) live there.

const SIZE := Vector2(1920, 1080)
## The square each top corner keeps free for the overlay buttons.
const CORNER := 130.0


## Makes `screen` fill its parent and gives it a centred frame to build in.
static func into(screen: Control) -> ScreenFrame:
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := ScreenFrame.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -SIZE.x / 2.0
	frame.offset_right = SIZE.x / 2.0
	frame.offset_top = -SIZE.y / 2.0
	frame.offset_bottom = SIZE.y / 2.0
	screen.add_child(frame)
	return frame


## Adds `child` at `box` (frame units) and returns it.
func place(child: Control, box: Rect2) -> Control:
	child.position = box.position
	child.size = box.size
	child.custom_minimum_size = box.size
	add_child(child)
	return child
