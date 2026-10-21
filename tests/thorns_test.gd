extends TestKit
## Thorns that come and go (Spikes, LevelGen.place_thorn_modes): past the start some runs of thorns
## go on a timer and some on a switch, never at a chasm's foot, the same on every build; a switched
## run's switch stands on a floor reached from the way in, away from it, and they share a sigil. In
## play a timed run rises and falls together, hurting only while out; a switched run drops while
## its switch is on and rises again when it is turned off; a hit from thorns puts the wizard back on
## the rock they last stood on, a heart the poorer, held still for a moment (the stick does nothing,
## the untouchable time waits) and then free to run. A floating ledge stood on since counts too: sent
## back, they are put on a lift where they stood on it, wherever it has moved to, and with the lift
## gone, back on the rock.
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
	check(await within(func() -> bool: return player.held > 0.0, 1.0), "touching thorns strikes the wizard")
	var struck_at: Vector2 = player.global_position
	check(not player.visible and struck_at.distance_to(foot) > 8.0, "and they are gone from where they were struck")
	check(player.is_invulnerable() and player.health.health == hearts - 1, "a heart the poorer, and untouchable for a moment")
	var safe_left: float = player.invulnerable.acting
	var view: Camera2D = Stage.camera()
	var view_at: Vector2 = view.position if view != null else Vector2.ZERO
	Input.action_press("Right")
	await within(func() -> bool: return false, Player.THORN_PAUSE * 0.5)
	check(not player.visible and player.global_position == struck_at, "while gone, nothing moves them, the stick neither")
	check(view == null or view.position.is_equal_approx(view_at), "and the view holds still")
	check(await within(func() -> bool: return player.held <= 0.0, Player.THORN_PAUSE), "%.1f s on" % Player.THORN_PAUSE)
	check(player.visible and player.global_position.distance_to(foot) < 8.0, "they appear back on the rock they last stood on")
	check(view == null or view.position.is_equal_approx(player.position), "the view cut to them")
	check(is_equal_approx(player.invulnerable.acting, safe_left), "and the hit's untouchable time is all still to come")
	check(await within(func() -> bool: return player.global_position.x > foot.x + 16.0, 0.5), "then they can run again")
	Input.action_release("Right")

	print("floating ledges count as footing")
	var plain: Node = (load("res://prefabs/platform.tscn") as PackedScene).instantiate()
	var cloud: Node = (load("res://prefabs/puff.tscn") as PackedScene).instantiate()
	check(player._floats(plain) and not player._floats(cloud), "a platform is footing, a cloud that gives way is not")
	plain.free()
	cloud.free()
	# A lift (parked, so the test moves it) in open air with room round it.
	var cell: float = float(info.tile_map.tile_set.tile_size.x) * info.tile_map.global_scale.x
	var home: Vector2i = Vector2i(-1, -1)
	for v: Vector2i in info.world.empties:
		var room: bool = true
		for x: int in range(0, 3):
			for y: int in range(-3, 1):
				var c: Vector2i = v + Vector2i(x, y)
				room = room and info.world.is_valid(c) and info.world.get_cell(c).type != LevelGen.Type.SPIKES and not info.solid_at(info.cell_position(c))
		if room:
			home = v
			break
	check(home != Vector2i(-1, -1), "open air for a lift")
	var lift: MovingPlatform = (load("res://prefabs/moving_platform.tscn") as PackedScene).instantiate() as MovingPlatform
	lift.set_meta(&"cell", home)
	info.map_elements.add_child(lift)
	lift.setup(info, home, [1, Vector2i(1, 0), 1])
	lift.halt()
	await physics_frame
	# Untouchable throughout, so nothing else knocks them off.
	player.invulnerable.acting = 60.0
	player.velocity = Vector2.ZERO
	player.global_position = lift.global_position + Vector2(0.0, -cell)
	check(await until(func() -> bool: return player.is_on_floor() and player.perch == lift), "standing on a lift, it is kept as footing")
	var rock: Vector2 = player.footing
	var off: Vector2 = player.perch_off
	var was: Vector2 = player.global_position
	# Off it and struck, and the lift moves on a cell while the wizard is gone.
	player.global_position += Vector2(0.0, -cell * 1.5)
	player.thorn_back()
	lift._held += Vector2(cell, 0.0)
	lift._place(lift._held)
	check(await within(func() -> bool: return player.held <= 0.0, Player.THORN_PAUSE + 0.2), "gone a moment")
	check(player.global_position.distance_to(lift.global_position + off) < 4.0 and player.global_position.distance_to(was) > cell * 0.9, "they appear on the lift where they stood on it, wherever it has gone meanwhile")
	check(await within(func() -> bool: return player.is_on_floor(), 0.3) and player.perch == lift, "and stand on it")
	player.global_position += Vector2(0.0, -cell * 1.5)
	lift.free()
	player.thorn_back()
	await within(func() -> bool: return player.held <= 0.0, Player.THORN_PAUSE + 0.2)
	check(player.global_position.distance_to(rock) < 1.0, "with the lift gone, back on the last rock instead")
	RunState.delete_save()
	finish()
