extends TestKit
## Stills of the garden's foes' tells (docs/REVIEW_PLAN.md §8.4, step 2; RisoProp.tell_mark): the
## wisp, the watcher, the hopper, the seed pod and the small worm, each let run its own tell with the
## wizard in its sight and held still at the start, the middle and the last beat of it (MOMENTS),
## printed with the flame lit and snuffed. One sheet a foe, tells/<foe>.png: the three moments
## across, lit above and snuffed below, each cropped round the foe at a close zoom. On the default
## preset (Hard). The audit of the garden's tells, and where their last beat is looked at.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_tells.gd

## How far through its tell each still is held: just begun, half way, and in its last beat.
const MOMENTS: Array[float] = [0.08, 0.5, 0.97]
## Each still's size (px) and the zoom it is taken at, against the game's own.
const SHOT: Vector2i = Vector2i(400, 320)
const ZOOM: float = 2.4
## The most game seconds a tell is waited for.
const WAIT: float = 10.0

var camera: Camera2D
var base_zoom: Vector2
var at: Vector2 = Vector2.ZERO


## The garden level the foes are found in (place).
var place_at: Vector2i = Vector2i(-1, -1)


## A garden level, short of a gate, holding a seed pod and a small worm: looked for over a few
## worlds and rows, as one level may hold neither.
func place() -> Vector2i:
	for x: int in range(28, 40):
		for row: int in range(1, Bands.garden_rows()):
			var where: Vector2i = Vector2i(x, row)
			if Bosses.gate_at(row) != &"":
				continue
			var w: LevelGen = build(where)
			if w != null and count_of(w, LevelGen.Type.POD) > 0 and count_of(w, LevelGen.Type.WORMLET) > 0:
				return where
	return Vector2i(-1, -1)


func run() -> void:
	window()
	await boot(28)
	Health.invincible = true
	camera = main.get_node("Camera2D") as Camera2D
	base_zoom = camera.zoom
	place_at = place()
	check(place_at.x >= 0, "a garden level with a seed pod and a small worm (%s)" % place_at)
	await go(place_at)
	player.get_node("CameraControl").set_process(false)
	player.set_physics_process(false)
	camera.zoom = base_zoom * ZOOM
	for scene: String in ["mover_enemy.tscn", "hopper_enemy.tscn", "shooter_enemy.tscn"]:
		for n: Node in placed(scene):
			n.queue_free()
	await frames(2)
	await _wisp()
	await _hopper()
	await _watcher()
	await _pod()
	await _wormlet()
	finish()


## A foe of `scene` made and put on the floor at `spot`.
func _make(scene: String, spot: Vector2i) -> Node2D:
	check(spot.x >= 0, "a run of floor for the %s" % scene.get_basename())
	var node: Node2D = (load("res://prefabs/" + scene) as PackedScene).instantiate() as Node2D
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(spot)
	return node


func _wisp() -> void:
	var spot: Vector2i = floor_run(3)
	var node: Node2D = _make("mover_enemy.tscn", spot)
	var mover: Mover = node.get_node("Mover") as Mover
	await until(func() -> bool: return info.loader.is_awake(node))
	await within(func() -> bool: return mover.grounded, 1.0)
	if mover.direction != 1:
		mover.turn()
	mover.turn_left = 0.0
	mover.lurch_wait = 0.0
	player.global_position = node.global_position + Vector2(170, -15)
	await _sheet("wisp", mover, func() -> float: return mover.winding, node.global_position + Vector2(40, -40))
	node.queue_free()


func _hopper() -> void:
	var spot: Vector2i = floor_run(3)
	var node: Node2D = _make("hopper_enemy.tscn", spot)
	var hop: Hopper = node.get_node("Hopper") as Hopper
	await until(func() -> bool: return info.loader.is_awake(node))
	await within(func() -> bool: return hop.grounded, 1.0)
	hop.rest = 0.0
	player.global_position = node.global_position + Vector2(220, -15)
	await _sheet("hopper", hop, func() -> float: return hop.crouch, node.global_position + Vector2(0, -20))
	node.queue_free()


func _watcher() -> void:
	var spot: Vector2i = floor_run(3)
	var node: Node2D = _make("shooter_enemy.tscn", spot)
	var eye: Shooter = node.get_node("Shooter") as Shooter
	await until(func() -> bool: return info.loader.is_awake(node))
	player.global_position = node.global_position + Vector2(300, -40)
	await _sheet("watcher", eye, func() -> float: return eye.charge if eye.sees else -1.0, node.global_position + Vector2(0, 30))
	node.queue_free()


