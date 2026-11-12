extends TestKit
## The wisp's lurch (Mover.LURCH_SIGHT, WispArt): with the wizard close in front of it on its floor,
## a wisp stops and winds up, holding still while it draws back and gathers itself, then lurches at
## them, a good way but no further than the lurch carries, and rests after; it does not lurch again
## at once, nor at a wizard behind it, and a stun breaks a wind-up off, the wisp easing back out of it.
## godot --headless --path . --script res://tests/wisp_lurch_test.gd

## How far in front of the wisp the wizard stands (px), within Mover.LURCH_SIGHT.x; and how far
## below the wizard's middle the wisp's is, standing on the same floor.
const AHEAD: float = 170.0
const FLOOR_RISE: float = 15.0
## How far a whole lurch carries it (px): LURCH_SPEED slowing to nothing over LURCH_TIME.
const REACH: float = Mover.LURCH_SPEED * Mover.LURCH_TIME * 0.5


func run() -> void:
	# It reads what the art does (TestKit.art).
	art(true)
	# A start level with a stretch of open floor for the wisp (run_of_floor).
	await boot(start_seed(func(w: LevelGen) -> bool: return run_of_floor(w) != Vector2i(-1, -1)))
	freeze()
	player.get_node("CameraControl").set_process(false)
	player.global_position = Vector2(-9000, -9000)
	# The test's wisp has the level to itself: no other wisp stops its lurch.
	for other: Node in placed("mover_enemy.tscn").slice(1):
		other.queue_free()
	await process_frame
	var spot: Vector2i = run_of_floor()
	check(spot != Vector2i(-1, -1), "a stretch of open floor for a wisp to lurch along")
	if spot == Vector2i(-1, -1):
		finish()
		return
	var w: Node2D = placed("mover_enemy.tscn")[0] as Node2D
	var mover: Mover = w.get_node("Mover") as Mover
	var art: WispArt = null
	for c: Node in w.get_children():
		if c is WispArt:
			art = c as WispArt
	await stand(w, spot)
	var pace: float = Difficulty.attack()

	print("winding up")
	player.global_position = w.global_position + Vector2(AHEAD, -FLOOR_RISE)
	check(await within(func() -> bool: return mover.winding >= 0.0, 0.2), "seeing the wizard close in front, it winds up")
	var x0: float = w.global_position.x
	await within(func() -> bool: return mover.winding >= 0.9 or mover.winding < 0.0, Mover.WIND_UP / pace + 0.2)
	check(absf(w.global_position.x - x0) < 0.5, "it holds still while it winds up")
	if art != null:
		check(art._wind > 0.8 and art._heat > 0.8, "it gathers itself and its glow flares (wound up %.2f, heat %.2f)" % [art._wind, art._heat])

	print("lurching")
	check(await within(func() -> bool: return mover.lurching >= 0.0, 0.3), "then it lurches")
	await within(func() -> bool: return mover.lurching < 0.0, Mover.LURCH_TIME + 0.2)
	var went: float = w.global_position.x - x0
	check(went > REACH * 0.6 and went <= REACH + 2.0, "at the wizard, %.0f px (a whole lurch is %.0f)" % [went, REACH])
	check(mover.resting > 0.0, "and gathers itself after")
	if art != null:
		check(art._wind < 0.05, "let go of its wind-up")
	var again: float = (Mover.LURCH_REST + Mover.LURCH_AGAIN) / pace
	check(not await within(func() -> bool: return mover.winding >= 0.0, again * 0.9), "it does not wind up again at once")

	print("not behind it")
	await stand(w, spot)
	player.global_position = w.global_position + Vector2(-AHEAD, -FLOOR_RISE)
	check(not await within(func() -> bool: return mover.winding >= 0.0, 0.5), "a wizard behind it is not lurched at")

	print("a stun breaks it off")
	await stand(w, spot)
	player.global_position = w.global_position + Vector2(AHEAD, -FLOOR_RISE)
	await within(func() -> bool: return mover.winding >= 0.6, Mover.WIND_UP / pace + 0.3)
	check(mover.winding >= 0.6, "winding up again")
	Stunner.of(w).stun(1.0)
	await frames(3)
	check(mover.winding < 0.0 and mover.lurching < 0.0, "stunned, it breaks off the wind-up")
	if art != null:
		check(art._wind > 0.05 and await within(func() -> bool: return art._wind < 0.05, 1.0), "and it eases back out of it, not all at once")
	finish()


## A floor cell with three more open cells of floor to its right: room to lurch along.
func run_of_floor(level: LevelGen = null) -> Vector2i:
	var world: LevelGen = level if level != null else info.world
	var walkable: Callable = func(c: Vector2i) -> bool:
		return world.is_valid(c) and world.ground_below(c) and world.get_cell(c).type not in [LevelGen.Type.GROUND, LevelGen.Type.CRACKED, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.SPIKES, LevelGen.Type.PLATFORM, LevelGen.Type.LASER]
	for v: Vector2i in world.free_floors():
		if walkable.call(v) and walkable.call(v + Vector2i.RIGHT) and walkable.call(v + Vector2i.RIGHT * 2) and walkable.call(v + Vector2i.RIGHT * 3):
			return v
	return Vector2i(-1, -1)


## Put the wisp on `cell`, facing right and fresh (no lurch under way or waited out), the wizard out
## of the way and the camera on it, and wait for it to settle on the floor.
func stand(w: Node2D, cell: Vector2i) -> void:
	var mover: Mover = w.get_node("Mover") as Mover
	player.global_position = Vector2(-9000, -9000)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	# A wisp asleep in a far chunk is woken where it is first: one moved asleep stays filed under
	# the chunk it slept in (LevelLoader.sleep_far_chunks), and would not wake at the new place.
	camera.global_position = w.global_position
	camera.reset_smoothing()
	await until(func() -> bool: return w.can_process(), 3000)
	await until(func() -> bool: return not Stunner.of(w).stunned())
	mover.set_physics_process(false)
	w.global_position = info.cell_position(cell)
	camera.global_position = w.global_position
	camera.reset_smoothing()
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
	mover.set_physics_process(true)
	await until(func() -> bool: return mover.grounded)
	await frames(2)
