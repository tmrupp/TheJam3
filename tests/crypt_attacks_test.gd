extends TestKit
## The cemetery's foes' attacks, each with its tell (Skeleton.SWIPE_SIGHT, Wraith.DART_RANGE): a
## skeleton close to the wizard stops and winds up, holding still, its near arm raised, then swipes,
## stepping on and reaching out with its touch, which strikes them; it rests after and does not swipe
## again at once, and a stun knocks it to pieces mid wind-up. A hunting wraith near the wizard swells,
## drawing back from them, then darts at them, a good way at once; light breaks a swell off.
## godot --headless --path . --script res://tests/crypt_attacks_test.gd

## How far in front of the skeleton the wizard stands (px), within Skeleton.SWIPE_SIGHT.x and
## within the swipe's reach; and how far below the wizard's middle the skeleton's is, on one floor.
const SWIPE_AHEAD: float = 92.0
const FLOOR_RISE: float = 15.0
## How far from the wraith the wizard's middle is (px), the wraith within Wraith.DART_RANGE of the
## point it makes for (Wraith hunts a point 50 px over the wizard's middle).
const DART_AHEAD: Vector2 = Vector2(220.0, 50.0)


func run() -> void:
	if not needs([&"cemetery"]):
		finish()
		return
	await boot()
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	var at: Variant = _run(3)
	check(at != null, "a stretch of open floor, away from the lanterns")
	if at == null:
		finish()
		return
	await skeleton(at as Vector2i)
	await wraith(at as Vector2i)
	RunState.delete_save()
	finish()


func skeleton(at: Vector2i) -> void:
	print("a skeleton's swipe")
	player.global_position = Vector2(-9000, -9000)
	var node: Node2D = (load("res://prefabs/skeleton_enemy.tscn") as PackedScene).instantiate() as Node2D
	var bones: Skeleton = node.get_node("Skeleton") as Skeleton
	bones.asleep = false
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(at)
	look(node.global_position)
	await until(func() -> bool: return info.loader.is_awake(node))
	await within(func() -> bool: return bones.grounded, 1.0)
	var art: SkeletonArt = null
	for c: Node in node.get_children():
		if c is SkeletonArt:
			art = c as SkeletonArt
	var pace: float = Difficulty.attack()
	player.end_invulnerable()
	var health: int = player.health.health
	player.global_position = node.global_position + Vector2(SWIPE_AHEAD, -FLOOR_RISE)
	check(await within(func() -> bool: return bones.winding >= 0.0, 0.3), "the wizard close in front, it winds up")
	var x0: float = node.global_position.x
	await within(func() -> bool: return bones.winding >= 0.9 or bones.winding < 0.0, Skeleton.WIND_UP / pace + 0.2)
	check(absf(node.global_position.x - x0) < 0.5, "it holds still while it winds up")
	if art != null:
		check(art.hands[1].y < -SkeletonArt.SHOULDER, "its near arm raised over its shoulder (hand at %.1f)" % art.hands[1].y)
	check(await within(func() -> bool: return bones.swiping >= 0.0, 0.3), "then it swipes")
	var box: Node2D = node.get_node("HitBox") as Node2D
	check(absf(box.position.x) == Skeleton.SWIPE_REACH, "its touch reaching out with its arm")
	await within(func() -> bool: return bones.swiping < 0.0, Skeleton.SWIPE_TIME + 0.2)
	var went: float = (node.global_position.x - x0) * bones.facing
	check(went > Skeleton.SWIPE_LUNGE * 0.5 and went <= Skeleton.SWIPE_LUNGE + 1.0, "stepping into the blow, %.0f px" % went)
	check(player.health.health < health, "the swipe strikes the wizard (%d to %d)" % [health, player.health.health])
	check(box.position.x == 0.0 and bones.resting > 0.0, "then its touch draws back in and it stands a moment")
	var again: float = (Skeleton.SWIPE_REST + Skeleton.SWIPE_AGAIN) / pace
	check(not await within(func() -> bool: return bones.winding >= 0.0, again * 0.9), "it does not swipe again at once")
	check(await within(func() -> bool: return bones.winding >= 0.0, again), "but does in a while")
	Stunner.of(node).stun(0.2)
	await physics_frame
	await physics_frame
	check(bones.winding < 0.0 and bones.swiping < 0.0 and bones.apart() > 0.0 and box.position.x == 0.0, "a stun mid wind-up knocks it to pieces, the swipe lost")
	node.queue_free()
	await until(gone(node))


func wraith(at: Vector2i) -> void:
	print("a wraith's dart")
	player.global_position = Vector2(-9000, -9000)
	var node: Node2D = (load("res://prefabs/wraith_enemy.tscn") as PackedScene).instantiate() as Node2D
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(at) + Vector2(0, -60)
	var ghost: Wraith = node.get_node("Wraith") as Wraith
	look(node.global_position)
	await until(func() -> bool: return info.loader.is_awake(node))
	var pace: float = Difficulty.attack()
	player.end_invulnerable()
	player.global_position = node.global_position + DART_AHEAD
	info.snuff(player.global_position)
	var aim: Callable = func() -> float: return node.global_position.distance_to(player.global_position + Vector2(0, -50))
	check(await within(func() -> bool: return ghost.swelling >= 0.0, 0.5), "hunting a snuffed wizard near it, it swells")
	var from: float = aim.call()
	await within(func() -> bool: return ghost.swelling >= 0.6 or ghost.swelling < 0.0, Wraith.SWELL / pace + 0.2)
	check(float(aim.call()) > from, "drawing back from them as it swells (%.0f px to %.0f)" % [from, float(aim.call())])
	var before: float = aim.call()
	check(await within(func() -> bool: return ghost.darting >= 0.0, Wraith.SWELL / pace), "then it darts")
	var nearest: float = before
	for i: int in range(ceili(Wraith.DART_TIME * float(Engine.physics_ticks_per_second))):
		nearest = minf(nearest, aim.call())
		await physics_frame
	check(before - nearest > 100.0 or ghost.recoil > 0.0, "at them, a good way at once (%.0f px nearer)" % (before - nearest))

	print("light breaks a swell off")
	ghost.recoil = 0.0
	ghost.resting = 0.0
	ghost.darting = -1.0
	ghost.dart_wait = 0.0
	node.global_position = player.global_position - DART_AHEAD
	check(await within(func() -> bool: return ghost.swelling >= 0.0, 0.5), "swelling again")
	info.relight()
	check(await within(func() -> bool: return ghost.shy and ghost.swelling < 0.0 and ghost.darting < 0.0, 0.3), "in the flame's light it freezes, the dart lost")
	node.queue_free()
	await until(gone(node))


func look(at: Vector2) -> void:
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.global_position = at
	camera.reset_smoothing()


## A floor cell with `n` more open floor cells to its right in a row (open over them too), more than
## a lantern's light from every lantern, or null.
func _run(n: int) -> Variant:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var ok: bool = true
		for k: int in range(n + 1):
			var c: Vector2i = v + Vector2i(k, 0)
			if not w.is_valid(c) or w.is_ground(c) or not w.ground_below(c) or w.is_ground(c + Vector2i.UP):
				ok = false
				break
		if ok and _far_from_lanterns(info.cell_position(v)):
			return v
	return null


func _far_from_lanterns(p: Vector2) -> bool:
	for lantern: Node in placed("checkpoint.tscn"):
		if (lantern as Node2D).global_position.distance_to(p) < RisoLight.RESPAWN_REACH + 100.0:
			return false
	return true
