extends TestKit
## A close-up sheet of an abomination dragging itself along an institute floor (world 28, its first
## level) toward the wizard, the camera following it: FRAMES stills, a still every EVERY physics steps,
## laid out COLUMNS across in abomination_crawl.png: going steadily along the floor, its tentacles
## writhing round it, its slime trail behind it.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_abomination_crawl.gd

const FRAMES: int = 12
const EVERY: int = 4
const COLUMNS: int = 3
## The still's size (px) and the camera's zoom against the game's own.
const SHOT: Vector2i = Vector2i(560, 300)
const ZOOM: float = 3.0
## How many blobs it has.
const LOBES: int = 3

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	var base: Vector2 = camera.zoom
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"institute"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	RisoLight.by_sight = false
	var spot: Variant = _floor(9)
	if spot == null:
		check(false, "a floor long enough")
		finish()
		return
	var at: Vector2i = spot
	player.global_position = info.cell_position(at + Vector2i(5, 0))
	player.invulnerable.enable(true)
	player.invulnerable.acting = 999.0
	# Long enough for the region's title card to go; then it comes, and a moment to set off.
	for i: int in range(420):
		camera.zoom = base * ZOOM
		camera.global_position = info.cell_position(at)
		camera.reset_smoothing()
		await process_frame
	var thing: Abomination = (load("res://prefabs/abomination.tscn") as PackedScene).instantiate() as Abomination
	LevelLoader.arm(thing, info.here.depth)
	thing.sprout(LOBES)
	info.map_elements.add_child(thing)
	thing.global_position = info.cell_position(at)
	thing.grow_in = 999.0
	thing.launch_in = 999.0
	for i: int in range(20):
		_follow(thing, base)
		await process_frame
	var sheet: Image = null
	var rows: int = ceili(float(FRAMES) / float(COLUMNS))
	for k: int in range(FRAMES):
		for i: int in range(EVERY):
			_follow(thing, base)
			await physics_frame
		await process_frame
		var image: Image = root.get_texture().get_image()
		var region: Image = image.get_region(Rect2i((image.get_size() - SHOT) / 2, SHOT))
		if sheet == null:
			sheet = Image.create(SHOT.x * COLUMNS, SHOT.y * rows, false, region.get_format())
		sheet.blit_rect(region, Rect2i(Vector2i.ZERO, SHOT), Vector2i((k % COLUMNS) * SHOT.x, (k / COLUMNS) * SHOT.y))
	save_still("abomination_crawl.png", sheet)
	if is_instance_valid(thing):
		thing.queue_free()
	await _shapes(at, base)
	RisoLight.by_sight = true
	RunState.delete_save()
	finish()


## A row of SHAPES abominations of every size from one blob to SPLIT, each its own shape, standing
## still on the floor from `at`: abomination_shapes.png.
const SHAPES: int = 6

func _shapes(at: Vector2i, base: Vector2) -> void:
	var row: Array[Abomination] = []
	for i: int in range(SHAPES):
		var a: Abomination = (load("res://prefabs/abomination.tscn") as PackedScene).instantiate() as Abomination
		LevelLoader.arm(a, info.here.depth)
		a.sprout(1 + i % Abomination.SPLIT)
		info.map_elements.add_child(a)
		a.global_position = info.cell_position(at + Vector2i(i + 1, 0))
		a.grow_in = 999.0
		a.launch_in = 999.0
		row.append(a)
	# Nothing to go for (the wizard projected), so they settle onto the floor where they are.
	player.phasing = true
	for i: int in range(30):
		await physics_frame
	for a: Abomination in row:
		a.set_physics_process(false)
		a.facing = 1.0
	player.global_position = info.cell_position(at + Vector2i(SHAPES + 3, 0))
	for i: int in range(40):
		camera.zoom = base * 1.6
		camera.global_position = info.cell_position(at + Vector2i(SHAPES / 2, 0)) + Vector2(64, -40)
		camera.reset_smoothing()
		await process_frame
	save_still("abomination_shapes.png")


func _follow(thing: Node2D, base: Vector2) -> void:
	camera.zoom = base * ZOOM
	if is_instance_valid(thing):
		camera.global_position = thing.global_position + Vector2(0, -20)
	camera.reset_smoothing()


## The first stretch of open floor `long` cells long with a row of headroom, out of the halls.
func _floor(long: int) -> Variant:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var ok: bool = true
		for k: int in range(-1, long + 1):
			var c: Vector2i = v + Vector2i(k, 0)
			if not w.is_valid(c) or w.is_ground(c) or not w.is_ground(c + Vector2i.DOWN) or w.is_ground(c + Vector2i.UP) or Institute.hall_at(w, c) >= 0:
				ok = false
				break
		if ok:
			return v
	return null
