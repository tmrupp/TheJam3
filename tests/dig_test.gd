extends TestKit
## A shrine's door (Shrine.sells_door): in a level the labyrinth left with no way on, the shrine's
## third station sells one at full health, for stars and a key. Bought, a door appears at the spot
## kept for the way on, it leads on to the level beyond, which has its way back again, and the way
## is kept with the run (RunState.dug), saved, and gone with a new run.
## godot --headless --path . --script res://tests/dig_test.gd


func run() -> void:
	RunState.save_path = "user://dig_test.save"
	await boot(28)
	player.set_physics_process(false)

	print("a shrine sells a way on where the labyrinth left none")
	var at: Vector2i = _wanting()
	check(at != Vector2i(-1, -1), "a garden level with no way on whose shrine sells one: %s" % at)
	if at == Vector2i(-1, -1):
		finish()
		return
	var beyond: Vector2i = at + Vector2i(0, NextWorldDef.away(at.y))
	check(not info.run.dug.has(beyond) and not Rules.def_for(beyond).ways().has(MapInfo.Exit.BACK), "the level beyond has no way back either")
	await go(at)
	var shrine: Shrine = placed("shrine.tscn")[0] as Shrine
	check(_exit(MapInfo.Exit.DEEPER) == null and not info.here.ways().has(MapInfo.Exit.DEEPER) and info.here.lead(MapInfo.Exit.DEEPER).is_empty(), "no door on, and no way on")
	player.health.health = 1
	check(shrine.station() == &"mend", "hurt, it mends first")
	player.health.health = player.health.max_health
	check(shrine.station() == &"door" and shrine.door_wanted(), "at full health, it sells a way on")
	check_eq(shrine.station_price(), roundi(Shrine.DOOR_PRICE * float(Rules.deeper_price(at.y))), "for the level's deeper price")
	check_eq(shrine.keys_asked(), Shrine.KEY_COST, "and a key")
	var price: int = shrine.station_price()
	player.collect(price - player.coins.coins)
	player.keyring.clear()
	shrine.buy_mend()
	check(not shrine.used() and _exit(MapInfo.Exit.DEEPER) == null, "with no key, nothing is bought")
	Abilities.set_tier(player, &"keyring", 1)
	player.keyring.set_all([1])
	shrine.buy_mend()
	await frames(2)
	check(shrine.used() and player.coins.coins == 0 and player.keyring.all().is_empty(), "bought: the stars and the key paid")
	var door: LevelExit = _exit(MapInfo.Exit.DEEPER)
	check(door != null and info.cell_at(door.global_position) == info.world.exits[MapInfo.Exit.DEEPER], "a door on stands at the spot kept for it")
	check(info.here.ways().has(MapInfo.Exit.DEEPER) and info.here.lead(MapInfo.Exit.DEEPER).get("to") == beyond, "and leads on, to %s" % beyond)
	check(info.run.dug.has(beyond) and Rules.def_for(beyond).ways().has(MapInfo.Exit.BACK), "the level beyond has its way back again")
	check(not shrine.door_wanted() and shrine.station() != &"door", "a way on dug, none is sold again")

	print("through it and back")
	info.travel(MapInfo.Exit.DEEPER)
	await until(func() -> bool: return info.coord == beyond and not info.travelling, 20000)
	await settle()
	player.set_physics_process(false)
	var back: LevelExit = _exit(MapInfo.Exit.BACK)
	check(info.coord == beyond and back != null and info.cell_at(back.global_position) == info.world.exits[MapInfo.Exit.BACK], "it leads on, and a door back stands where the wizard arrives")
	info.travel(MapInfo.Exit.BACK)
	await until(func() -> bool: return info.coord == at and not info.travelling, 20000)
	await settle()
	check(info.coord == at and _exit(MapInfo.Exit.DEEPER) != null, "back again, the door on is still there")

	print("kept with the run")
	var data: Dictionary = info.run.to_save(info.coord, {})
	var again: RunState = RunState.new()
	again.from_save(data)
	check(again.dug.has(beyond), "saved and taken up again")
	again.start(28)
	check(again.dug.is_empty() and not Rules.def_for(at).ways().has(MapInfo.Exit.DEEPER), "a new run digs its own")
	finish()


## A garden level, away from the start's rows and the gates, whose way on the labyrinth left out and
## whose shrine sells one; (-1, -1) for none.
func _wanting() -> Vector2i:
	for k: int in range(2, Bands.garden_rows()):
		for x: int in range(20, 60):
			var at: Vector2i = Vector2i(x, k)
			if not Rules.maze_has(at, MapInfo.Exit.DEEPER) and Shrine.sells_door_at(at) and Bosses.gate_at(at.y) == &"" and Worlds.arriving_at(at + Vector2i(0, 1)) == null:
				return at
	return Vector2i(-1, -1)


## The level's exit `which` in the scene, or null.
func _exit(which: int) -> LevelExit:
	for n: Node in placed("level_exit.tscn"):
		if (n as LevelExit).exit == which and not n.is_queued_for_deletion():
			return n as LevelExit
	return null