## A pod facing across open air (three cells clear in front of it), the wizard out in front.
func _pod() -> void:
	var pods: Array[Node] = placed("seed_pod.tscn")
	var chosen: Node2D = null
	for n: Node in pods:
		var pod: SeedPod = n.get_node("SeedPod") as SeedPod
		var cell: Vector2i = n.get_meta(&"cell")
		var step: Vector2i = Vector2i(roundi(pod.way.x), roundi(pod.way.y))
		if chosen == null and step.y == 0 and range(1, 4).all(func(k: int) -> bool: return not info.world.is_ground(cell + step * k)):
			chosen = n as Node2D
	check(chosen != null, "a pod facing across open air at %s" % place_at)
	if chosen == null:
		return
	for n: Node in pods:
		if n != chosen:
			n.queue_free()
	var pod: SeedPod = chosen.get_node("SeedPod") as SeedPod
	player.global_position = pod.mouth() + pod.way * 260.0
	await _sheet("pod", pod, func() -> float: return pod.telling, chosen.global_position)


## A small worm, the wizard on a floor near its home.
func _wormlet() -> void:
	for n: Node in placed("seed_pod.tscn"):
		n.queue_free()
	var worms: Array[Node] = placed("wormlet.tscn")
	check(not worms.is_empty(), "a small worm at %s" % place_at)
	if worms.is_empty():
		return
	var node: Node2D = worms[0] as Node2D
	for n: Node in worms.slice(1):
		n.queue_free()
	var worm: Wormlet = node.get_node("Wormlet") as Wormlet
	var stand: Vector2i = Vector2i(-1, -1)
	# Any floor near its home, whatever stands on it (the garden is dressed thickly).
	for y: int in range(worm.home.y - 3, worm.home.y + 4):
		for x: int in range(worm.home.x - 3, worm.home.x + 4):
			var v: Vector2i = Vector2i(x, y)
			if stand.x < 0 and info.world.is_valid(v) and not info.world.is_ground(v) and info.world.ground_below(v):
				stand = v
	check(stand.x >= 0, "a floor near its home")
	player.global_position = info.cell_position(stand)
	var u: Callable = func() -> float: return worm.warn_near() if worm.state == Wormlet.State.WARN else -1.0
	await _sheet("wormlet", worm, u, info.cell_position(stand))


## The sheet for `name`: let `body` (the node whose physics runs the tell) go until `u` reaches each
## of MOMENTS, hold it there, and print it round `where` lit and snuffed.
func _sheet(name: String, body: Node, u: Callable, where: Vector2) -> void:
	var sheet: Image = Image.create(SHOT.x * MOMENTS.size(), SHOT.y * 2, false, Image.FORMAT_RGBA8)
	look(where)
	for i: int in range(MOMENTS.size()):
		body.set_physics_process(true)
		var reached: bool = await within(func() -> bool: return float(u.call()) >= MOMENTS[i], WAIT)
		body.set_physics_process(false)
		check(reached, "%s: its tell reached %.2f" % [name, MOMENTS[i]])
		if not reached:
			return
		print("  %s at %.2f of its tell" % [name, float(u.call())])
		await frames(60)
		sheet.blit_rect(await _still(), Rect2i(Vector2i.ZERO, SHOT), Vector2i(SHOT.x * i, 0))
		info.snuff(player.global_position)
		await frames(60)
		sheet.blit_rect(await _still(), Rect2i(Vector2i.ZERO, SHOT), Vector2i(SHOT.x * i, SHOT.y))
		info.relight()
		await frames(30)
	body.set_physics_process(true)
	save_still("tells/%s.png" % name, sheet)


## The view now, cropped to SHOT round its middle.
func _still() -> Image:
	look(at)
	await process_frame
	var whole: Image = root.get_texture().get_image()
	whole.convert(Image.FORMAT_RGBA8)
	return whole.get_region(Rect2i((whole.get_size() - SHOT) / 2, SHOT))


## Keep the camera on `where`, unclamped by the level's edges.
func look(where: Vector2) -> void:
	at = where
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	camera.global_position = where
	camera.reset_smoothing()


## A floor cell with `n` more open floor cells to its right in a row (open over them too, whatever
## stands on them but a hazard or a door), nothing solid along it in the scene; (-1, -1) if there is
## none.
func floor_run(n: int) -> Vector2i:
	var w: LevelGen = info.world
	var floors: Array[Vector2i] = []
	for y: int in range(w.size.y):
		for x: int in range(w.size.x):
			var c: Vector2i = Vector2i(x, y)
			if not w.is_ground(c) and w.ground_below(c):
				floors.append(c)
	for v: Vector2i in floors:
		var ok: bool = true
		for k: int in range(n + 1):
			var c: Vector2i = v + Vector2i(k, 0)
			if not w.is_valid(c) or w.is_ground(c) or not w.ground_below(c) or w.is_ground(c + Vector2i.UP) \
					or w.get_cell(c).type in [LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.SPIKES, LevelGen.Type.PLATFORM, LevelGen.Type.LASER]:
				ok = false
				break
		if ok and _clear(v, v + Vector2i(n, 0)):
			return v
	return Vector2i(-1, -1)


## Whether nothing solid (rock, or anything on its layer: a gate, a solid prop) stands between the
## middles of cells `a` and `b` in the scene.
func _clear(a: Vector2i, b: Vector2i) -> bool:
	var q: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(info.cell_position(a), info.cell_position(b), 4)
	return main.get_world_2d().direct_space_state.intersect_ray(q).is_empty()
