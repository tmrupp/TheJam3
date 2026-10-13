extends TestKit
## The necromancer (Necromancer, docs/REGIONS_PLAN.md §6): in the first crypt of the cemetery's gate
## level, its graves the crypt's floors; it wakes as the wizard comes near; in the dark a strike
## passes through it, in light a strike puts out a candle and it blinks away to another grave; it
## raises skeletons, awake, that a stun crumbles and that drop no stars; with its last candle out it
## crumbles, is slain for the run, and leaves its relic.
## godot --headless --path . --script res://tests/necromancer_test.gd


func run() -> void:
	MapInfo.debug = false
	var gate: Vector2i = Vector2i(28, Bosses.row_of(&"necromancer"))
	print("in its gate level")
	var w: LevelGen = build(gate)
	var held: Array[Vector2i] = w.objects_of(LevelGen.Type.BOSS)
	check(held.size() == 1 and not w.crypts.is_empty() and (w.crypts[0]["floors"] as Array).has(held[0]), "it waits in the level's first crypt")

	await boot(28)
	player.set_physics_process(false)
	info.coord = gate
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	var found: Array[Node] = placed("necromancer.tscn")
	check(found.size() == 1, "in play it is there")
	if found.is_empty():
		finish()
		return
	var necro: Necromancer = found[0] as Necromancer
	check(necro.graves.size() >= 6 and not necro.awake, "%d graves, and it waits" % necro.graves.size())

	print("it wakes")
	var beside: Vector2i = _beside(necro)
	player.global_position = info.cell_position(beside)
	check(await within(func() -> bool: return necro.awake, 0.5), "the wizard comes in: it wakes")

	print("dark and light")
	info.snuff(player.global_position)
	await physics_frame
	var wound: Wound = necro.get_node("Wound") as Wound
	check(not necro.lit(), "snuffed, it stands in the dark")
	wound.hit(1, Vector2.RIGHT)
	check(wound.hp == Necromancer.CANDLES, "a strike passes through it")
	info.relight()
	await physics_frame
	await physics_frame
	check(necro.lit(), "with the flame lit beside it, light falls on it")
	var stood: Vector2 = necro.global_position
	wound.hit(1, Vector2.RIGHT)
	check(wound.hp == Necromancer.CANDLES - 1, "a strike puts out a candle")
	check(await within(func() -> bool: return necro.blinking < 0.0 and necro.global_position.distance_to(stood) > 10.0, Necromancer.BLINK_TIME + 0.5), "and it blinks away to another grave")

	print("it raises skeletons")
	player.global_position = info.cell_position(_beside(necro))
	check(await within(func() -> bool: return not necro.raised.is_empty(), Necromancer.RAISE_EVERY / Difficulty.haste() + 1.0), "a skeleton rises out of a grave")
	if not necro.raised.is_empty():
		var skeleton: Node2D = necro.raised[0]
		var bones: Skeleton = skeleton.get_node("Skeleton") as Skeleton
		check(not bones.asleep and skeleton.is_in_group(&"hex_target"), "awake, and an enemy")
		var stars: int = placed("coin.tscn").size()
		Stunner.of(skeleton).stun(1.0)
		check(await until(gone(skeleton)), "a stun crumbles it")
		await settle()
		check(placed("coin.tscn").size() == stars, "and it drops no stars")

	print("slain")
	while wound.hp > 1 and is_instance_valid(necro):
		player.global_position = info.cell_position(_beside(necro))
		await physics_frame
		await physics_frame
		necro.blinking = -1.0
		wound.hit(1, Vector2.RIGHT)
	player.global_position = info.cell_position(_beside(necro))
	await physics_frame
	await physics_frame
	wound.hit(1, Vector2.RIGHT)
	check(necro.dying(), "its last candle out, it crumbles")
	check(await until(gone(necro)), "and is gone")
	await settle()
	check(info.run.bosses.has(&"necromancer"), "slain for the run")
	check(placed("relic.tscn").any(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"necromancer"), "its relic left where it stood")
	RunState.delete_save()
	finish()


## A cell beside the necromancer's grave (a grave a cell or two away, else its own) for the wizard to
## stand at, with nothing between.
func _beside(necro: Necromancer) -> Vector2i:
	var at: Vector2i = info.cell_at(necro.global_position + Vector2(0, -8))
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(-2, 0)]:
		if necro.graves.has(at + d) and not info.world.is_ground(at + Vector2i(signi(d.x), 0)):
			return at + d
	return at
