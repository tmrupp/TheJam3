extends TestKit
## The bosses' trophies (Trophy, TrophyStand): a boss slain drops its trophy beside its relic, on
## open air; the wizard picks it up by touching it and carries it, kept in the save. The tutorial
## has a stand for each boss in the band layout, each of its own boss; carrying a trophy past its
## stand sets it there. With every boss's trophy set the run is won: the card of a won run shows
## and the save is gone.
## godot --headless --path . --script res://tests/trophy_test.gd


func run() -> void:
	await boot(28)
	var bosses: Array[StringName] = Bands.bosses()
	await _drop(bosses[0])
	await _stands(bosses)
	RunState.delete_save()
	finish()


## The first boss slain in its gate level: its trophy drops beside its relic and is picked up.
func _drop(boss: StringName) -> void:
	print("a boss's trophy")
	await go(lair(boss), false)
	check(info.slay_boss(), "the %s is slain" % boss)
	check(await until(func() -> bool: return info.run.bosses.has(boss)), "for the run")
	check(info.run.boss_trophies.has(boss), "its trophy waits where it fell")
	await settle(5)
	var found: Array[Node] = placed("trophy.tscn")
	check_eq(found.size(), 1, "one trophy there")
	if found.is_empty():
		return
	var trophy: Trophy = found[0] as Trophy
	check_eq(trophy.boss, boss, "the %s's" % boss)
	check(not info.world.is_ground(info.cell_at(trophy.global_position)), "on open air")
	player.set_physics_process(false)
	player.global_position = trophy.global_position
	still()
	check(await until(func() -> bool: return int(info.run.trophies.get(boss, 0)) == Trophy.CARRIED), "picked up by touching it")
	check(not info.run.boss_trophies.has(boss), "and waits there no more")
	check_eq(int((RunState.read_save().get("trophies", {}) as Dictionary).get(boss, 0)), Trophy.CARRIED, "kept in the save")
	player.set_physics_process(true)


## The tutorial's stands, one a boss; the rest of the trophies carried in, set one by one.
func _stands(bosses: Array[StringName]) -> void:
	print("the stands")
	for boss: StringName in bosses:
		info.run.trophies[boss] = Trophy.CARRIED
	await go(Tutorial.of(28), false)
	var stands: Array[Node] = placed("trophy_stand.tscn")
	check_eq(stands.size(), bosses.size(), "a stand for each boss in the layout")
	var held: Array[StringName] = []
	for n: Node in stands:
		held.append((n as TrophyStand).boss)
	held.sort()
	var want: Array[StringName] = bosses.duplicate()
	want.sort()
	check_eq(held, want, "each its own boss's")
	player.set_physics_process(false)
	for i: int in range(stands.size()):
		var stand: TrophyStand = stands[i] as TrophyStand
		player.global_position = stand.global_position
		still()
		check(await until(func() -> bool: return stand.is_set()), "the %s's trophy is set on its stand" % stand.boss)
		if i < stands.size() - 1:
			check(not info.won, "not won while a trophy is still out")
	check(await until(func() -> bool: return info.won and info.run_ending > 0.0), "every trophy set: the run is won")
	check(not FileAccess.file_exists(RunState.save_path), "and its save is gone")
