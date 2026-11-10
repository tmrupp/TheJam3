extends TestKit
## suite: full
## Every attack waits before it lands (docs/REVIEW_PLAN.md §8; Difficulty.tell): for each of the
## garden's foes (the wisp's lurch, the hopper's leap, the watcher's shot, a seed pod's seed, a small
## worm coming out of the rock), from the first physics step its wind-up shows to the step its
## attack goes is at least Difficulty.TELL_MIN of the game's own seconds, on the presets that run
## tells faster than Normal (Hard and Brutal; Normal's are their own lengths, over the floor: the
## watcher's, seconds long on every preset, only on the fastest); and so for the garden's bosses (the
## worm's strike, a bramble vine's lash, a bulb's seed), stepped through their own clocks on every
## preset. A guard raised in the last beat of a wisp's wind-up, the wizard close by, catches
## its lurch. (A hopper's blow, a watcher's shot and a seed land after a flight, so their last beat
## marks the leap or the shot, not the blow: docs/REVIEW_PLAN.md §8.)
## godot --headless --path . --script res://tests/tells_test.gd

## The most game seconds a tell is waited for.
const WAIT: float = 10.0


## The garden level the foes are tried in (place).
var at: Vector2i = Vector2i(-1, -1)


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
	await boot(28)
	at = place()
	check(at.x >= 0, "a garden level with a seed pod and a small worm (%s)" % at)
	await go(at)
	player.get_node("CameraControl").set_process(false)
	for scene: String in ["mover_enemy.tscn", "hopper_enemy.tscn", "shooter_enemy.tscn"]:
		for n: Node in placed(scene):
			n.queue_free()
	await frames(2)
	var was: Difficulty.Preset = Difficulty.preset
	for p: int in range(Difficulty.NAMES.size()):
		Difficulty.preset = p as Difficulty.Preset
		print("%s:" % Difficulty.NAMES[p])
		Health.invincible = true
		_bosses()
		if p == Difficulty.Preset.NORMAL:
			continue
		await _wisp()
		await _hopper()
		if p == Difficulty.NAMES.size() - 1:
			await _watcher()
		await _pod()
		await _wormlet()
	Difficulty.preset = was
	print("the guard in the last beat")
	Health.invincible = false
	await _guard_wisp()
	finish()


## Whether `steps` physics steps are at least Difficulty.TELL_MIN of game seconds (a step's rounding
## allowed).
func long_enough(steps: int) -> bool:
	return float(steps) / float(Engine.physics_ticks_per_second) >= Difficulty.TELL_MIN - 0.5 / float(Engine.physics_ticks_per_second)


## Physics steps from the first in which `begun` holds to the first in which `struck` does, with
## `body`'s physics running (-1 if either is not met within WAIT game seconds).
func tell_steps(begun: Callable, struck: Callable) -> int:
	if not await within(begun, WAIT):
		return -1
	var steps: int = 0
	while not bool(struck.call()):
		await physics_frame
		steps += 1
		if steps > roundi(WAIT * Engine.physics_ticks_per_second):
			return -1
	return steps


func report(name: String, steps: int) -> void:
	check(steps >= 0 and long_enough(steps), "  %s: %d steps (%.2f s) from its tell to its attack, at least %.2f" % [name, steps, float(steps) / float(Engine.physics_ticks_per_second), Difficulty.TELL_MIN])


## A foe of `scene` made and put on the floor at `spot`.
func _make(scene: String, spot: Vector2i) -> Node2D:
	var node: Node2D = (load("res://prefabs/" + scene) as PackedScene).instantiate() as Node2D
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(spot)
	look(node.global_position)
	return node


