extends TestKit
## The map kept from run to run (Known, docs/REVIEW_PLAN.md §4): part of a level seen and a boss's
## level visited, the run ends and starts again on its seed: the level's map and the worlds map hold
## what was seen, the boss's column is marked; on another seed it is not; a kept level whose layout
## stamp no longer matches is dropped; and nothing is kept from a debug run.
## godot --headless --path . --script res://tests/known_test.gd


func run() -> void:
	await boot(28)
	var seed: int = info.run.run_seed
	var at: Vector2i = Vector2i(seed, 1)
	await go(at)
	# Part of the level seen: a cell and those round it (MapInfo.reveal).
	var cell: Vector2i = info.world.free_floors()[0]
	info.reveal(cell)
	var seen_before: int = info.seen().count(1)
	check(seen_before > 0, "part of %s seen (%d cells)" % [at, seen_before])
	var boss: StringName = Bosses.ahead(1)
	var lair: Vector2i = Vector2i(Bosses.column(boss, seed), Bosses.row_of(boss))
	await go(lair)
	info.save_run()
	check(Known.has(at) and Known.has(lair), "what the run has seen is kept as it saves")

	print("a run on the seed again")
	info.end_run()
	await until(func() -> bool: return info.run_ending <= 0.0 and not info.travelling and info.world != null, 20000)
	await settle()
	check(not info.run.records.has(at) and info.run.run_seed == seed, "the run has begun again, its records gone")
	check(RisoMap_pickable().has(at), "the worlds map can pick the level known from before")
	check((info.run.boss_hints.get(boss, []) as Array).has([lair.x, 0]), "the %s's column, met before, is marked" % boss)
	await go(at)
	check(info.seen().count(1) >= seen_before and info.is_seen(cell), "the level's map holds what was seen before (%d cells)" % info.seen().count(1))

	print("another seed")
	info.start_run(seed + 1)
	await settle()
	var other: StringName = boss
	check(not info.run.boss_hints.has(other), "on another seed, no boss's column is marked from before")

	print("a layout changed")
	var places: Dictionary = Known.kept()["places"]
	(places[at] as Dictionary)["stamp"] = 12345
	var w: LevelGen = build(at)
	check(Known.seen_for(at, w).is_empty() and not Known.has(at), "a kept level whose layout stamp does not match is dropped")

	print("a debug run")
	var count: int = Known.places().size()
	MapInfo.debug = true
	var far: Vector2i = Vector2i(seed + 40, 2)
	await go(far)
	info.save_run()
	MapInfo.debug = false
	check(not Known.has(far) and Known.places().size() == count, "nothing is kept from a debug run")
	RunState.delete_save()
	Known.forget()
	finish()


## The worlds map's pickable levels (RisoMap.pickable).
func RisoMap_pickable() -> Array[Vector2i]:
	var map: Node = main.get_node("RisoMap")
	return map.call("pickable", info)
