extends TestKit
## Stills of a snuffing font and of the lantern the wizard carries (world 28, the cemetery's first
## row): the font close up while the flame can be put out, just after it is put out there, and
## once it has been out a while; and the wizard by the
## font with their flame lit, snuffed and unprotected (no lantern's protection), outside on the
## terraces and inside the crypt's dark. snuffer_*.png, lantern_*.png.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_snuffer.gd

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var fonts: Array[Node] = placed("snuffer.tscn")
	if fonts.is_empty():
		print("FAIL: no snuffing font")
		finish()
		return
	var font: Node2D = fonts[0] as Node2D
	# The enemies go, so nothing strikes the wizard while they stand still for the stills.
	for node: Node in info.map_elements.get_children():
		var type: int = Placeables.type_of(node)
		if type >= 0 and Placeables.has_flag(type as LevelGen.Type, &"enemy"):
			node.queue_free()
	# Wait out the region's title.
	await create_timer(5.0).timeout
	var crypt: Dictionary = info.world.crypts[0]
	var floors: Array[Vector2i] = crypt["floors"]
	var inside: Vector2 = info.cell_position(floors[mini(4, floors.size() - 1)])
	# The font, with the wizard a step away, lit, snuffed and unprotected.
	player.global_position = font.global_position + Vector2(-70, 0)
	await _look(font.global_position + Vector2(-30, -50), "snuffer_lit.png", 3.0)
	player.global_position = font.global_position + Vector2(-240, 0)
	await _look(font.global_position + Vector2(-120, -50), "snuffer_far.png")
	player.global_position = font.global_position + Vector2(-70, 0)
	(font as Snuffer).snuff()
	await _look(font.global_position + Vector2(-30, -50), "snuffer_dip.png", 3.0, 24)
	await _look(font.global_position + Vector2(-30, -50), "snuffer_snuffed.png", 3.0, 200)
	info.relight()
	info.run.vulnerable = true
	await _look(font.global_position + Vector2(-30, -50), "snuffer_unprotected.png", 3.0)
	info.run.vulnerable = false
	# The wizard's lantern close up, outside and in the crypt's dark.
	for place: Array in [["out", font.global_position + Vector2(-70, 0)], ["in", inside]]:
		player.global_position = place[1]
		await _look(player.global_position + Vector2(0, -30), "lantern_%s_lit.png" % place[0], 2.0)
		info.snuff(player.global_position)
		await _look(player.global_position + Vector2(0, -30), "lantern_%s_snuffed.png" % place[0], 2.0)
		info.relight()
		info.run.vulnerable = true
		await _look(player.global_position + Vector2(0, -30), "lantern_%s_unprotected.png" % place[0], 2.0)
		info.run.vulnerable = false
	RunState.delete_save()
	finish()


## Hold the camera on `at` at `zoom` for `hold` frames, then save the still. The wizard's flicker
## after a hit or an arrival is cut short, so it does not hide them.
func _look(at: Vector2, file: String, zoom: float = 1.0, hold: int = 40) -> void:
	var was: Vector2 = camera.zoom
	for i: int in range(hold):
		player.end_invulnerable()
		player.graced.end()
		camera.global_position = at
		camera.zoom = was * zoom
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
