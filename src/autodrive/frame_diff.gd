class_name FrameDiff
extends RefCounted
## What one thing adds to a frame, measured on pixels: the bot draws the
## screen with and without it and counts the pixels that differ. "Reads at a
## glance" becomes a number a gate can hold.

## Per-channel distance (0..1) from which a pixel counts as changed.
const SEEN := 0.1
## Per-channel steps of this size are soft (an antialiased edge), from HARD up
## they are a staircase edge; smaller ones are flat colour or noise.
const SOFT := 0.08
const HARD := 0.3


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


## Share of the edges in `image` that are soft (0..1): the number of
## neighbouring pixel pairs that step SOFT to HARD, over all that step at
## least SOFT. An antialiased frame scores high, a jagged one low.
static func softness(image: Image) -> float:
	var rgb := image.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	var data := rgb.get_data()
	var wide := rgb.get_width()
	var soft := 0
	var hard := 0
	for y in range(0, rgb.get_height() - 1, 2):
		for x in range(0, wide - 1, 2):
			var at := (y * wide + x) * 3
			for neighbour in [at + 3, at + wide * 3]:
				var step := 0
				for channel in 3:
					step = maxi(step, absi(data[at + channel] - data[neighbour + channel]))
				if step >= HARD * 255.0:
					hard += 1
				elif step >= SOFT * 255.0:
					soft += 1
	return float(soft) / maxf(soft + hard, 1.0)
