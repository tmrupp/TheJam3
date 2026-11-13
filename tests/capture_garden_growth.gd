extends TestKit
## The garden's seed pods and plants, close up: a pod at rest and swelling toward a seed
## (garden_pod_rest.png, garden_pod_swelling.png), a seed lying (garden_seed.png) where it was flung from the pod (garden_seed_flung.png), and a plot bare
## and with its plant at each tier, a sprout to the door's great bloom (garden_plot_<n>.png, -1 bare),
## the wizard at the bare plot with no seed and carrying one beside one lying (garden_plot_prompt.png,
## garden_seed_carried.png),
## a small worm's warning in the rock, the worm coming up out of its hole, out on the floor, and
## diving into a new hole (garden_worm_warn.png, garden_worm_rise.png, garden_worm_out.png,
## garden_worm_sink.png), each also at the game's own zoom (…_game.png).
## godot --path . --windowed --resolution 1280x720 --screen 1 --script res://tests/capture_garden_growth.gd

## How much closer than the game's camera the close-up is, and the size of each still's crop.
const CLOSE: float = 3.0
const CROP: Vector2i = Vector2i(560, 520)
const CROP_GAME: Vector2i = Vector2i(240, 220)

var camera: Camera2D
var base: Vector2


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	base = camera.zoom
	await _pod()
	await _plot()
	await _worm()
	finish()


func _pod() -> void:
	var at: Vector2i = Vector2i(-1, -1)
	for row: int in range(1, Bands.garden_rows()):
		if not build(Vector2i(28, row)).objects_of(LevelGen.Type.POD).is_empty():
			at = Vector2i(28, row)
			break
	if at.x < 0:
		check(false, "a garden level with a pod")
		return
	await go(at)
	var body: Node2D = placed("seed_pod.tscn")[0] as Node2D
	var pod: SeedPod = body.get_node("SeedPod") as SeedPod
	# Far off, so it does not see the wizard and spit while it is photographed.
	player.global_position = body.global_position + Vector2(0, 4000)
	info.loader.wake_around(body.global_position)
	for state: Array in [["rest", 0.0], ["swelling", 0.85]]:
		await _shoot(body.global_position, "garden_pod_%s" % state[0], func() -> void: pod.charge = float(state[1]))
	# Its seed, flung out from it as it bursts (SeedPod.shoved), photographed where it comes to rest.
	info.drop_seed(SeedPod.shoved(info, body.global_position, pod.way), body.global_position)
	await settle()
	await within(func() -> bool: return false, SeedPod.SHOVE_TIME + 0.1)
	var seeds: Array[Node] = colored("key.tscn", KeyRing.SEED)
	if not seeds.is_empty():
		await _shoot((seeds[0] as Node2D).global_position, "garden_seed", Callable())
		await _shoot(((seeds[0] as Node2D).global_position + body.global_position) * 0.5, "garden_seed_flung", Callable())


func _plot() -> void:
	await go(Vector2i(28, 0))
	var plots: Array[Node] = placed("plot.tscn")
	if plots.is_empty():
		check(false, "the start level has a plot")
		return
	var plot: Node2D = plots[0] as Node2D
	player.global_position = plot.global_position + Vector2(0, 4000)
	info.loader.wake_around(plot.global_position)
	await _shoot(plot.global_position + Vector2(0, -20), "garden_plot_bare", Callable())
	for tier: int in range(4):
		info.run.plants[info.coord] = {"furthest": 0 if tier == 0 else Plot.TIERS[tier - 1], "door": false}
		await _shoot(plot.global_position + Vector2(0, -20), "garden_plot_%d" % tier, Callable())
	info.run.plants.clear()
	# The wizard at the bare plot with no seed (its prompt shows the seed it wants), then carrying one
	# beside one lying (the two the same size).
	player.global_position = plot.global_position
	still()
	await settle(10)
	await _shoot(plot.global_position + Vector2(0, -60), "garden_plot_prompt", Callable())
	player.keyring.set_seeds(1)
	var lying: Vector2 = plot.global_position + Vector2(-170, -20)
	info.drop_seed(lying, lying)
	await settle(30)
	await _shoot(plot.global_position + Vector2(-60, -60), "garden_seed_carried", Callable())
	player.keyring.set_seeds(0)


func _worm() -> void:
	for row: int in range(1, Bands.garden_rows()):
		if build(Vector2i(28, row)).objects_of(LevelGen.Type.WORMLET).is_empty():
			continue
		await go(Vector2i(28, row))
		var body: RigidBody2D = placed("wormlet.tscn", true)[0] as RigidBody2D
		var worm: Wormlet = body.get_node("Wormlet") as Wormlet
		var home: Vector2i = body.get_meta(&"cell")
		# Far off, so it does not stir by itself while it is photographed.
		player.global_position = body.global_position + Vector2(0, 4000)
		info.loader.wake_around(body.global_position)
		var floor_at: Vector2 = info.cell_position(home) + Vector2(0, 30)
		await _shoot(floor_at, "garden_worm_warn", func() -> void:
			worm.face = home
			worm.from_ceiling = false
			worm.state = Wormlet.State.WARN
			worm.timer = Wormlet.WARN_TIME * 0.35)
		var lying: Vector2 = worm._on_floor(info, info.cell_position(home).x, home)
		worm.face = home
		worm.heading = 1.0
		worm._set_out(true)
		worm._open_burrow(worm.mouth(), Vector2.UP, 10.0)
		await _shoot(floor_at, "garden_worm_rise", func() -> void:
			worm.state = Wormlet.State.RISE
			worm.out = 0.55
			worm.mouth_x = worm.mouth().x
			body.global_position = lying)
		await _shoot(floor_at, "garden_worm_out", func() -> void:
			worm.state = Wormlet.State.OUT
			worm.out = 1.0
			worm.timer = 10.0
			body.global_position = lying)
		worm.burrows.clear()
		worm._open_burrow(lying + Vector2(Wormlet.LENGTH * 0.5 + Wormlet.GIRTH * 0.5, Wormlet.GIRTH * 0.5), Vector2.UP, 10.0)
		await _shoot(floor_at, "garden_worm_sink", func() -> void:
			worm.state = Wormlet.State.SINK
			worm.out = 0.5
			worm.mouth_x = lying.x + Wormlet.LENGTH * 0.5 + Wormlet.GIRTH * 0.5
			body.global_position = lying)
		return
	check(false, "a garden level with a small worm")


## A close-up and a still at the game's own zoom, centred on `at`; `pose` is called each frame.
func _shoot(at: Vector2, file: String, pose: Callable) -> void:
	for zoom: float in [CLOSE, 1.0]:
		camera.zoom = base * zoom
		for i: int in range(20):
			if pose.is_valid():
				pose.call()
			camera.global_position = at
			camera.reset_smoothing()
			await process_frame
		var whole: Image = root.get_texture().get_image()
		var size: Vector2i = CROP if zoom > 1.0 else CROP_GAME
		save_still("%s%s.png" % [file, "" if zoom > 1.0 else "_game"], whole.get_region(Rect2i((whole.get_size() - size) / 2, size)))
	camera.zoom = base
