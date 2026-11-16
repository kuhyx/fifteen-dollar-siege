extends SceneTree
## Contact sheets of the code-drawn art, so every pictogram and vignette can be
## looked at side by side (build-game R8). Runs on a private Xvfb through
## scripts/art_sheet.sh, never on the live display:
##   godot --path . -s tools/art_sheet.gd -- <kind> <out.png> [--t=SECONDS] [--id=BUFF]
## kinds: buffs (25 pictograms at card size and large), ui (mode, control and
## key pictograms), vignettes (25 vignettes at one time), vignette (one buff's
## vignette at eight times).

const SETTLE_FRAMES := 4


class Sheet:
	extends Control
	var kind := "buffs"
	var at_s := 0.0
	var buff: StringName = &""

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.PANEL.darkened(0.4))
		match kind:
			"buffs":
				_buffs()
			"buffs_big":
				_buffs_big()
			"ui":
				_ui()
			"vignettes":
				_vignettes()
			"vignette":
				_one_vignette()

	## Six columns of card-sized panels (the size a shop card has), then every
	## buff again large. Crop 900x750 canvas units for the card-size check.
	func _buffs() -> void:
		var defs := BuffCatalog.all()
		for i in defs.size():
			var card := Rect2(Vector2(i % 6, i / 6) * 150.0 + Vector2(4, 4), Vector2(142, 142))
			draw_rect(card, Palette.PANEL)
			BuffPictograms.of(defs[i].id).draw(self, card.grow(-23.0))

	## Nine columns, 200 units each: the drawing itself, large.
	func _buffs_big() -> void:
		var defs := BuffCatalog.all()
		for i in defs.size():
			var corner := Vector2(i % 9, i / 9) * 210.0 + Vector2(10, 10)
			BuffPictograms.of(defs[i].id).draw(self, Rect2(corner, Vector2(200, 200)))

	func _ui() -> void:
		var ids := UiPictograms.ids()
		var cell := Vector2(size.x / 8.0, size.y / 4.0)
		for i in ids.size():
			var corner := Vector2(i % 8, i / 8) * cell
			var picture := UiPictograms.of(ids[i])
			picture.draw(self, Rect2(corner + Vector2(10, 20), Vector2(64, 64)))
			picture.draw(self, Rect2(corner + Vector2(84, 20), Vector2(150, 150)))
		KeyGlyph.draw_sheet(self, Vector2(40, size.y * 0.78), 96.0)

	func _vignettes() -> void:
		var defs := BuffCatalog.all()
		var cell := Vector2(size.x / 5.0, size.y / 5.0)
		for i in defs.size():
			var corner := Vector2(i % 5, i / 5) * cell
			var stage := Rect2(corner + Vector2(6, 4), cell - Vector2(12, 8))
			BuffVignettes.draw(defs[i].id, self, stage, at_s)

	func _one_vignette() -> void:
		var cell := Vector2(size.x / 4.0, size.y / 2.0)
		for i in 8:
			var corner := Vector2(i % 4, i / 4) * cell
			var stage := Rect2(corner + Vector2(6, 6), cell - Vector2(12, 12))
			BuffVignettes.draw(buff, self, stage, BuffVignettes.LOOP_S * i / 8.0)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr(
			"usage: art_sheet.gd -- <buffs|ui|vignettes|vignette> <out.png> [--t=S] [--id=BUFF]"
		)
		quit(2)
		return
	var sheet := Sheet.new()
	sheet.kind = args[0]
	sheet.at_s = float(LaunchOptions.value_of(args, "--t="))
	sheet.buff = StringName(LaunchOptions.value_of(args, "--id="))
	root.add_child(sheet)
	_save.call_deferred(args[1])


func _save(path: String) -> void:
	for i in SETTLE_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var code := image.save_png(path)
	print("art_sheet: %s %dx%d" % [path, image.get_width(), image.get_height()])
	quit(0 if code == OK else 1)
