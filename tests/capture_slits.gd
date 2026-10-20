extends TestKit
## Stills of the crags' arrow slits (RisoDecor's "slit"), cut as a crossbow's are but empty, beside a
## crossbow (CrossbowArt): one through a wall with its room on one side and open air on the other,
## one facing only its room, one seen only from outside, and a tower's crossbow. Written as one
## row (slits.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_slits.gd

const SIZE: int = 420


func run() -> void:
	window()
	await boot(28)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.set_physics_process(false)
	var shots: Array[Image] = []
	var want: Array[String] = ["through", "room", "outside"]
	var found: Dictionary = {}
	var bow_at: Vector2 = Vector2.INF
	# The band's levels in turn, until each kind of slit and a crossbow have been seen.
	for k: int in range(NextWorldDef.BAND):
		info.coord = Vector2i(28, NextWorldDef.band_row(&"crags", k))
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.set_physics_process(false)
		player.global_position = Vector2(-9000, -9000)
		var decor: RisoDecor = main.get_node("RisoDecor") as RisoDecor
		for item: Dictionary in decor.items:
			if item["kind"] != &"slit":
				continue
			var inner: int = int(item["inner"])
			var outer: int = int(item["outer"])
			var kind: String = "through" if inner != 0 and outer != 0 else ("room" if inner != 0 else "outside")
			if not found.has(kind):
				found[kind] = await _shot(camera, info.cell_position(item["cell"]))
		if bow_at == Vector2.INF:
			for n: Node in placed("crossbow.tscn"):
				var bow: Crossbow = n as Crossbow
				if info.world.structures.get(bow.cell + Vector2i(bow.facing, 0), &"") == &"tower":
					bow_at = bow.global_position
					found["bow"] = await _shot(camera, bow_at)
					break
		if want.all(func(w: String) -> bool: return found.has(w)) and found.has("bow"):
			break
	for kind: String in want + ["bow"]:
		print("%s: %s" % [kind, "found" if found.has(kind) else "none"])
		if found.has(kind):
			shots.append(found[kind])
	var sheet: Image = Image.create(SIZE * shots.size(), SIZE, false, shots[0].get_format())
	for k: int in range(shots.size()):
		sheet.blit_rect(shots[k], Rect2i(0, 0, SIZE, SIZE), Vector2i(k * SIZE, 0))
	save_still("slits.png", sheet)
	RunState.delete_save()
	finish()


## A close-up round `at`, the camera on it.
func _shot(camera: Camera2D, at: Vector2) -> Image:
	for i: int in range(12):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * at)
	@warning_ignore("integer_division")
	var x: int = clampi(int(sp.x) - SIZE / 2, 0, 1280 - SIZE)
	@warning_ignore("integer_division")
	var y: int = clampi(int(sp.y) - SIZE / 2, 0, 720 - SIZE)
	return root.get_texture().get_image().get_region(Rect2i(x, y, SIZE, SIZE))
