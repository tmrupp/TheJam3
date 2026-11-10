extends TestKit
## Relic unlocks (KeyRing.UNLOCK): a boss drops one where it falls (MapInfo.boss_slain); picked up,
## it goes in the pocket apart from the ring, trails the wizard as keys do and is kept in the save. A
## relic of a move not yet known cannot be taken without one, and taking it uses one up; the next
## tier of a move already known, from another relic, needs none.
## godot --headless --path . --script res://tests/relic_unlock_test.gd


func run() -> void:
	await boot(28)
	player.keyring.clear()
	await _drop()
	await _relics()
	RunState.delete_save()
	finish()


## A boss's drop, picked up: in the pocket, trailing the wizard, kept in the save.
func _drop() -> void:
	print("a boss's drop")
	freeze()
	# On a floor a few cells from the wizard, so it is dropped out of their reach.
	var here: Vector2i = info.cell_at(player.global_position)
	var spot: Variant = LevelGen.best_of(info.world.free_floors(), func(v: Vector2i) -> int: return absi(LevelGen.dist(v, here) - 4))
	var at: Vector2 = info.cell_position(spot as Vector2i)
	info.boss_slain(&"worm", at)
	await settle(5)
	var lying: Array[Node] = unlocks_lying()
	check_eq(lying.size(), 1, "a slain boss drops a relic unlock")
	if lying.is_empty():
		return
	check(info.record().dropped.size() == 1, "kept in the level's record until picked up")
	player.global_position = (lying[0] as Node2D).global_position
	still()
	player.set_physics_process(true)
	check(await until(func() -> bool: return player.keyring.unlocks() == 1), "picked up at once, though it was dropped")
	check(player.keyring.all().is_empty(), "in the pocket, not on the ring")
	var art: RisoWizard = player.get_node_or_null("RisoWizard") as RisoWizard
	if art != null:
		check(await until(func() -> bool: return art.key_colors.has(KeyRing.UNLOCK)), "trailing the wizard as keys do")
	check_eq(int(player.to_save().get("relic_unlocks", 0)), 1, "kept in the save")


## Relics, with and without an unlock.
func _relics() -> void:
	print("relics")
	var move: StringName = &""
	for m: StringName in Relics.MOVES:
		if Abilities.tier(player, m) == 0 and Abilities.max_tier(m) >= 2:
			move = m
			break
	check(move != &"", "a relic move not yet known")
	player.keyring.set_unlocks(0)
	var relic: Relic = await _relic(move)
	check(relic.needs_unlock() and not relic.can_take(), "a relic of a move not yet known needs a relic unlock")
	relic.take()
	check_eq(Abilities.tier(player, move), 0, "and is not taken without one")
	player.keyring.set_unlocks(2)
	check(relic.can_take(), "with one, it can be taken")
	relic.take()
	await frames(2)
	check(Abilities.tier(player, move) == 1 and player.keyring.unlocks() == 1, "taken, it teaches %s and uses one unlock up" % move)
	var again: Relic = await _relic(move)
	check(not again.needs_unlock(), "another relic of %s, a move now known, needs none" % move)
	player.keyring.set_unlocks(0)
	again.take()
	await frames(2)
	check_eq(Abilities.tier(player, move), 2, "and raises it a tier without one")


## A relic of `move` left beside the wizard (as a beaten master leaves one: free of stars).
func _relic(move: StringName) -> Relic:
	var pos: Vector2 = player.global_position + Vector2(-300, 0)
	info.relic_left(pos, move, false)
	await frames(3)
	for n: Node in placed("relic.tscn"):
		var r: Relic = n as Relic
		if r.ability == move and r.global_position.distance_to(pos) < 1.0:
			return r
	return null
