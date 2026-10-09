extends TestKit
## The crag towers' pieces in play: the trapdoor in a watchtower's roof bears the wizard standing on
## it from the roof and stays shut, then swings open for good once the wizard comes up under it
## (Trapdoor); a rock-bug nest, an enemy for hex bolts, wakes with the wizard near, hatching bugs, no more than BROOD of its
## own at once (BugNest); and a mending bowl (MendWell) offers nothing at full health, then heals the
## hurt wizard to full for its price and is spent for good.
## godot --headless --path . --script res://tests/tower_pieces_test.gd


func run() -> void:
	# A crag level with all three: a watchtower's trapdoor, a nest and a mending bowl.
	var row: int = 0
	for k: int in range(NextWorldDef.BAND):
		var w: LevelGen = build(Vector2i(28, NextWorldDef.band_row(&"crags", k)))
		if [LevelGen.Type.TRAPDOOR, LevelGen.Type.NEST, LevelGen.Type.WELL].all(func(t: LevelGen.Type) -> bool: return not w.objects_of(t).is_empty()):
			row = NextWorldDef.band_row(&"crags", k)
			break
	check(row != 0, "a crag level holds a trapdoor, a nest and a mending bowl")
	await boot()
	info.coord = Vector2i(28, row)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.health.max_health = 99
	player.health.health = 99
	var cell: float = float(info.tile_map.tile_set.tile_size.y) * info.tile_map.global_scale.y
	await trapdoor(cell)
	await nest(cell)
	await well()
	player.set_physics_process(true)
	RunState.delete_save()
	finish()


func trapdoor(cell: float) -> void:
	print("trapdoor")
	var all: Array[Node] = placed("trapdoor.tscn")
	check(not all.is_empty(), "the level has trapdoors")
	if all.is_empty():
		return
	var door: Trapdoor = all[0] as Trapdoor
	var at: Vector2i = door.get_meta(&"cell")
	var top: float = door.global_position.y - Trapdoor.HALF
	# Dropped on it from the roof: it holds them up and stays shut.
	player.global_position = door.global_position + Vector2(0.0, -cell)
	player.velocity = Vector2.ZERO
	await frames(60)
	check(is_instance_valid(door) and not door.is_queued_for_deletion(), "stood on from above, it stays shut")
	check(player.global_position.y < top and player.is_on_floor(), "and bears the wizard (%.0f over its top %.0f)" % [player.global_position.y, top])
	check(info.solid_at(door.global_position), "and is solid on the map")
	# Come up under it, from the room below: it opens, for good.
	player.global_position = door.global_position + Vector2(0.0, cell * 0.6)
	player.velocity = Vector2.ZERO
	check(await until(gone(door)), "from inside, it swings open")
	check(info.record().opened.has(at), "and the level record keeps it open")
	check(not info.solid_at(info.cell_position(at)), "so the hatch is clear on the map")


func nest(cell: float) -> void:
	print("nest")
	var all: Array[Node] = placed("bug_nest.tscn")
	check(not all.is_empty(), "the level has nests")
	if all.is_empty():
		return
	var host: BugNest = all[0] as BugNest
	check(host.is_in_group(&"hex_target") and host.get_node_or_null("Wound") is Wound, "an enemy, for hex bolts to destroy")
	player.set_physics_process(false)
	player.global_position = host.global_position + Vector2(cell * float(BugNest.WAKE + 4), 0.0)
	# (Any it hatched while the wizard was about the trapdoor, or was hatching then, cleared away.)
	await frames(int(BugNest.HATCH * 60.0) + 10)
	for bug: Node2D in host.brood:
		bug.queue_free()
	await frames(int((BugNest.FIRST + BugNest.HATCH) * 60.0) + 30)
	check(host.brood.is_empty() and not host.awake(), "with the wizard far off, it sleeps")
	player.global_position = host.global_position + Vector2(cell * 3.0, -cell * 0.5)
	check(await until(func() -> bool: return host.brood.size() == 1, 6000), "with the wizard near, it hatches a rock-bug")
	var bug: Node2D = host.brood[0]
	check(bug.get_node("RockBug") is RockBug and not bug.has_meta(&"cell"), "a rock-bug, not one of the level's")
	check(await until(func() -> bool: return host.brood.size() == BugNest.BROOD, int(BugNest.EVERY * 1000.0) + 4000), "and another, after a while")
	host.wait = 0.0
	await frames(int(BugNest.HATCH * 60.0) + 30)
	check(host.brood.size() <= BugNest.BROOD and host.hatching < 0.0, "but no more than BROOD of its own at once")
	player.set_physics_process(true)


func well() -> void:
	print("mending bowl")
	var all: Array[Node] = placed("mend_well.tscn")
	check(not all.is_empty(), "the level has a mending bowl")
	if all.is_empty():
		return
	var bowl: MendWell = all[0] as MendWell
	var it: Interactable = bowl.get_node("Interactable") as Interactable
	player.set_physics_process(false)
	player.global_position = bowl.global_position
	player.health.health = player.health.max_health
	await frames(5)
	check(not it.available and not bowl.used(), "at full health it offers nothing")
	player.health.health = player.health.max_health - 3
	player.collect(bowl.heal_price() - 1 - player.coins.coins)
	bowl.buy_mend()
	check(player.health.health == player.health.max_health - 3 and not bowl.used(), "short of its price, it does nothing")
	player.collect(1)
	await frames(2)
	check(it.available, "hurt, with its price, it is offered")
	bowl.buy_mend()
	check(player.health.health == player.health.max_health and player.coins.coins == 0, "and heals to full for its price (%d)" % bowl.heal_price())
	check(bowl.used() and info.record().mended.has(bowl.get_meta(&"cell")), "spent for good, kept in the level record")
	player.health.health = player.health.max_health - 1
	await frames(2)
	check(not it.available, "and offers nothing after")
	player.set_physics_process(true)
