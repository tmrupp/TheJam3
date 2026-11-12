extends TestKit
## Close-up sheets of a wisp's moves (Mover, WispArt), world 28's first level, each COLUMNS across,
## the camera on the wisp: wisp_lurch.png, walking, then its wind-up (drawing back, squat and coiled,
## its glow heating), the lurch (long and thin) and the rest after, and wisp_lurch_bare.png, the
## same without its tell printed over it; wisp_fall.png, dropped from a few cells up, tipping into
## its fall, landing and settling; wisp_stun.png, stunned. And the
## wizard's feather popping as it fills again (RisoCostume.RECHARGE_TIME), in feather_pop.png.
## godot --path . --windowed --resolution 1280x720 --fixed-fps 60 --script res://tests/capture_wisp_lurch.gd

const COLUMNS: int = 6
## The still's size (px) and the camera's zoom against the game's own.
const SHOT: Vector2i = Vector2i(360, 300)
const ZOOM: float = 4.0
## Where the camera looks, from the wisp's origin.
const AIM: Vector2 = Vector2(0, -28)
## How many cells up the wisp is dropped from (fewer where the level has no such room), and how many
## stills are kept of its fall.
const DROP_CELLS: int = 4
const FALL_SHOTS: int = 6
## Physics steps after it lands at which a still is taken.
const LANDED: Array[int] = [1, 3, 5, 8, 12, 20]
## The feather's stills: their size, zoom, and how many physics steps apart.
const FEATHER_SHOT: Vector2i = Vector2i(240, 240)
const FEATHER_ZOOM: float = 3.5
const FEATHER_EVERY: int = 3

var camera: Camera2D


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	var base: Vector2 = camera.zoom
	freeze()
	player.get_node("CameraControl").set_process(false)
	player.end_invulnerable()
	Health.invincible = true
	# Everything is printed as lit, however far the wizard is.
	RisoLight.by_sight = false
	player.global_position = Vector2(-9000, -9000)
	for other: Node in placed("mover_enemy.tscn"):
		other.queue_free()
	await process_frame
	# A run of floor to lurch along, and a floor with as much open air over it as there is,
	# DROP_CELLS at most, to drop it onto.
	var spot: Vector2i = floor_run(3, 1, true)
	check(spot.x >= 0, "a run of floor to lurch along")
	var drop: int = DROP_CELLS
	var under: Vector2i = floor_run(0, drop + 1)
	while under.x < 0 and drop > 1:
		drop -= 1
		under = floor_run(0, drop + 1)
	check(under.x >= 0, "a floor with open air over it (%d cells)" % drop)
	camera.zoom = base * ZOOM
	# A wisp of the capture's own (one of the level's sleeps with the part of the level it began in).
	var w: Node2D = Placeables.scene(LevelGen.Type.ENEMY).instantiate() as Node2D
	LevelLoader.arm(w, info.here.depth)
	info.map_elements.add_child(w)
	w.global_position = info.cell_position(spot)
	var mover: Mover = w.get_node("Mover") as Mover
	look(w.global_position + AIM)
	await frames(3)
	await stand(w, spot)
	save_still("wisp_lurch.png", sheet(await lurch_shots(w, spot, false), SHOT))
	await stand(w, spot)
	save_still("wisp_lurch_bare.png", sheet(await lurch_shots(w, spot, true), SHOT))

	# The fall: dropped from DROP_CELLS up, every step of it recorded and a few kept.
	player.global_position = Vector2(-9000, -9000)
	await stand(w, under)
	mover.lurch_wait = 99.0
	mover.set_physics_process(false)
	w.global_position = info.cell_position(under - Vector2i(0, drop))
	await frames(2)
	mover.fall_speed = 0.0
	mover.grounded = false
	mover.set_physics_process(true)
	var falling: Array[Image] = []
	for i: int in range(120):
		await physics_frame
		falling.append(await shot_of(w))
		if mover.grounded:
			break
	var falls: Array[Image] = []
	for k: int in range(FALL_SHOTS):
		falls.append(falling[roundi(float(k + 1) / float(FALL_SHOTS + 1) * float(falling.size() - 1))])
	var step: int = 0
	for at: int in LANDED:
		while step < at:
			await physics_frame
			step += 1
		falls.append(await shot_of(w))
	save_still("wisp_fall.png", sheet(falls, SHOT))

	# Stunned, and waking.
	await stand(w, spot)
	mover.lurch_wait = 99.0
	var dazed: Array[Image] = [await shot_of(w)]
	Stunner.of(w).stun(1.6)
	for i: int in range(5):
		await frames(12)
		dazed.append(await shot_of(w))
	save_still("wisp_stun.png", sheet(dazed, SHOT))
	Health.invincible = false

	# The feather filling again, the wizard standing still.
	RisoLight.by_sight = true
	player.global_position = info.respawn_marker.global_position
	player.set_physics_process(true)
	await until(func() -> bool: return player.is_on_floor())
	freeze()
	camera.zoom = base * FEATHER_ZOOM
	var hat: Vector2 = player.global_position + Vector2(-10, -80)
	look(hat)
	player.dash.acted = true
	await frames(10)
	var pops: Array[Image] = [shot(FEATHER_SHOT)]
	player.dash.acted = false
	for i: int in range(7):
		await frames(FEATHER_EVERY)
		look(hat)
		pops.append(shot(FEATHER_SHOT))
	save_still("feather_pop.png", sheet(pops, FEATHER_SHOT))
	finish()


