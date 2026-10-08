extends TestKit
## The gates at the band ends (Bosses, docs/REGIONS_PLAN.md §5): which rows they are and who guards
## them, the way on sealed while the boss lives, a lantern death healing it, its death opening its
## band's every gate level for the rest of the run and leaving a free relic, an arena boss behind its
## door, no hyperspace past a living boss's gate, and the F7 panel's Slay boss. The rules are shown
## with the stand-in (Boss), in the necromancer's arena; the worm and the bramble, which are built,
## have worm_test and bramble_test.
## godot --headless --path . --script res://tests/gate_test.gd


func run() -> void:
	MapInfo.debug = false
	print("the gates")
	var g: int = NextWorldDef.GARDEN_ROWS
	var b: int = NextWorldDef.BAND
	var want: Dictionary = {g: &"worm", -g: &"bramble", g + b: &"necromancer", g + 2 * b: &"beast", -(g + b): &"spider", -(g + 2 * b): &"whale"}
	var rows_ok: bool = true
	for row: int in range(-(g + 4 * b), g + 4 * b + 1):
		rows_ok = rows_ok and Bosses.gate_at(row) == StringName(want.get(row, &""))
	for row: int in want:
		rows_ok = rows_ok and Bosses.row_of(want[row]) == row
	check(rows_ok, "the garden's gates at rows %d and %d, and each band's far end, each with its boss" % [g, -g])
	check(not Bosses.in_arena(&"worm") and not Bosses.in_arena(&"bramble") and Bosses.in_arena(&"necromancer") and Bosses.in_arena(&"whale"), "the worm and the bramble fight in their gate level, the rest in an arena")
	check(Bosses.crossed(1, g + 2) == [&"worm"] and Bosses.crossed(g, g + 1) == [&"worm"] and Bosses.crossed(g + 1, g + 4).is_empty(), "a way out past a gate level crosses its gate")
	check(Bosses.crossed(g + 4, 1).is_empty() and Bosses.crossed(-2, g + 3) == [&"worm"] and Bosses.crossed(2, -(g + b + 1)) == [&"bramble", &"spider"], "toward the start none; across it, only the far side's")
	check(Relics.at(Vector2i(28, g)) == &"" and Relics.at(Vector2i(28, g + b)) == &"", "a gate level holds no relic of its own")
	var arena: SideWorld = Worlds.proto(Worlds.kind_of(Arena))
	check(arena.deals(Vector2i(28, g + b)) and arena.deals(Vector2i(28, -(g + b))) and not arena.deals(Vector2i(28, g)) and not arena.deals(Vector2i(28, 1)), "an arena boss's gate level has its door; no other level does")

	print("in the gate level")
	var worm_level: LevelGen = build(Vector2i(28, g))
	var bosses: Array[Vector2i] = worm_level.objects_of(LevelGen.Type.BOSS)
	check(bosses.size() == 1 and StringName(worm_level.get_cell(bosses[0]).extra_info) == &"worm", "the worm's gate level holds it")
	check(LevelGen.dist(bosses[0], worm_level.exits[MapInfo.Exit.DEEPER]) >= LevelGen.BOSS_APART, "near the way on it guards")
	check(build(Vector2i(28, g)).objects == worm_level.objects and build(Vector2i(28, g + 1)).objects_of(LevelGen.Type.BOSS).is_empty(), "the same every build, and only there")

	await boot(28)
	player.set_physics_process(false)
	await _go(Vector2i(28, g))
	var worm_way: LevelExit = _exit(MapInfo.Exit.DEEPER)
	player.collect(9999)
	check(placed("worm.tscn").size() == 1 and placed("boss.tscn").is_empty(), "in play the worm itself is there (Worm; worm_test fights it)")
	check(worm_way.sealed() == &"worm" and worm_way.interaction_hint().get("sealed", false), "its way on is sealed")
	worm_way.interacted()
	await settle()
	check(info.coord == Vector2i(28, g), "and no stars open it")

	print("the bramble's gate")
	await _go(Vector2i(28, -g))
	check(placed("bramble.tscn").size() == 1 and placed("boss.tscn").is_empty(), "in play the bramble itself is there (Bramble; bramble_test fights it)")
	check(_exit(MapInfo.Exit.DEEPER).sealed() == &"bramble", "its way on is sealed")

	# The bosses fought in an arena are not built yet: their stand-in (Boss) shows the gate's rules.
	print("the stand-in, in an arena")
	await _go(Vector2i(28, g + b))
	check(placed("boss.tscn").is_empty() and _exit(MapInfo.Exit.DEEPER).sealed() == &"necromancer", "the necromancer's gate level is sealed, with no boss in it")
	var door: int = Worlds.door(Worlds.kind_of(Arena))
	var doors: Array[Node] = placed("level_exit.tscn").filter(func(n: Node) -> bool: return (n as LevelExit).exit == door)
	check(doors.size() == 1 and (doors[0] as LevelExit).sealed() == &"" and (doors[0] as LevelExit).price() == 0, "its arena's door is open and free")
	info.travel(door)
	await settle()
	player.set_physics_process(false)
	var arena_at: Vector2i = info.coord
	check(Worlds.kind_at(arena_at) == Worlds.kind_of(Arena) and placed("boss.tscn").size() == 1, "inside, the boss")
	var boss: Boss = placed("boss.tscn")[0] as Boss
	check(boss.boss == &"necromancer" and (boss.get_node("Wound") as Wound).hp == Boss.HP, "the necromancer's stand-in, whole")

	print("a death heals it")
	var wound: Wound = boss.get_node("Wound") as Wound
	for i: int in range(3):
		wound.hit(1, Vector2.RIGHT)
	check(wound.hp == Boss.HP - 3, "struck, it shows %d of %d" % [wound.hp, Boss.HP])
	info.run.vulnerable = false
	player.die()
	await settle()
	await _go(arena_at)
	boss = placed("boss.tscn")[0] as Boss
	check((boss.get_node("Wound") as Wound).hp == Boss.HP and not info.run.bosses.has(&"necromancer"), "after a lantern death it is whole again")

	print("slain")
	wound = boss.get_node("Wound") as Wound
	var fell: Vector2 = boss.global_position
	for i: int in range(Boss.HP):
		if is_instance_valid(boss) and not boss.is_queued_for_deletion():
			wound.hit(1, Vector2.RIGHT)
	await settle()
	check(info.run.bosses.has(&"necromancer") and placed("boss.tscn").is_empty(), "it dies, slain for the run")
	var relics: Array[Node] = placed("relic.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"necromancer")
	# Each hit knocks it back a little, so it falls a way from where it stood.
	var where: Vector2 = (info.run.boss_relics.get(&"necromancer", [null, Vector2.INF]) as Array)[1]
	check(relics.size() == 1 and (relics[0] as Node2D).global_position.distance_to(where) < 1.0 and where.distance_to(fell) < 400.0 and (relics[0] as Relic).price() == 0, "leaving a relic where it fell, free")
	var move: StringName = (relics[0] as Relic).ability
	check(Relics.MOVES.has(move) and Abilities.tier(player, move) == 0, "a move the wizard does not know (%s)" % move)
	(relics[0] as Relic).take()
	# A spell swaps for the one held, which is left on the plinth: the relic stays, holding it.
	var swapped: bool = not info.record().relic_left.is_empty()
	check(Abilities.tier(player, move) == 1 and info.run.boss_relics.has(&"necromancer") == swapped, "taken, it teaches it, and is gone (or holds the spell it swapped out: %s)" % swapped)
	info.travel(MapInfo.Exit.BACK)
	await settle()
	player.set_physics_process(false)
	check(info.coord == Vector2i(28, g + b) and _exit(MapInfo.Exit.DEEPER).sealed() == &"", "back in its gate level, the way on is open")
	await _go(Vector2i(29, g + b))
	check(placed("boss.tscn").is_empty() and _exit(MapInfo.Exit.DEEPER).sealed() == &"", "and every other gate level of its band too")
	await _go(Vector2i(28, g))
	check(placed("worm.tscn").size() == 1 and _exit(MapInfo.Exit.DEEPER).sealed() == &"worm", "the way down still waits on the worm")
	await _go(Vector2i(28, -g))
	check(_exit(MapInfo.Exit.DEEPER).sealed() == &"bramble", "and the way up on the bramble")

	print("no hyperspace past a gate")
	var hyper: Hyperspace = Worlds.proto(Worlds.kind_of(Hyperspace)) as Hyperspace
	var found: Variant = null
	for x: int in range(1, 400):
		var from: Vector2i = Vector2i(x, -1)
		if hyper.deals(from) and Hyperspace.crosses(from):
			found = from
			break
	check(found != null, "a hyperspace from above the start that crosses to below it")
	if found != null:
		var def: NextWorldDef = Rules.def_for(found)
		var fresh: RunState = RunState.new()
		check(def.seal(Worlds.door(Worlds.kind_of(Hyperspace)), fresh) == &"worm", "its door is sealed while the worm lives")
		fresh.bosses[&"worm"] = true
		check(def.seal(Worlds.door(Worlds.kind_of(Hyperspace)), fresh) == &"", "and opens once it is slain")

	print("slain from the F7 panel")
	await _go(Vector2i(28, g))
	check(info.slay_boss() and placed("worm.tscn").is_empty(), "Slay boss kills the worm in its gate level at once")
	await settle()
	check(info.run.bosses.has(&"worm") and _exit(MapInfo.Exit.DEEPER).sealed() == &"" and placed("relic.tscn").any(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"worm"), "its gate opens and its relic is left")
	await _go(Vector2i(28, -g))
	check(info.slay_boss() and placed("bramble.tscn").is_empty(), "and the bramble in its gate level")
	await settle()
	check(info.run.bosses.has(&"bramble") and _exit(MapInfo.Exit.DEEPER).sealed() == &"" and placed("relic.tscn").any(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"bramble"), "its way up opens and its relic is left")
	await _go(Vector2i(28, g + 2 * b))
	check(info.slay_boss() and info.run.bosses.has(&"beast") and _exit(MapInfo.Exit.DEEPER).sealed() == &"", "and slays an arena boss from its gate level")
	check(not info.slay_boss(), "with nothing left to slay, it does nothing")

	print("saved")
	var saved: Dictionary = info.run.to_save(info.coord, {})
	var again: RunState = RunState.new()
	again.from_save(saved)
	check(again.bosses.has(&"necromancer") and again.bosses.has(&"worm") and again.bosses.has(&"bramble"), "the bosses slain are kept with the run")
	RunState.delete_save()
	finish()


## Load level `at` (arriving at its way back) and wait for it.
func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)


## The level's exit `which`.
func _exit(which: int) -> LevelExit:
	for n: Node in placed("level_exit.tscn"):
		if (n as LevelExit).exit == which:
			return n as LevelExit
	return null
