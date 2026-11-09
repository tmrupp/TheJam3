extends TestKit
## Frames for GIFs of the garden's seeds and plants, played in real physics: a seed pod spitting at
## the wizard, its seeds caught by the guard and sent home until it bursts and drops its seed
## (garden_pod_gif/); and a plot's plant at each stage as if the wizard came back from further each
## time, then picked into a hyperspace door (garden_plant_gif/). Frames go to the stills folder as
## frame_NNN.png, one every EVERY physics steps (played at 30 frames a second); tests/make_gifs.py
## turns them into GIFs. A small worm stirring as the wizard comes near, bursting out under or over
## them, squirming and sinking back (garden_worm_gif/), and a swarm of them round a great bloom
## (garden_swarm_gif/). `-- only=pod` (plant, worm, swarm) takes one of them.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_garden_gif.gd

## How many physics steps apart frames are taken, the middle of the window taken, and the size it is
## scaled to.
const EVERY: int = 3
const CROP: Vector2i = Vector2i(800, 560)
const SIZE: Vector2i = Vector2i(360, 252)
## How much closer than the game's camera the view is: on the pod and the wizard, and on the plot.
const CLOSE: float = 1.2
const PLANT_CLOSE: float = 2.2
## How near (px) a seed comes before the guard goes up to meet it, and how many game seconds a pod is
## given to spit and its seed to arrive.
const MEET_AT: float = 70.0
const SHOT_WAIT: float = 5.0
## How many frames each of a plant's stages is shown for.
const STAGE: int = 45

var camera: Camera2D
var base: Vector2
var frame: int = 0
var dir: String = ""
var view: Vector2 = Vector2.ZERO
## How much closer than the game's camera the view is now (CLOSE, or PLANT_CLOSE for the plot).
var close: float = CLOSE


func run() -> void:
	window()
	await boot(28)
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	base = camera.zoom
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.trim_prefix("only=")
	if only in ["", "pod"]:
		await _pod()
	if only in ["", "plant"]:
		await _plant()
	if only in ["", "worm"]:
		await _worm()
	if only in ["", "swarm"]:
		await _swarm()
	finish()


## Take frames for `steps` physics steps, one every EVERY, centred on `view`.
func _roll(steps: int) -> void:
	for i: int in range(steps):
		camera.zoom = base * close
		# Free of the level's edges, so the view can centre on what it is shooting.
		camera.limit_left = -10000000
		camera.limit_top = -10000000
		camera.limit_right = 10000000
		camera.limit_bottom = 10000000
		camera.global_position = view
		camera.reset_smoothing()
		await physics_frame
		if i % EVERY == 0:
			await process_frame
			var whole: Image = root.get_texture().get_image()
			var still: Image = whole.get_region(Rect2i((whole.get_size() - CROP) / 2, CROP))
			still.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
			save_still("%s/frame_%03d.png" % [dir, frame], still)
			frame += 1


## Roll frames until `cond` holds or `seconds` of game time pass; whether it held.
func _roll_until(cond: Callable, seconds: float) -> bool:
	var steps: int = int(seconds * Engine.physics_ticks_per_second)
	for i: int in range(steps):
		if cond.call():
			return true
		await _roll(1)
	return cond.call()


func _pod() -> void:
	dir = "garden_pod_gif"
	frame = 0
	# A pod with a floor in its sight near it, for the wizard to stand on.
	for row: int in range(1, Bands.garden_rows()):
		var w: LevelGen = build(Vector2i(28, row))
		if w.objects_of(LevelGen.Type.POD).is_empty():
			continue
		info.coord = Vector2i(28, row)
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		for n: Node in placed("seed_pod.tscn"):
			var body: RigidBody2D = n as RigidBody2D
			var pod: SeedPod = body.get_node("SeedPod") as SeedPod
			var cell: Vector2i = body.get_meta(&"cell")
			for d: int in range(2, 5):
				var spot: Vector2i = cell + Vector2i(pod.way) * d
				for drop: int in range(0, 4):
					var at: Vector2i = spot + Vector2i(0, drop)
					if not _safe(at):
						continue
					player.global_position = info.cell_position(at)
					still()
					info.loader.wake_around(body.global_position)
					await settle(6)
					if pod.sees:
						await _parry(body, pod)
						return
	check(false, "a pod with a floor in its sight")


## Whether the wizard can stand at `at` unhurt: an empty cell on plain rock, no thorns beside it.
func _safe(at: Vector2i) -> bool:
	var w: LevelGen = info.world
	if not w.is_valid(at) or not w.is_valid(at + Vector2i.DOWN) or w.get_cell(at).type != LevelGen.Type.EMPTY or w.get_cell(at + Vector2i.DOWN).type != LevelGen.Type.GROUND:
		return false
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i(-1, 1), Vector2i(1, 1)]:
		if w.is_valid(at + d) and w.get_cell(at + d).type == LevelGen.Type.SPIKES:
			return false
	return true