func _wisp() -> void:
	var node: Node2D = _make("mover_enemy.tscn", floor_run(3))
	var mover: Mover = node.get_node("Mover") as Mover
	await until(func() -> bool: return info.loader.is_awake(node))
	await within(func() -> bool: return mover.grounded, 1.0)
	if mover.direction != 1:
		mover.turn()
	mover.turn_left = 0.0
	mover.lurch_wait = 0.0
	player.set_physics_process(false)
	player.global_position = node.global_position + Vector2(170, -15)
	look(player.global_position)
	var steps: int = await tell_steps(func() -> bool: return mover.winding >= 0.0, func() -> bool: return mover.lurching >= 0.0)
	if steps < 0:
		print("  the wisp at %s facing %d, grounded %s, waiting %.2f, the wizard at %s" % [node.global_position, mover.direction, mover.grounded, mover.lurch_wait, player.global_position])
	report("the wisp's lurch", steps)
	node.queue_free()
	await until(gone(node))


func _hopper() -> void:
	var node: Node2D = _make("hopper_enemy.tscn", floor_run(3))
	var hop: Hopper = node.get_node("Hopper") as Hopper
	await until(func() -> bool: return info.loader.is_awake(node))
	await within(func() -> bool: return hop.grounded, 1.0)
	hop.rest = 0.0
	player.set_physics_process(false)
	player.global_position = node.global_position + Vector2(220, -15)
	look(player.global_position)
	var steps: int = await tell_steps(func() -> bool: return hop.crouch >= 0.0, func() -> bool: return not hop.grounded)
	if steps < 0:
		print("  the hopper at %s, grounded %s, resting %.2f, crouch %.2f, the wizard at %s" % [node.global_position, hop.grounded, hop.rest, hop.crouch, player.global_position])
	report("the hopper's leap", steps)
	node.queue_free()
	await until(gone(node))


func _watcher() -> void:
	var node: Node2D = _make("shooter_enemy.tscn", floor_run(3))
	var eye: Shooter = node.get_node("Shooter") as Shooter
	await until(func() -> bool: return info.loader.is_awake(node))
	player.set_physics_process(false)
	player.global_position = node.global_position + Vector2(300, -40)
	look(player.global_position)
	# Its tell is its whole charge, the eye opening from shut: a shot goes as the charge starts again.
	var last: Array[float] = [0.0]
	var fired: Callable = func() -> bool:
		var now: float = eye.charge
		var went: bool = now < last[0]
		last[0] = now
		return went
	report("the watcher's shot", await tell_steps(func() -> bool: return eye.sees and eye.charge > 0.0, fired))
	node.queue_free()
	await until(gone(node))


## A pod facing across open air, the wizard out in front.
func _pod() -> void:
	var chosen: SeedPod = null
	for n: Node in placed("seed_pod.tscn"):
		var pod: SeedPod = n.get_node("SeedPod") as SeedPod
		var cell: Vector2i = n.get_meta(&"cell")
		var step: Vector2i = Vector2i(roundi(pod.way.x), roundi(pod.way.y))
		if chosen == null and step.y == 0 and range(1, 4).all(func(k: int) -> bool: return not info.world.is_ground(cell + step * k)):
			chosen = pod
		else:
			pod.set_physics_process(false)
	check(chosen != null, "a pod facing across open air at %s" % at)
	if chosen == null:
		return
	chosen.set_physics_process(true)
	player.set_physics_process(false)
	player.global_position = chosen.mouth() + chosen.way * 260.0
	look(player.global_position)
	var spat: int = chosen.spat
	report("a pod's seed", await tell_steps(func() -> bool: return chosen.telling >= 0.0, func() -> bool: return chosen.spat > spat))


## A small worm, the wizard on a floor near its home.
func _wormlet() -> void:
	var worms: Array[Node] = placed("wormlet.tscn")
	check(not worms.is_empty(), "a small worm at %s" % at)
	if worms.is_empty():
		return
	var worm: Wormlet = worms[0].get_node("Wormlet") as Wormlet
	var stand: Vector2i = Vector2i(-1, -1)
	# Any floor near its home, whatever stands on it (the garden is dressed thickly).
	for y: int in range(worm.home.y - 3, worm.home.y + 4):
		for x: int in range(worm.home.x - 3, worm.home.x + 4):
			var v: Vector2i = Vector2i(x, y)
			if stand.x < 0 and info.world.is_valid(v) and not info.world.is_ground(v) and info.world.ground_below(v):
				stand = v
	player.set_physics_process(false)
	player.global_position = info.cell_position(stand)
	look(player.global_position)
	report("a small worm coming out", await tell_steps(func() -> bool: return worm.state == Wormlet.State.WARN, func() -> bool: return worm.state != Wormlet.State.WARN))


