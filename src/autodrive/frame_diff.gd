class_name FrameDiff
extends RefCounted
## What one thing adds to a frame, measured on pixels: the bot draws the
## screen with and without it and counts the pixels that differ. "Reads at a
## glance" becomes a number a gate can hold.

## Per-channel distance (0..1) from which a pixel counts as changed.
const SEEN := 0.1


## Pixels of `region` (image pixels) that differ between the two frames.
static func changed(with: Image, without: Image, region: Rect2i) -> int:
	var box := region.intersection(Rect2i(Vector2i.ZERO, with.get_size()))
	var count := 0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var a := with.get_pixel(x, y)
			var b := without.get_pixel(x, y)
			var gap := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			if gap >= SEEN:
				count += 1
	return count
