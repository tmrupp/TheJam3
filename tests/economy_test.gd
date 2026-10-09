extends TestKit
## Groups 7 and 8 of docs/DEEPER_PLAN.md ("Grouped for implementation"): light, lanterns and death,
## and the economy pass.
## - Lanterns are scarce: one at the way back (the start lantern at depth 0) and LANTERNS_PER_K more.
## - Giving up (the pause menu) is a death back to the lit lantern, offered only while protected.
## - Mend heals from draughts that only learning it or burning the lit lantern refills.
## - Every level has one star cluster worth cluster_value(depth); some levels a skeleton key.
## - The keyring carries more keys; a skeleton key opens any one door, then crumbles.
## - Warp and rift cost stars each cast, paid only when they work.
## godot --headless --path . --script res://tests/economy_test.gd

## A key of `color` laid far from the wizard (so it is not grabbed by walking past it).
func spawn_key(color: int) -> Node2D:
	var key: Node2D = (load("res://prefabs/key.tscn") as PackedScene).instantiate()
	key.set_meta(&"key_color", color)
	key.position = player.position + Vector2(2000, 0)
	info.map_elements.add_child(key)
	return key


## A shut door none of the carried keys opens, or null.
func locked_door() -> Node:
	for door: Node in placed("door.tscn"):
		if not player.keyring.has(int(door.get_meta(&"key_color", 0))):
			return door
	return null


func lanterns() -> Array[Node]:
	return info.map_elements.get_children().filter(func(n: Node) -> bool: return n is Checkpoint and not n.is_queued_for_deletion())


func count(w: LevelGen, type: LevelGen.Type) -> int:
	var n: int = 0
	for column: Array in w.cells:
		for cell: LevelGen.Cell in column:
			if cell.type == type:
				n += 1
	return n


## Whether `v` is inside one of the level's vaults (whose loot is checked in vaults_test).
func in_vault(w: LevelGen, v: Vector2i) -> bool:
	return w.vaults.any(func(vault: Dictionary) -> bool: return (vault["room"] as Array).has(v))


func vault_count(w: LevelGen, type: LevelGen.Type) -> int:
	var n: int = 0
	for vault: Dictionary in w.vaults:
		for v: Vector2i in vault["room"]:
			if w.get_cell(v).type == type:
				n += 1
	return n


func run() -> void:
	generation()
	await boot(28)
	player.set_physics_process(false)

	await keys()
	await casting()
	await mending()
	await giving_up()
	await cluster()
	saving()

	RunState.delete_save()
	finish("lanterns, giving up, mend, clusters, keys and cast costs")


## Generated levels: few lanterns, one cluster each, skeleton keys in some.
func generation() -> void:
	print("generation")
	var most_lanterns: int = 0
	for seed_value: int in [1, 7, 28, 99, 512]:
		for depth: int in [0, 2, 5]:
			var def: NextWorldDef = Rules.def_for(Vector2i(seed_value, depth))
			var w: LevelGen = LevelGen.new(collapse(def.coord), def)
			var label: String = "seed %d depth %d" % [seed_value, depth]
			var lit: int = count(w, LevelGen.Type.CHECKPOINT)
			most_lanterns = maxi(most_lanterns, lit)
			check(lit <= 1 + w.per_area(LevelGen.LANTERNS_PER_K), label + ": %d lanterns, one at the way back and a few more" % lit)
			check(w.exit_lanterns.keys() == [MapInfo.Exit.BACK], label + ": only the way back has a lantern beside it")
			check(count(w, LevelGen.Type.CLUSTER) - vault_count(w, LevelGen.Type.CLUSTER) == 1, label + ": one star cluster (besides any in vaults)")
			var keys: int = 0
			for v: Vector2i in w.objects:
				var cell: LevelGen.Cell = w.get_cell(v)
				if cell.type == LevelGen.Type.KEY and cell.extra_info != null and int(cell.extra_info) == KeyRing.SKELETON and not in_vault(w, v):
					keys += 1
			for secret: Dictionary in w.secrets:
				for reward: Array in secret["rewards"]:
					if reward[1] == LevelGen.Type.KEY and int(reward[2]) == KeyRing.SKELETON:
						keys += 1
			check(keys == (1 if def.skeleton else 0), label + ": a skeleton key only where dealt, besides vaults (%d)" % keys)
	check(most_lanterns <= 3, "no level has more than 3 lanterns (%d)" % most_lanterns)
	var dealt: int = 0
	for x: int in range(100):
		if Rules.skeleton_at(Vector2i(x, 3)):
			dealt += 1
	check(dealt >= 15 and dealt <= 45, "skeleton keys in about %d%% of levels (%d of 100)" % [Rules.SKELETON_CHANCE, dealt])
	check(not Rules.skeleton_at(Vector2i(28, 0)), "none in first levels")
	check(Rules.cluster_value(0) == 10 and Rules.cluster_value(5) > Rules.cluster_value(0), "a cluster is worth 10 at the surface, more deeper")


