extends TestKit
## The whale's belly (Belly, Acid, Wreck): laid out by hand, the same on every visit, its way back
## and lantern at its mouth, a pool of acid in its stomach, three pieces of wreckage in its pits and
## its heart in a chamber of its own; the acid's cycle (drained, warning, flooding, flooded,
## draining, over and over), starting drained; in it the wizard wades slowly, sinks slowly, strokes
## up at each jump and is burned now and then, cooling off out of it; and wreckage resting on the
## pit floor floats up on the flood, carrying a wizard stood on it clear of the acid, and settles
## again as it drains.
## godot --headless --path . --script res://tests/belly_test.gd


func run() -> void:
	var row: int = WhaleHunt.row()
	var at: Vector2i = Worlds.side_at(Worlds.kind_of(Belly), Vector2i(28, row))
	var w: LevelGen = build(at)
	var again: LevelGen = build(at)
	check(w.objects == again.objects, "the belly is laid out the same on every visit")
	check(count_of(w, LevelGen.Type.ACID) == 1 and count_of(w, LevelGen.Type.WRECK) == Belly.WRECKS.size(), "a pool of acid, and %d pieces of wreckage" % Belly.WRECKS.size())
	check(count_of(w, LevelGen.Type.BOSS) == 1 and w.exits.has(MapInfo.Exit.BACK) and w.exit_lanterns.has(MapInfo.Exit.BACK), "its heart, and its way back with a lantern")
	check(w.exits[MapInfo.Exit.BACK].x < 10 and w.objects_of(LevelGen.Type.BOSS)[0].x > 55, "the way back at its mouth, the heart far across")

	print("cycle")
	check(Acid.level_at(0.0) == 0.0 and Acid.level_at(Acid.HOLD_LOW + Acid.WARN - 0.01) == 0.0, "drained, then warning, still drained")
	check(Acid.level_at(Acid.HOLD_LOW + Acid.WARN + Acid.RISE * 0.5) > 0.2, "flooding")
	check(Acid.level_at(Acid.HOLD_LOW + Acid.WARN + Acid.RISE + 0.1) == 1.0, "flooded")
	check(Acid.level_at(Acid.period() - 0.01) < 0.05 and Acid.level_at(Acid.period() + 1.0) == 0.0, "drained again, and over again")

	await boot(28)
	player.health.max_health = 99
	player.health.health = 99
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var acids: Array[Node] = placed("acid.tscn")
	check(acids.size() == 1, "its acid is in the scene")
	if acids.is_empty():
		finish()
		return
	var acid: Acid = acids[0] as Acid
	check(acid.level() == 0.0 and acid.t < Acid.HOLD_LOW, "it starts drained, with time to cross")

	print("wading")
	var pit: Vector2i = _pit(w)
	var pit_floor: Vector2 = info.cell_position(pit) + Vector2(0.0, 30.0)
	await _put(pit_floor)
	check(Acid.wading(player) > Acid.BURN_DEPTH, "drained, its pits still hold acid")
	_press(&"Right")
	await physics_frame
	await physics_frame
	check(absf(player.velocity.x) <= Acid.WADE + 0.1, "the wizard wades slowly in it (%d px/s)" % roundi(absf(player.velocity.x)))
	Input.action_release(&"Right")
	player.global_position = pit_floor
	var hp: int = player.health.health
	var burnt: bool = await within(func() -> bool: return player.health.health < hp, Acid.BURN_FIRST + 0.5)
	check(burnt and player.health.health == hp - Acid.BURN, "it burns them a moment after they go in")
	hp = player.health.health
	var again_burnt: bool = await within(func() -> bool: return player.health.health < hp, Acid.BURN_EVERY + 0.5)
	check(again_burnt, "and again while they stay")
	hp = player.health.health
	await _put(info.cell_position(pit + Vector2i(-1, -1)))
	var dry: bool = not await within(func() -> bool: return player.health.health < hp, Acid.BURN_EVERY + 1.0)
	check(dry and Acid.wading(player) == 0.0, "out of it, on the floor beside the pit, no burns")

	print("swimming")
	acid.t = Acid.HOLD_LOW + Acid.WARN + Acid.RISE + 0.5
	player.end_invulnerable()
	player.global_position = info.cell_position(pit + Vector2i(0, -3))
	player.velocity = Vector2(0.0, 600.0)
	player.set_physics_process(true)
	await physics_frame
	await physics_frame
	check(player.velocity.y < 600.0 and Acid.depth_at(player.get_tree(), player.global_position) > 0.0, "flooded, a fall into it is checked")
	var sunk: bool = await within(func() -> bool: return player.velocity.y <= Acid.SINK + 0.1, 1.0)
	check(sunk, "and they sink slowly")
	_press(&"Jump")
	await physics_frame
	await physics_frame
	Input.action_release(&"Jump")
	check(player.velocity.y < -Acid.STROKE * 0.8, "a jump in it is a stroke up")

	print("wreckage")
	acid.t = 0.0
	await physics_frame
	var wrecks: Array[Node] = placed("wreck.tscn")
	check(wrecks.size() == Belly.WRECKS.size(), "its wreckage is in the scene")
	if wrecks.is_empty():
		finish()
		return
	var wreck: Wreck = wrecks[0] as Wreck
	var low_deck: float = wreck.global_position.y
	await _put(Vector2(wreck.global_position.x, low_deck - 60.0))
	var aboard: bool = await within(func() -> bool: return player.is_on_floor(), 1.0)
	check(aboard and absf(player.feet_y() - wreck.global_position.y) < 8.0, "the wizard stands on a piece of wreckage in its pit")
	acid.t = Acid.HOLD_LOW + Acid.WARN
	hp = player.health.health
	var risen: bool = await within(func() -> bool: return acid.level() >= 1.0, Acid.RISE + 1.0)
	await physics_frame
	check(risen and wreck.global_position.y < low_deck - (acid.low_y - acid.high_y) * 0.8, "it floats up on the flood")
	check(player.is_on_floor() and absf(player.feet_y() - wreck.global_position.y) < 10.0 and player.health.health == hp, "carrying the wizard up with it, clear of the acid")
	acid.t = Acid.period() - 0.1
	await within(func() -> bool: return acid.level() == 0.0, 1.0)
	await physics_frame
	check(absf(wreck.global_position.y - wreck.rest_y) < 1.0 or wreck.global_position.y < wreck.rest_y, "drained, it settles again")
	RunState.delete_save()
	finish()


## The hole of open acid in the first pit of the belly's floor: the cell beside its wreckage.
func _pit(w: LevelGen) -> Vector2i:
	var wrecks: Array[Vector2i] = w.objects_of(LevelGen.Type.WRECK)
	wrecks.sort()
	return wrecks[0] + Vector2i(Wreck.WIDE, 0)


## Press `action` as a player would (it reaches the game before its next physics step).
func _press(action: StringName) -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)


## Put the wizard at `at`, falling free, and let them land.
func _put(at: Vector2) -> void:
	player.end_invulnerable()
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await within(func() -> bool: return player.is_on_floor(), 1.0)
	await physics_frame
