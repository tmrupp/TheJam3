extends TestKit
## The gates at the band ends (Bosses, docs/REGIONS_PLAN.md §5): which rows they are and who guards
## them, the way on sealed while the boss lives, a lantern death healing it, its death opening its
## band's every gate level for the rest of the run and leaving a free relic, every boss in its gate
## level (no arenas), no hyperspace past a living boss's gate, and the F7 panel's Slay boss. The rules
## are shown with the beast (Beast), in its gate level, its souls cleared away (beast_test hunts
## them); the worm, the bramble, the golem and the necromancer have worm_test, bramble_test,
## golem_test and necromancer_test.
## godot --headless --path . --script res://tests/gate_test.gd


func run() -> void:
	MapInfo.debug = false
	print("the gates")
	var g: int = NextWorldDef.GARDEN_ROWS
	var b: int = NextWorldDef.BAND
	var want: Dictionary = {g: &"worm", -g: &"bramble", g + b: &"necromancer", g + 2 * b: &"beast", -(g + b): &"golem", -(g + 2 * b): &"whale"}
	var rows_ok: bool = true
	for row: int in range(-(g + 4 * b), g + 4 * b + 1):
		rows_ok = rows_ok and Bosses.gate_at(row) == StringName(want.get(row, &""))
	for row: int in want:
		rows_ok = rows_ok and Bosses.row_of(want[row]) == row
	check(rows_ok, "the garden's gates at rows %d and %d, and each band's far end, each with its boss" % [g, -g])
	check(Bosses.crossed(1, g + 2) == [&"worm"] and Bosses.crossed(g, g + 1) == [&"worm"] and Bosses.crossed(g + 1, g + 4).is_empty(), "a way out past a gate level crosses its gate")
	check(Bosses.crossed(g + 4, 1).is_empty() and Bosses.crossed(-2, g + 3) == [&"worm"] and Bosses.crossed(2, -(g + b + 1)) == [&"bramble", &"golem"], "toward the start none; across it, only the far side's")
	check(Relics.at(Vector2i(28, g)) == &"" and Relics.at(Vector2i(28, g + b)) == &"", "a gate level holds no relic of its own")
	var in_level: bool = true
	for row: int in want:
		var gate_level: LevelGen = build(Vector2i(28, row))
		var held: Array[Vector2i] = gate_level.objects_of(LevelGen.Type.BOSS)
		if want[row] == &"whale":
			in_level = in_level and held.is_empty()
		else:
			in_level = in_level and held.size() == 1 and StringName(gate_level.get_cell(held[0]).extra_info) == want[row]
	check(in_level, "every boss is in its gate level itself (no arenas), but the whale, which roams its row")

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

	print("the necromancer's gate")
	await _go(Vector2i(28, g + b))
	check(placed("necromancer.tscn").size() == 1 and placed("boss.tscn").is_empty() and _exit(MapInfo.Exit.DEEPER).sealed() == &"necromancer", "in play the necromancer itself is there, its way on sealed (Necromancer; necromancer_test fights it)")

	# The beast shows the gate's rules, its souls cleared away once it has sent them.
	print("the beast, in its gate level")
	var gate_at: Vector2i = Vector2i(28, g + 2 * b)
	await _go(gate_at)
	check(placed("beast.tscn").size() == 1 and placed("boss.tscn").is_empty() and _exit(MapInfo.Exit.DEEPER).sealed() == &"beast", "the beast's gate level is sealed, the beast in it (Beast)")
	var boss: Beast = placed("beast.tscn")[0] as Beast
	var wound: Wound = boss.get_node("Wound") as Wound
	check(boss.boss == &"beast" and wound.hp == Beast.CORE_HP, "whole")

	print("a death heals it")
	# A first strike wakes it, and it sends its souls out; they are cleared away.
	wound.hit(1, Vector2.RIGHT)
	BeastSouls.end(info.run)
	for i: int in range(3):
		wound.hit(1, Vector2.RIGHT)
	check(wound.hp == Beast.CORE_HP - 3, "struck, it shows %d of %d" % [wound.hp, Beast.CORE_HP])
	info.run.vulnerable = false
	player.die()
	await settle()
	await _go(gate_at)
	boss = placed("beast.tscn")[0] as Beast
	check((boss.get_node("Wound") as Wound).hp == Beast.CORE_HP and not info.run.bosses.has(&"beast"), "after a lantern death it is whole again")

	print("slain")
	wound = boss.get_node("Wound") as Wound
	var fell: Vector2 = boss.global_position
	# The first strike wakes it again; its souls are gone, so its great eye opens.
	wound.hit(1, Vector2.RIGHT)
	for i: int in range(Beast.CORE_HP):
		if not boss.dying():
			wound.hit(1, Vector2.RIGHT)
	check(await until(gone(boss)), "it sinks away")
	await settle()
	check(info.run.bosses.has(&"beast") and placed("beast.tscn").is_empty(), "it dies, slain for the run")
	var relics: Array[Node] = placed("relic.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"beast")
	# Each hit knocks it back a little, so it falls a way from where it stood.
	var where: Vector2 = (info.run.boss_relics.get(&"beast", [null, Vector2.INF]) as Array)[1]
	check(relics.size() == 1 and (relics[0] as Node2D).global_position.distance_to(where) < 1.0 and where.distance_to(fell) < 400.0 and (relics[0] as Relic).price() == 0, "leaving a relic where it fell, free")
	var move: StringName = (relics[0] as Relic).ability
	check(Relics.MOVES.has(move) and Abilities.tier(player, move) == 0, "a move the wizard does not know (%s)" % move)
	var slot: StringName = Abilities.slot_of(move)
	var held: StringName = Abilities.spell(player, slot) if slot != &"" else &""
	var held_tier: int = Abilities.tier(player, held) if held != &"" else 0
	player.keyring.clear()
	(relics[0] as Relic).take()
	# A move that takes a slot puts out what is in it, which comes back as a paper.
	var back: bool = held == &"" or player.keyring.has(KeyRing.paper(held, held_tier))
	check(Abilities.tier(player, move) == 1 and not info.run.boss_relics.has(&"beast") and back, "taken, it teaches it and is gone, handing back what it put out as a paper (%s)" % (held if held != &"" else &"nothing"))
	check(_exit(MapInfo.Exit.DEEPER).sealed() == &"", "its gate level's way on is open")
	await _go(Vector2i(29, g + 2 * b))
	check(placed("beast.tscn").is_empty() and _exit(MapInfo.Exit.DEEPER).sealed() == &"", "and every other gate level of its band too")
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
	await _go(Vector2i(28, g + b))
	check(info.slay_boss() and info.run.bosses.has(&"necromancer") and _exit(MapInfo.Exit.DEEPER).sealed() == &"", "and the necromancer in its gate level")
	await settle()
	check(placed("necromancer.tscn").is_empty() and placed("relic.tscn").any(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"necromancer"), "its relic is left where it stood")
	check(not info.slay_boss(), "with nothing left to slay, it does nothing")

	print("healed from the F7 panel")
	player.health.health = 1
	check(not info.full_heal() and player.health.health == 1, "outside a debug run, Full heal does nothing")
	MapInfo.debug = true
	check(info.full_heal() and player.health.health == player.health.max_health, "in one, it heals the wizard to full")
	MapInfo.debug = false

	print("saved")
	var saved: Dictionary = info.run.to_save(info.coord, {})
	var again: RunState = RunState.new()
	again.from_save(saved)
	check(again.bosses.has(&"beast") and again.bosses.has(&"necromancer") and again.bosses.has(&"worm") and again.bosses.has(&"bramble"), "the bosses slain are kept with the run")
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