## The wizard, standing in its sight, catches its seeds with the guard until it bursts (the catch
## made as a press in time makes it, Parry.parry, as each seed reaches them), its seed then falling.
func _parry(body: RigidBody2D, pod: SeedPod) -> void:
	for scene: String in ["shooter_enemy.tscn", "mover_enemy.tscn", "hopper_enemy.tscn"]:
		for foe: Node in placed(scene):
			foe.queue_free()
	view = (body.global_position + player.global_position) * 0.5 + Vector2(0, -40)
	var place: Vector2i = info.coord
	var burst: Array[bool] = [false]
	(body.get_node("Wound") as Wound).slain.connect(func() -> void: burst[0] = true)
	var guard: Parry = player.get_node("Parry") as Parry
	player.health.health = player.health.max_health
	await _roll(15)
	var near: Callable = func() -> Bullet:
		for n: Node in info.map_elements.get_children():
			var b: Bullet = n as Bullet
			if b != null and not b.is_queued_for_deletion() and b.seed and b.global_position.distance_to(player.global_position) < MEET_AT:
				return b
		return null
	for k: int in range(4):
		if burst[0] or info.coord != place:
			break
		if not await _roll_until(func() -> bool: return near.call() != null, SHOT_WAIT):
			break
		var shot: Bullet = near.call() as Bullet
		guard.parry(1, Vector2.ZERO, shot.get_node("HitBox/Damager"))
		await _roll(30)
	await _roll(45)
	check(burst[0] and info.coord == place, "the pod is burst by its own seeds")


func _plant() -> void:
	dir = "garden_plant_gif"
	frame = 0
	var home: Vector2i = Vector2i(28, 0)
	info.coord = home
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var plots: Array[Node] = placed("plot.tscn")
	if plots.is_empty():
		check(false, "the start level has its plot")
		return
	var plot: Plot = plots[0] as Plot
	for scene: String in ["shooter_enemy.tscn", "mover_enemy.tscn", "hopper_enemy.tscn"]:
		for foe: Node in placed(scene):
			foe.queue_free()
	player.global_position = plot.global_position + Vector2(-130, 0)
	still()
	# Standing there until the grace of arriving has worn off (it shimmers while it lasts).
	await within(func() -> bool: return not player.is_invulnerable(), 5.0)
	close = PLANT_CLOSE
	view = plot.global_position + Vector2(-50, -50)
	info.loader.wake_around(plot.global_position)
	await _roll(STAGE)
	player.keyring.set_seeds(1)
	plot.use()
	await _roll(STAGE)
	for far: int in Plot.TIERS:
		info.run.reached(home + Vector2i(far, 0))
		await _roll(STAGE)
	plot.use()
	await _roll(STAGE * 2)
	check(plot.door(), "the plant is picked into a hyperspace door")


## A small worm near the start: the wizard stands by its home while it warns, comes out, squirms and
## sinks, a few times over.
func _worm() -> void:
	dir = "garden_worm_gif"
	frame = 0
	close = PLANT_CLOSE * 0.8
	for row: int in range(1, Bands.garden_rows()):
		if build(Vector2i(28, row)).objects_of(LevelGen.Type.WORMLET).is_empty():
			continue
		info.coord = Vector2i(28, row)
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		for n: Node in placed("wormlet.tscn", true):
			var body: RigidBody2D = n as RigidBody2D
			var home: Vector2i = body.get_meta(&"cell")
			var stand: Vector2i = Vector2i(-1, -1)
			for dx: int in [0, -1, 1, -2, 2, -3, 3]:
				for dy: int in [0, -1, 1]:
					if stand.x < 0 and _safe(home + Vector2i(dx, dy)):
						stand = home + Vector2i(dx, dy)
			if stand.x < 0:
				continue
			for scene: String in ["shooter_enemy.tscn", "mover_enemy.tscn", "hopper_enemy.tscn", "seed_pod.tscn"]:
				for foe: Node in placed(scene, true):
					foe.queue_free()
			player.global_position = info.cell_position(stand)
			still()
			info.loader.wake_around(body.global_position)
			await within(func() -> bool: return not player.is_invulnerable(), 5.0)
			view = info.cell_position(stand) + Vector2(0, -40)
			for k: int in range(8):
				player.health.health = player.health.max_health
				await _roll(20)
			return
	check(false, "a small worm on a floor near the start")


## A plant grown to a great bloom in the start level, a swarm of small worms round it, and the wizard
## by the plot as they come up round them.
func _swarm() -> void:
	dir = "garden_swarm_gif"
	frame = 0
	close = 1.3
	var home: Vector2i = Vector2i(28, 0)
	info.run.plants[home] = {"furthest": Plot.TIERS[2], "door": false}
	info.coord = home
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var plots: Array[Node] = placed("plot.tscn")
	if plots.is_empty():
		check(false, "the start level has its plot")
		return
	var plot: Plot = plots[0] as Plot
	for scene: String in ["shooter_enemy.tscn", "mover_enemy.tscn", "hopper_enemy.tscn"]:
		for foe: Node in placed(scene, true):
			foe.queue_free()
	player.global_position = plot.global_position + Vector2(-130, 0)
	still()
	info.loader.wake_around(plot.global_position)
	await within(func() -> bool: return not player.is_invulnerable(), 5.0)
	view = plot.global_position + Vector2(-60, -60)
	for k: int in range(9):
		player.health.health = player.health.max_health
		await _roll(20)
	info.run.plants.erase(home)