func keys() -> void:
	print("the keyring")
	(colored("key.tscn", 0)[0] as Node).call("touch", player)
	check(player.keyring.all() == [0], "carrying colour 0")
	(colored("key.tscn", 1)[0] as Node).call("touch", player)
	await settle(1)
	check(player.keyring.all() == [1], "without the keyring, one key: colour 1 replaces colour 0")
	check(colored("key.tscn", 0).any(func(n: Node) -> bool: return n.has_meta(&"dropped_id")), "and colour 0 is left where colour 1 was")
	Abilities.grant(player, &"keyring")
	check(player.keyring.capacity() == 2, "keyring I carries two")
	spawn_key(2)
	await process_frame
	(colored("key.tscn", 2).back() as Node).call("touch", player)
	await settle(1)
	check(player.keyring.all() == [1, 2], "colour 2 joins colour 1 on the ring")
	var again: Node = spawn_key(2)
	await process_frame
	again.call("touch", player)
	check(player.keyring.all() == [1, 2] and placed("key.tscn").has(again), "a colour already carried is left lying")
	var three: Node = spawn_key(3)
	await process_frame
	three.call("touch", player)
	await settle(1)
	check(player.keyring.all() == [2, 3], "a full ring leaves its oldest key behind")
	var older: Array[Node] = colored("door.tscn", 2)
	if not older.is_empty():
		var door: Node = older[0]
		door.get_node("Unlock").call("try_open")
		await settle(1)
		check(not is_instance_valid(door) or door.is_queued_for_deletion(), "an older key on the ring opens its doors")

	print("skeleton keys")
	player.keyring.set_all([3])
	var shut: Node = locked_door()
	player.keyring.set_skeletons(1)
	shut.get_node("Unlock").call("touch", player)
	await settle(1)
	check(is_instance_valid(shut) and not shut.is_queued_for_deletion() and player.keyring.skeletons() == 1, "walking into a door never spends a skeleton key")
	shut.get_node("Unlock").call("interacted")
	await settle(1)
	check((not is_instance_valid(shut) or shut.is_queued_for_deletion()) and player.keyring.skeletons() == 0, "interacting opens any door with one, and it crumbles")
	var other: Node = locked_door()
	if other != null:
		other.get_node("Unlock").call("interacted")
		await settle(1)
		check(is_instance_valid(other) and not other.is_queued_for_deletion(), "with none left, the door stays shut")
	# A skeleton key laid in the level goes in the pocket, not on the ring.
	var skeleton: Node2D = spawn_key(KeyRing.SKELETON)
	await process_frame
	skeleton.call("touch", player)
	check(player.keyring.skeletons() == 1 and player.keyring.all() == [3], "a skeleton key is pocketed apart from the ring")
	var exits: Array[Node] = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.call("lock")) >= 0 and int(n.call("lock")) != 3)
	if not exits.is_empty():
		var side: Node = exits[0]
		var which: int = int(side.get("exit"))
		side.call("interacted")
		check(player.keyring.skeletons() == 0 and bool(info.record().lateral_open.get(which, false)), "it opens a side door too")
		await settle()
		player.set_physics_process(false)
		info.travel(MapInfo.Exit.RIGHT if which == MapInfo.Exit.LEFT else MapInfo.Exit.LEFT)
		await settle()
		player.set_physics_process(false)
	check(info.coord == Vector2i(28, 0), "back in the first level")


func casting() -> void:
	print("cast costs")
	Abilities.set_tier(player, &"warp", 1)
	var warp: Warp = player.get_node("Warp") as Warp
	player.collect(-player.coins.coins)
	var before: Vector2 = player.global_position
	Abilities.cast(player)
	check(warp.recharge == 0.0 and player.global_position == before, "no warp without the stars for it")
	var price: int = Abilities.cast_price(&"warp", 0)
	check(price == 4 and Abilities.cast_price(&"warp", 6) > price, "a warp costs 4 at the surface, more deeper")
	check(Abilities.cast_price(&"hex", 3) == 0 and Abilities.cast_price(&"mend", 3) == 0, "other spells are free to cast")
	player.collect(10)
	Abilities.cast(player)
	check(warp.recharge > 0.0 and player.coins.coins == 10 - price, "a warp is paid as it is cast")
	Abilities.cast(player)
	check(player.coins.coins == 10 - price, "a cast that fails (recharging) costs nothing")
	while warp.warping:
		await process_frame
	player.set_physics_process(false)
	player.global_position = before
	await settle(1)
	player.collect(-player.coins.coins)


