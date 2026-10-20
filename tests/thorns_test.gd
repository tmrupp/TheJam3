extends TestKit
## Thorns that come and go (Spikes, LevelGen.place_thorn_modes): past the start some runs of thorns
## go on a timer and some on a switch, never at a chasm's foot, the same on every build; a switched
## run's switch stands on a floor reached from the way in, away from it, and they share a sigil. In
## play a timed run rises and falls together, hurting only while out; a switched run drops while
## its switch is on and rises again when it is turned off; a hit from thorns puts the wizard back on
## the rock they last stood on, a heart the poorer and untouchable for a moment.
## godot --headless --path . --script res://tests/thorns_test.gd


func run() -> void:
	print("generation")
	var timed: int = 0
	var switched: int = 0
	var runs_seen: int = 0
	var ok_links: bool = true
	var ok_chasms: bool = true
	var ok_start: bool = true
	var same: bool = true
	var places: Array[Vector2i] = []
	for world_seed: int in [28, 7]:
		places.append(Vector2i(world_seed, 0))
		for k: int in range(1, 4):
			places.append(Vector2i(world_seed, NextWorldDef.band_row(&"garden", k)))
		for k: int in range(0, 3):
			places.append(Vector2i(world_seed, NextWorldDef.band_row(&"cemetery", k)))
	for at: Vector2i in places:
		var w: LevelGen = build(at)
		if w == null:
			continue
		var start: Vector2i = w.exits.get(MapInfo.Exit.BACK, Vector2i(-1, -1))
		var reach: Dictionary = w.reach_from(start) if w.is_valid(start) else {}
		var chasm_feet: Dictionary = {}
		for chasm: Dictionary in w.chasms:
			for plank: Vector2i in chasm["planks"]:
				for d: int in range(1, Chasms.CHASM_DEPTH + 3):
					chasm_feet[plank + Vector2i(0, d)] = true
		var again: LevelGen = build(at)
		for x: int in range(w.size.x):
			for y: int in range(w.size.y):
				var v: Vector2i = Vector2i(x, y)
				var cell: LevelGen.Cell = w.get_cell(v)
				if cell.type != LevelGen.Type.SPIKES:
					continue
				same = same and str(cell.extra_info) == str(again.get_cell(v).extra_info)
				if not (cell.extra_info is Dictionary):
					continue
				var how: Dictionary = cell.extra_info
				if Rules.def_for(at).depth < 1:
					ok_start = false
				if chasm_feet.has(v):
					ok_chasms = false
				if how.has("switch"):
					var lever: Vector2i = how["switch"]
					ok_links = ok_links and w.get_cell(lever).type == LevelGen.Type.SWITCH and reach.has(lever) and LevelGen.dist(lever, v) >= 2 							and not w.vaults.any(func(d: Dictionary) -> bool: return (d["room"] as Array).has(lever))
		for run_: Array in w.thorn_runs():
			var first: LevelGen.Cell = w.get_cell(run_[0] as Vector2i)
			runs_seen += 1
			if first.extra_info is Dictionary:
				var how: Dictionary = first.extra_info
				timed += 1 if how.has("timed") else 0
				switched += 1 if how.has("switch") else 0
				if how.has("switch"):
					var lever: Vector2i = how["switch"]
					ok_links = ok_links and w.get_cell(lever).extra_info == run_[0]
				# The whole run goes together.
				for c: Vector2i in run_:
					ok_links = ok_links and str(w.get_cell(c).extra_info) == str(first.extra_info)
	check(timed > 0 and switched > 0, "some runs of thorns go on a timer (%d) and some on a switch (%d), of %d" % [timed, switched, runs_seen])
	check(ok_start, "none at the start")
	check(ok_chasms, "never at a chasm's foot")
	check(ok_links, "a switched run's switch stands on a floor reached from the way in (never in a vault), works the whole run, and the run goes together")
	check(same, "the same on every build")

	print("in play")
	await boot()
	var thorns: Array[Node] = placed("spikes.tscn")
	check(not thorns.is_empty(), "thorns in the level")
	var timer_thorns: Spikes = thorns[0] as Spikes
	timer_thorns.mode = Spikes.Mode.TIMED
	timer_thorns.phase = 0.0
	timer_thorns.set_physics_process(true)
	var went_down: bool = await within(func() -> bool: return not timer_thorns.out, Spikes.CYCLE + 0.2)
	check(went_down, "a timed run goes down")
	await physics_frame
	await physics_frame
	var shape: CollisionShape2D = timer_thorns.get_node("CollisionShape2D") as CollisionShape2D
	check(shape.disabled, "and down it does not hurt")
	var warned: bool = await within(func() -> bool: return timer_thorns.warning() > 0.0, Spikes.CYCLE)
	check(warned, "its tips peek before it rises")
	var came_up: bool = await within(func() -> bool: return timer_thorns.out, Spikes.CYCLE)
	await physics_frame
	await physics_frame
	check(came_up and not shape.disabled, "then it rises and hurts again")
	# A switched run: tied to the level's first switch.
	var levers: Array[Node] = placed("switch.tscn")
	check(not levers.is_empty(), "a switch to tie thorns to")
	var lever: Switch = levers[0] as Switch
	var lever_cell: Vector2i = lever.get_meta(&"cell")
	var switch_thorns: Spikes = thorns[1] as Spikes if thorns.size() > 1 else timer_thorns
	switch_thorns.set_physics_process(true)
	switch_thorns.mode = Spikes.Mode.SWITCHED
	switch_thorns.lever = lever_cell
	if lever.is_on():
		lever.flip()
	await physics_frame
	check(switch_thorns.out, "a switched run is out while its switch is off")
	lever.flip()
	await physics_frame
	await physics_frame
	check(not switch_thorns.out and (switch_thorns.get_node("CollisionShape2D") as CollisionShape2D).disabled, "and drops when it is turned on")
	lever.flip()
	await physics_frame
	await physics_frame
	check(switch_thorns.out, "and rises when it is turned off")

	print("thorns send the wizard back")
	player.set_physics_process(true)
	check(await until(func() -> bool: return player.footing_at == info.coord), "standing on rock, the wizard's footing is kept")
	var foot: Vector2 = player.footing
	var hearts: int = player.health.health
	var bed: Array[Node] = thorns.filter(func(n: Node) -> bool:
		var s: Spikes = n as Spikes
		return n != timer_thorns and n != switch_thorns and s.mode == Spikes.Mode.ALWAYS and s.pit < 0)
	check(not bed.is_empty(), "a run of thorns always out")
	player.end_invulnerable()
	player.velocity = Vector2.ZERO
	player.global_position = (bed[0] as Node2D).to_global(Spikes.BODY)
	check(await within(func() -> bool: return player.global_position.distance_to(foot) < 8.0, 1.0), "touching thorns puts the wizard back on the rock they last stood on")
	check(player.is_invulnerable() and player.health.health == hearts - 1, "a heart the poorer, and untouchable for a moment")
	RunState.delete_save()
	finish()