## The bosses' tells, stepped through their own clocks: the worm's strike to its lunge, a vine's
## warning to its lash, a bulb's tell to its seed.
func _bosses() -> void:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var since: float = 0.0
	var steps: int = 0
	while since < Worm.STRIKE_WIND:
		since += Worm._strike_step(since, dt * Difficulty.haste())
		steps += 1
	report("the worm's strike", steps)
	var vine: BrambleVine = BrambleVine.new(null, Vector2i.ZERO, Vector2.RIGHT)
	vine.t = BrambleVine.REST
	steps = 0
	while vine.phase()[0] == &"warn" and steps < 1000:
		vine._physics_process(dt)
		steps += 1
	report("a bramble vine's lash", steps)
	vine.free()
	var telling: float = 0.0
	steps = 0
	while telling < 1.0:
		telling += dt / Difficulty.boss_tell(SeedPod.POD_TELL)
		steps += 1
	report("a bramble bulb's seed", steps)
	check(BrambleBulb.SEED_EVERY / (1.0 + BrambleBulb.SEED_FURY * 5.0) > SeedPod.POD_TELL, "  a bulb's swell at the bramble's greatest fury still leaves its tell its time")


## The wisp lurching at the wizard close by: a guard raised half way through its last beat catches it.
func _guard_wisp() -> void:
	var node: Node2D = _make("mover_enemy.tscn", floor_run(3))
	var mover: Mover = node.get_node("Mover") as Mover
	await until(func() -> bool: return info.loader.is_awake(node))
	await within(func() -> bool: return mover.grounded, 1.0)
	if mover.direction != 1:
		mover.turn()
	mover.turn_left = 0.0
	mover.lurch_wait = 0.0
	(node.get_node("Wound") as Wound).hp = 99
	await _guard("a wisp", node.global_position + Vector2(100, -10),
			func() -> bool: return Difficulty.last_beat(mover.winding, Difficulty.tell(Mover.WIND_UP)) and (1.0 - mover.winding) * Difficulty.tell(Mover.WIND_UP) <= Difficulty.LAST_BEAT * 0.5)
	node.queue_free()
	await until(gone(node))


## The wizard set down at `at`, the spell ready; when `now` holds (half way through the foe's last
## beat), the guard goes up: whether it catches the blow, the wizard unhurt.
func _guard(name: String, at: Vector2, now: Callable) -> void:
	player.set_physics_process(false)
	player.global_position = at
	look(player.global_position)
	still()
	player.set_physics_process(true)
	player.end_invulnerable()
	player.health.health = player.health.max_health
	var guard: Parry = player.get_node("Parry") as Parry
	guard.stop_parry()
	Abilities.refill(player)
	var before: float = guard.parried_at
	var raised: bool = await within(now, WAIT)
	check(raised, "%s's last beat came" % name)
	player.parry.emit()
	await within(func() -> bool: return guard.parried_at > before, 1.0)
	check(guard.parried_at > before and player.health.health == player.health.max_health, "%s's blow is caught by a guard raised in its last beat" % name)


## Hold the camera on `where`, unclamped by the level's edges: chunks of a level sleep by their
## distance from it (LevelLoader), and the camera does not follow the wizard here.
func look(where: Vector2) -> void:
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	camera.global_position = where
	camera.reset_smoothing()
	info.loader.wake_around(where)


## A floor cell with `n` more open floor cells to its right in a row (open over them too, whatever
## stands on them but a hazard or a door), nothing solid along it in the scene; (-1, -1) if there is
## none.
func floor_run(n: int) -> Vector2i:
	var w: LevelGen = info.world
	for y: int in range(w.size.y):
		for x: int in range(w.size.x):
			var v: Vector2i = Vector2i(x, y)
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