func mending() -> void:
	print("mend")
	Abilities.grant(player, &"mend")
	var mend: Mend = player.get_node("Mend") as Mend
	check(Abilities.spell(player) == &"mend" and mend.draughts() == 1, "mend I holds one draught, full when learned")
	Abilities.grant(player, &"mend")
	check(mend.draughts() == 2, "mend II holds two")
	player.health.health = 1
	Abilities.cast(player)
	check(player.health.health == 2 and mend.draughts() == 1, "a cast heals a heart and uses a draught")
	Abilities.cast(player)
	Abilities.cast(player)
	check(player.health.health == 3 and mend.draughts() == 0, "the draughts run out")
	player.health.health = 2
	Abilities.cast(player)
	check(player.health.health == 2, "nothing heals with none left")
	Abilities.set_tier(player, &"hex", 1)
	Abilities.set_tier(player, &"mend", 2)
	check((player.get_node("Mend") as Mend).draughts() == 0, "swapping the spell away and back does not fill the draughts")
	mend = player.get_node("Mend") as Mend
	var lit: Node = lanterns().filter(info.is_respawn_lantern)[0]
	check(info.can_burn(lit), "the lit lantern can be burned into the spell")
	lit.call("interacted")
	check(mend.draughts() == 2, "burning it fills the draughts")
	check(info.run.vulnerable and info.is_lantern_spent(lit), "and the lantern is spent: no protection")
	check(not info.can_burn(lit) and not info.light_lantern(lit), "a burned lantern cannot be burned or lit again")
	player.health.health = player.health.max_health
	Abilities.set_tier(player, &"mend", 0)


func giving_up() -> void:
	print("giving up")
	check(not info.can_give_up(), "no giving up without a lit lantern (that would end the run)")
	var menu: Node = main.get_node("Menu")
	menu.call("pause_resume_game")
	check(not bool(menu.get("give_up_button").visible), "the pause menu does not offer it")
	menu.call("pause_resume_game")
	var lantern: Node = lanterns().filter(func(n: Node) -> bool: return not info.is_lantern_spent(n))[0]
	var cell: Vector2i = lantern.get_meta(&"cell")
	check(info.light_lantern(lantern), "lighting another lantern")
	check(info.can_give_up(), "now giving up is offered")
	menu.call("pause_resume_game")
	check(bool(menu.get("give_up_button").visible), "in the pause menu")
	player.collect(4)
	# The level's stars are all taken already, so the wizard picks none up on the way back.
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "coin.tscn" and n.has_meta(&"cell"):
			info.record().taken[n.get_meta(&"cell")] = true
			n.queue_free()
	player.global_position += Vector2(200, 0)
	menu.call("give_up")
	check(not paused, "giving up closes the menu")
	await settle()
	player.set_physics_process(false)
	# The level reloaded with the respawn: find the lantern again.
	lantern = lanterns().filter(func(n: Node) -> bool: return n.get_meta(&"cell") == cell)[0]
	check(info.run.vulnerable and info.is_lantern_spent(lantern), "it is a death: the lantern burns out")
	check(info.run.has_ghost and info.run.ghost_stars == 4 and player.coins.coins == 0, "the stars drop into a ghost")
	check(player.global_position.distance_to(info.respawn_marker.global_position) < 80.0, "back at the lantern")
	check(player.health.health == 1, "giving up respawns at one heart")


func cluster() -> void:
	print("the star cluster")
	var found: Array[Node] = placed("star_cluster.tscn").filter(func(n: Node) -> bool: return not in_vault(info.world, n.get_meta(&"cell")))
	check(found.size() == 1, "one star cluster in the level (besides any in vaults)")
	if found.is_empty():
		return
	var c: Node = found[0]
	var cell: Vector2i = c.get_meta(&"cell")
	var before: int = player.coins.coins
	c.call("touch", player)
	check(player.coins.coins == before + Rules.cluster_value(0), "it gives %d stars" % Rules.cluster_value(0))
	check((info.record().taken as Dictionary).has(cell), "and stays taken")


func saving() -> void:
	print("saving")
	Abilities.grant(player, &"keyring")
	player.keyring.set_all([0, 1, 2])
	player.keyring.set_skeletons(2)
	Abilities.grant(player, &"mend")
	player.mend_draughts = 0
	info.save_run()
	var data: Dictionary = RunState.read_save()
	check(data.get("keys", []) == [0, 1, 2] and int(data.get("skeleton_keys", 0)) == 2 and int(data.get("mend_draughts", -1)) == 0, "the ring, skeleton keys and draughts are saved")
	player.keyring.clear()
	Mend.restore(player, -1)
	player.keyring.set_all(data["keys"])
	player.keyring.set_skeletons(int(data["skeleton_keys"]))
	Mend.restore(player, int(data["mend_draughts"]))
	check(player.keyring.all() == [0, 1, 2] and player.keyring.skeletons() == 2 and (player.get_node("Mend") as Mend).draughts() == 0, "and restored")
	player.keyring.set_all([1])
	check(player.keyring.all() == [1] and player.keyring.all().size() <= 1, "an old save's one key loads as before")
