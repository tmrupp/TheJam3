extends TestKit
## Frames of the abominations at work in an institute level (world 28, its first), for a GIF: on a
## long floor, a breach at one end letting them out, an abomination of BIG blobs by it, and a class
## (a master and its students) bunched at the other end, so the first grow and fling unhurt a while;
## then they crawl at the class and bite, the students and their master cast at them, and they grow
## blobs and fling new ones off, more and more. The wizard hangs projected overhead, so nothing goes
## for them. Light by sight is off, so the floor prints evenly. Frames go to the stills folder's
## abomination_gif/ as frame_NNN.png, a frame every EVERY physics steps (so at 12 frames a second
## it plays at the game's own speed), scaled to SIZE; turn them into a GIF with ffmpeg (see
## docs/RISO_PRINT.md).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_abomination_gif.gd

## How many frames are taken, how many physics steps apart, and their size.
const FRAMES: int = 200
const EVERY: int = 5
const SIZE: Vector2i = Vector2i(640, 360)
## How long the floor must be (cells, with a row of headroom), and how often (seconds) the
## abominations grow a blob here (sooner than in play, so the swarm grows within the clip).
const LONG: int = 10
const GROW: float = 1.2
## How soon (seconds) after a launch the next may come here (sooner than in play, likewise).
const LAUNCH: float = 3.5
## How long (seconds) the class holds its first casts.
const HOLD: float = 6.0
## How many blobs the abomination the clip opens on has (one short of flinging one off).
const BIG: int = 5
## The camera's zoom, against the game's own.
const ZOOM: float = 1.7

var camera: Camera2D
var base_zoom: Vector2 = Vector2.ONE


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	base_zoom = camera.zoom
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"institute"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	RisoLight.by_sight = false
	var spot: Variant = _long_floor()
	if spot == null:
		check(false, "a floor long enough")
		finish()
		return
	var at: Vector2i = spot
	# Clear the stretch of anything already there that moves.
	for node: Node in info.map_elements.get_children():
		var n2: Node2D = node as Node2D
		if n2 != null and node.has_meta(&"cell") and Placeables.has_flag(Placeables.type_of(node), &"enemy"):
			var c: Vector2i = info.cell_at(n2.global_position)
			if absi(c.y - at.y) <= 3 and c.x >= at.x - 3 and c.x <= at.x + LONG + 3:
				node.queue_free()
	var breach: Breach = (load("res://prefabs/breach.tscn") as PackedScene).instantiate() as Breach
	LevelLoader.arm(breach, info.here.depth)
	info.map_elements.add_child(breach)
	breach.global_position = info.cell_position(at + Vector2i(1, 0))
	breach.setup(info, at + Vector2i(1, 0))
	breach.set_physics_process(false)
	# The class bunched at the far end, so the abominations grow and fling unhurt a while first.
	var master: Scholar = _scholar("master.tscn", at + Vector2i(LONG - 1, 0), &"nova")
	for k: int in [1, 2]:
		_scholar("student.tscn", at + Vector2i(LONG - 1 - k, 0), &"")
	master.facing = -1.0
	var mid: Vector2i = at + Vector2i(int(LONG * 0.5), 0)
	player.global_position = info.cell_position(mid + Vector2i(0, -2))
	player.phasing = true
	var middle: Vector2 = info.cell_position(mid) + Vector2(-64, -70)
	# Long enough for the region's title card to go.
	for i: int in range(480):
		_hold(middle)
		await process_frame
	# Then one of BIG blobs by the breach, about to fling its first, and the breach awake.
	var big: Abomination = (load("res://prefabs/abomination.tscn") as PackedScene).instantiate() as Abomination
	LevelLoader.arm(big, info.here.depth)
	big.sprout(BIG)
	info.map_elements.add_child(big)
	big.global_position = info.cell_position(at + Vector2i(3, 0))
	# Its first launch ready, so the clip opens on its tell.
	big.launch_in = 0.0
	# The class holds its first casts a while, so the tell and the launch play out first.
	for node: Node in get_nodes_in_group(&"scholar"):
		(node as Scholar).cast_in = HOLD
	breach.wait = 3.0
	breach.set_physics_process(true)
	var dir: String = ProjectSettings.globalize_path(STILLS).path_join("abomination_gif")
	DirAccess.make_dir_recursive_absolute(dir)
	for k: int in range(FRAMES):
		for i: int in range(EVERY):
			_hold(middle)
			player.phasing = true
			# They grow sooner here, so the swarm grows within the clip.
			for node: Node in get_nodes_in_group(&"abomination"):
				var a: Abomination = node as Abomination
				if a != null and a.grow_in > GROW:
					a.grow_in = GROW
				if a != null and a.launch_in > LAUNCH:
					a.launch_in = LAUNCH
			# Paced by physics steps, not rendered frames: the window renders faster than physics
			# steps, so counting frames would film the game in slow motion.
			await physics_frame
		await process_frame
		var image: Image = root.get_texture().get_image()
		image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		image.save_png(dir.path_join("frame_%03d.png" % k))
	print("CAPTURED %d frames to %s" % [FRAMES, dir])
	RisoLight.by_sight = true
	RunState.delete_save()
	finish()


func _hold(at: Vector2) -> void:
	camera.zoom = base_zoom * ZOOM
	camera.global_position = at
	camera.reset_smoothing()


func _scholar(scene: String, v: Vector2i, ability: StringName) -> Scholar:
	var node: Scholar = (load("res://prefabs/" + scene) as PackedScene).instantiate() as Scholar
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(v)
	node.setup(info, v, {"ability": ability, "hall": -1})
	return node


## The first stretch of open floor LONG cells long with a row of headroom, out of the halls, as
## its left cell; null if none.
func _long_floor() -> Variant:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var ok: bool = true
		for k: int in range(-1, LONG + 1):
			var c: Vector2i = v + Vector2i(k, 0)
			if not w.is_valid(c) or w.is_ground(c) or not w.is_ground(c + Vector2i.DOWN) or w.is_ground(c + Vector2i.UP) or Institute.hall_at(w, c) >= 0:
				ok = false
				break
		if ok:
			return v
	return null