## Stills of the wisp, standing at `spot`, lurching at the wizard: walking, through its wind-up, its
## lurch (the wizard gone once it is off, so nothing stands over it) and its rest; `bare`, without
## its tell.
func lurch_shots(w: Node2D, spot: Vector2i, bare: bool) -> Array[Image]:
	var mover: Mover = w.get_node("Mover") as Mover
	var art: RisoProp = null
	for c: Node in w.get_children():
		if c is RisoProp:
			art = c as RisoProp
	var hide: Callable = func() -> void:
		if bare and art.tell_ink != null:
			art.tell_ink.visible = false
	process_frame.connect(hide)
	var shots: Array[Image] = [await shot_of(w)]
	player.global_position = info.cell_position(spot) + Vector2(190, -15)
	for want: float in [0.2, 0.4, 0.6, 0.8, 0.97]:
		await within(func() -> bool: return mover.winding >= want or mover.lurching >= 0.0, 1.0)
		shots.append(await shot_of(w))
	for want: float in [0.05, 0.25, 0.6]:
		await within(func() -> bool: return mover.lurching >= want or mover.resting > 0.0, 1.0)
		player.global_position = Vector2(-9000, -9000)
		shots.append(await shot_of(w))
	await within(func() -> bool: return mover.resting > 0.0, 1.0)
	for wait: int in [2, 6, 14]:
		await frames(wait)
		shots.append(await shot_of(w))
	process_frame.disconnect(hide)
	if art.tell_ink != null:
		art.tell_ink.visible = true
	return shots


## A floor cell with `n` more floor cells to its right, nothing in a wisp's way along them and
## `high` cells clear of rock over each: the first there is or, `barest`, the one with the fewest
## things standing along it (they print over a wisp passing them); (-1, -1) if there is none.
func floor_run(n: int, high: int, barest: bool = false) -> Vector2i:
	var world: LevelGen = info.world
	var best: Vector2i = Vector2i(-1, -1)
	var fewest: int = n + 2
	for y: int in range(world.size.y):
		for x: int in range(world.size.x):
			var v: Vector2i = Vector2i(x, y)
			var ok: bool = true
			var things: int = 0
			for k: int in range(n + 1):
				var c: Vector2i = v + Vector2i.RIGHT * k
				ok = ok and world.is_valid(c) and world.ground_below(c) and world.get_cell(c).type not in [LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.SPIKES, LevelGen.Type.PLATFORM, LevelGen.Type.LASER]
				for up: int in range(high):
					var over: Vector2i = c - Vector2i(0, up)
					ok = ok and world.is_valid(over) and not world.is_ground(over) and world.get_cell(over).type != LevelGen.Type.CRACKED
				if ok and world.get_cell(c).type != LevelGen.Type.EMPTY:
					things += 1
			if ok and not barest:
				return v
			if ok and things < fewest:
				fewest = things
				best = v
	return best


## Put the wisp on `cell`, facing right and fresh (no lurch under way or waited out), the camera on
## it, and wait for it to settle on the floor, held where it stands meanwhile (as its Mover holds it
## through a turn).
func stand(w: Node2D, cell: Vector2i) -> void:
	var mover: Mover = w.get_node("Mover") as Mover
	await until(func() -> bool: return not Stunner.of(w).stunned())
	mover.set_physics_process(false)
	w.global_position = info.cell_position(cell)
	look(w.global_position + AIM)
	await until(func() -> bool: return info.loader.is_awake(w))
	await frames(2)
	mover.winding = -1.0
	mover.lurching = -1.0
	mover.resting = 0.0
	mover.lurch_wait = 0.0
	mover.turn_left = 0.0
	if mover.direction != 1:
		mover.turn()
		mover.turn_left = 0.0
	# Moved, it is off its floor until its Mover finds it again; then it settles from the drop.
	mover.grounded = false
	mover.set_physics_process(true)
	await until(func() -> bool: return mover.grounded)
	for i: int in range(50):
		mover.turn_left = 0.1
		await physics_frame
	mover.turn_left = 0.0
	mover.lurch_wait = 0.0


## The camera anywhere (its limits lifted), on `at`, the level about it awake.
func look(at: Vector2) -> void:
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	camera.global_position = at
	camera.reset_smoothing()
	info.loader.wake_around(at)


## The wisp as drawn a frame from now, the camera on it, the still cut out round where it has got to
## by then (lurching, it outruns the camera).
func shot_of(w: Node2D) -> Image:
	look(w.global_position + AIM)
	await RenderingServer.frame_post_draw
	var whole: Image = root.get_texture().get_image()
	var view: Vector2 = root.get_visible_rect().size
	var on_screen: Vector2 = ((w.global_position + AIM - camera.get_screen_center_position()) * camera.zoom + view * 0.5) * (Vector2(whole.get_size()) / view)
	var corner: Vector2i = (Vector2i(on_screen) - SHOT / 2).clamp(Vector2i.ZERO, whole.get_size() - SHOT)
	return whole.get_region(Rect2i(corner, SHOT))


## The middle `size` of the window as drawn now.
func shot(size: Vector2i) -> Image:
	var whole: Image = root.get_texture().get_image()
	return whole.get_region(Rect2i((whole.get_size() - size) / 2, size))


## `shots` laid out COLUMNS across.
func sheet(shots: Array[Image], size: Vector2i) -> Image:
	var rows: int = ceili(float(shots.size()) / float(COLUMNS))
	var out: Image = Image.create(size.x * COLUMNS, size.y * rows, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(Vector2i.ZERO, size), Vector2i((k % COLUMNS) * size.x, (k / COLUMNS) * size.y))
	return out
