extends TestKit
## The bosses' trophies (Trophy, TrophyStand): a boss slain drops its trophy beside its relic, on
## open air; the wizard picks it up by touching it and carries it, kept in the save. The tutorial
## has a stand for each boss in the band layout, each of its own boss; carrying a trophy past its
## stand sets it there. With every boss's trophy set the run is won: the card of a won run shows
## and the save is gone; the win is kept past the run (Trophy.won, for the start menu); the card
## holds, however long, until a press made once it has shown MapInfo.WIN_HOLD, and a press brings the
## start menu back. Under a layout other than the whole game's, as a demo build's card, it carries
## the bosses past the garden and its two lines (docs/REVIEW_PLAN.md §5).
## godot --headless --path . --script res://tests/trophy_test.gd


func run() -> void:
	Tutorial.settings_path = "user://trophy_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.settings_path))
	await boot(28)
	var bosses: Array[StringName] = Bands.bosses()
	await _drop(bosses[0])
	await _stands(bosses)
	await _card(bosses)
	RunState.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.settings_path))
	finish()


## The won card: kept up until a press, the win kept for the menu, and in a demo build its lines.
func _card(bosses: Array[StringName]) -> void:
	print("the won card")
	check_eq(Trophy.won(), bosses, "the win is kept past the run, with its trophies, for the start menu")
	var demo: bool = Bands.current != Bands.DEFAULT
	MapInfo.demo_build = demo
	var line: Array[String] = RisoHud.run_line(info.run)
	check(line.size() == 3 and line[0].contains(":"), "the run in a line: its time (%s), lanterns burned (%s), levels visited (%s)" % line)
	if demo:
		check(not RisoHud.beyond().is_empty() and RisoHud.beyond().all(func(b: StringName) -> bool: return not bosses.has(b)), "a demo's card shows the bosses past its garden (%s)" % [RisoHud.beyond()])
		check(RisoHud.DEMO_END.contains("end of the demo"), "and says plainly the demo ends here")
	var press: InputEventKey = InputEventKey.new()
	press.keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	await frames(2)
	check(info.won and info.run_ending > 0.0, "a press made at once does not skip the card")
	await within(func() -> bool: return false, 8.0)
	check(is_instance_valid(info) and info.won and info.run_ending > 0.0, "the card is still up %.1f s on, past the old six" % info.won_for)
	var old: Node = main
	Input.parse_input_event(press)
	check(await until(gone(old)), "a press then brings the start menu back")
	MapInfo.demo_build = false


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
	freeze()
	player.global_position = trophy.global_position
	still()
	check(await until(func() -> bool: return int(info.run.trophies.get(boss, 0)) == Trophy.CARRIED), "picked up by touching it")
	check(not info.run.boss_trophies.has(boss), "and waits there no more")
	# The save is written as the frame is processed (MapInfo.save_run).
	await frames(2)
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
	freeze()
	for i: int in range(stands.size()):
		var stand: TrophyStand = stands[i] as TrophyStand
		player.global_position = stand.global_position
		still()
		check(await until(func() -> bool: return stand.is_set()), "the %s's trophy is set on its stand" % stand.boss)
		if i < stands.size() - 1:
			check(not info.won, "not won while a trophy is still out")
	check(await until(func() -> bool: return info.won and info.run_ending > 0.0), "every trophy set: the run is won")
	check(not SafeFile.exists(RunState.save_path), "and its save is gone")
