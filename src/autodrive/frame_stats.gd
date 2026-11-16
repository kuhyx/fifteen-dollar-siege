class_name FrameStats
extends RefCounted
## Blank-frame detection for screenshots (the gate must fail closed).

const MIN_STDDEV := 3.0
const MIN_RANGE := 24.0
const SAMPLES_PER_AXIS := 160


## {"mean", "stddev", "range"} of the sampled luminance (0..255).
static func luminance(image: Image) -> Dictionary:
	var width := image.get_width()
	var height := image.get_height()
	if width == 0 or height == 0:
		return {"mean": 0.0, "stddev": 0.0, "range": 0.0}
	var step_x := maxi(1, width / SAMPLES_PER_AXIS)
	var step_y := maxi(1, height / SAMPLES_PER_AXIS)
	var count := 0
	var total := 0.0
	var total_sq := 0.0
	var low := 255.0
	var high := 0.0
	for y in range(0, height, step_y):
		for x in range(0, width, step_x):
			var c := image.get_pixel(x, y)
			var lum := (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
			count += 1
			total += lum
			total_sq += lum * lum
			low = minf(low, lum)
			high = maxf(high, lum)
	var mean := total / count
	var variance := maxf(0.0, total_sq / count - mean * mean)
	return {"mean": mean, "stddev": sqrt(variance), "range": high - low}


static func is_blank(image: Image) -> bool:
	if image == null:
		return true
	var stats := luminance(image)
	return stats["stddev"] < MIN_STDDEV or stats["range"] < MIN_RANGE
