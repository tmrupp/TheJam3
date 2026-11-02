extends TestKit
## Switch gates (every level has one; its switch is reachable with the gate shut and stands well
## away from it; some switches start on; turning it on lifts the gate and off drops it again, never on the
## wizard; a hex bolt turns one on but never off; the record keeps each as it was left), the rare
## big jump (never at depth 0, about
## PLUNGE_CHANCE % of levels deeper; drops PLUNGE_DEPTH levels for its price) and the parry that
## every damage spell raises (wounds and stuns what it catches, reflects shots, refunds the dash;
## none with no damage spell held).
## godot --headless --path . --script res://tests/switches_test.gd


func run() -> void:
	print("generation")
	var gates_ok: bool = true
	var reach_ok: bool = true
	var levels: int = 0
	var near: int = 0
	var switch_pairs: int = 0
	var far_ok: bool = true
	var all_switches: int = 0
	var start_on: int = 0
	for world_seed: int in [1, 7, 28, 99]:
		# Garden levels: a cemetery's open terraces and the sky's islands have hardly any corridors
		# for gates.
		for depth: int in [0, 1, Bands.garden_rows(), -Bands.garden_rows()]:
			var def: NextWorldDef = Rules.def_for(Vector2i(world_seed, depth))
			var w: LevelGen = LevelGen.new(collapse(def.coord), def)
			levels += 1
			var pairs: int = 0
			for v: Vector2i in w.objects:
				if w.get_cell(v).type != LevelGen.Type.SWITCH_GATE:
					continue
				pairs += 1
				switch_pairs += 1
				var lever: Vector2i = w.get_cell(v).extra_info
				if w.get_cell(lever).type != LevelGen.Type.SWITCH or w.get_cell(lever).extra_info != v:
					gates_ok = false
				# The switch is reachable from the way in with its gate shut.
				var start: Vector2i = w.exits[MapInfo.Exit.BACK]
				var seen: Dictionary = {start: true}
				var queue: Array[Vector2i] = [start]
				while not queue.is_empty():
					var c: Vector2i = queue.pop_back()
					for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var n: Vector2i = c + d
						if n != v and w.is_valid(n) and w.get_cell(n).type != LevelGen.Type.GROUND and w.get_cell(n).type != LevelGen.Type.CRACKED and not seen.has(n):
							seen[n] = true
							queue.append(n)
				if not seen.has(lever):
					reach_ok = false
				var apart: int = LevelGen.dist(lever, v)
				near += 1 if apart >= LevelGen.SWITCH_MIN else 0
				far_ok = far_ok and apart >= 2
			for v: Vector2i in w.objects:
				if w.get_cell(v).type == LevelGen.Type.SWITCH:
					all_switches += 1
					start_on += 1 if Switch.starts_on(w, v) else 0
			# A gate level's big thing (the bramble's shaft) is cut first, and in a small level may
			# leave no corridor for a gate: there one is not owed.
			if pairs < 1 and w.shaft.is_empty():
				gates_ok = false
			elif pairs < 1:
				print("  (%s: no switch gate beside the bramble's shaft)" % def.coord)
	check(gates_ok, "every one of %d levels has a switch gate (but a shaft level with no room), paired both ways with its switch" % levels)
	check(reach_ok, "every switch is reachable from the way in with its gate shut")
	check(far_ok and near * 10 >= switch_pairs * 9, "switches stand well away from their gates (%d of %d at least %d cells off, none right beside one)" % [near, switch_pairs, LevelGen.SWITCH_MIN])
	check(start_on * 100 > all_switches * 15 and start_on * 100 < all_switches * 55, "some switches start on (%d of %d)" % [start_on, all_switches])
	var plunges: int = 0
	var surface: int = 0
	var tried: int = 0
	var plunge_seed: int = -1
	for world_seed: int in range(1, 120):
		for depth: int in [0, 1]:
			var def: NextWorldDef = Rules.def_for(Vector2i(world_seed, depth))
			var deals: bool = Rules.level_seed(def.gen_seed, 777) % 100 < Hyperspace.CHANCE
			if depth == 0 and deals:
				surface += 1
			if depth == 1:
				tried += 1
				if deals:
					plunges += 1
					if plunge_seed < 0:
						plunge_seed = world_seed
	check(plunges > tried / 10 and plunges < tried / 3, "the hyperspace door is rare: dealt in %d of %d depth-1 levels" % [plunges, tried])
	var dw: LevelGen = LevelGen.new(collapse(Vector2i(plunge_seed, 1)), Rules.def_for(Vector2i(plunge_seed, 1)))
	var d0: LevelGen = LevelGen.new(collapse(Vector2i(plunge_seed, 0)), Rules.def_for(Vector2i(plunge_seed, 0)))
	check(dw.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1)).x >= 0 and dw.get_cell(dw.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1))).type == LevelGen.Type.EXIT and int(dw.get_cell(dw.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1))).extra_info) == Worlds.door(Worlds.kind_of(Hyperspace)) and d0.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1)).x < 0, "a dealt level has its hyperspace door; depth 0 never does")
	check(Worlds.proto(Worlds.kind_of(Hyperspace)).entry_price(3) == roundi(Rules.deeper_price(3) * Hyperspace.PRICE), "it costs %d at depth 3 (the deeper exit costs %d)" % [Worlds.proto(Worlds.kind_of(Hyperspace)).entry_price(3), Rules.deeper_price(3)])

	print("switches in play")
	await boot(plunge_seed)
	player.set_physics_process(false)
	# The garden's gates are what gate_test is for: here they are passed, so its hyperspace opens.
	info.run.bosses[Bosses.gate_at(Bands.garden_rows())] = true
	info.run.bosses[Bosses.gate_at(-Bands.garden_rows())] = true
	# The switches that work a gate (a lift or thorns may have one too).
	var switches: Array[Node] = placed("switch.tscn").filter(func(n: Node) -> bool: return info.world.get_cell((n as Switch).gate_cell).type == LevelGen.Type.SWITCH_GATE)
	var gates: Array[Node] = placed("switch_gate.tscn")
	check(not switches.is_empty() and gates.size() == switches.size(), "the level holds %d switch and gate" % switches.size())
	var lever: Switch = switches[0] as Switch
	var gate: SwitchGate = null
	for g: Node in gates:
		if g.get_meta(&"cell") == lever.gate_cell:
			gate = g as SwitchGate
	check(gate != null and gate.shut() == not lever.is_on(), "the switch knows its gate, which stands as the switch is (down while off)")
	if lever.is_on():
		lever.flip()
	await frames(3)
	check(not lever.is_on() and gate.shut(), "off, its gate is down")
	lever.flip()
	await frames(3)
	check(lever.is_on() and not gate.shut(), "turned on, it lifts the gate")
	var gate_cell: Vector2i = lever.gate_cell
	var lever_cell: Vector2i = lever.get_meta(&"cell")
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	player.set_physics_process(false)
	var back: Array[Node] = placed("switch_gate.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"cell") == gate_cell)
	check(back.size() == 1 and not (back[0] as SwitchGate).shut() and info.switch_on(lever_cell), "a revisit keeps the switch on and the gate up")
	gate = back[0] as SwitchGate
	lever = placed("switch.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"cell") == lever_cell)[0] as Switch
	# Off with the wizard in its way: it waits until they are clear.
	player.global_position = gate.global_position
	lever.flip()
	await frames(5)
	check(not lever.is_on() and not gate.shut(), "turned off with the wizard under it, the gate waits")
	player.global_position = info.cell_position(lever_cell)
	await frames(5)
	check(gate.shut(), "and drops once they are clear")
	await until(func() -> bool: return gate.lift <= 0.0, 3000)
	check(gate.lift == 0.0, "winched all the way down")
	# A hex bolt turns a switch on, never off.
	var other: Switch = lever
	var fire: Callable = func() -> void:
		var bolt: Node2D = Node2D.new()
		bolt.set_script(preload("res://scripts/HexBolt.gd"))
		bolt.set("dir", Vector2.RIGHT)
		info.map_elements.add_child(bolt)
		# Fired from just beside it, so no rock the level happens to put nearby is in the way.
		bolt.global_position = other.global_position + Vector2(-40, -20)
	fire.call()
	await until(func() -> bool: return other.is_on())
	check(other.is_on(), "a hex bolt turns a switch on")
	await frames(10)
	fire.call()
	await frames(10)
	check(other.is_on(), "but never off")

	print("the hyperspace door")
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	player.set_physics_process(false)
	var jump: Array[Node] = placed("level_exit.tscn").filter(func(n: Node) -> bool: return int(n.get("exit")) == Worlds.door(Worlds.kind_of(Hyperspace)))
	check(info.coord == Vector2i(plunge_seed, 1) and jump.size() == 1, "the dealt level shows its hyperspace door")
	var owed: int = int(jump[0].call("price"))
	check(owed == Worlds.proto(Worlds.kind_of(Hyperspace)).entry_price(1), "it asks %d stars" % owed)
	player.collect(owed - player.coins.coins)
	jump[0].call("interacted")
	await settle()
	player.set_physics_process(false)
	check(info.coord == Worlds.side_at(Worlds.kind_of(Hyperspace), Vector2i(plunge_seed, 1)) and Worlds.is_side(info.coord), "paying enters hyperspace, the door's own world")
	check(player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.BACK])) < 80.0 and player.coins.coins == 0, "arriving by its way back, the stars spent")
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	player.set_physics_process(false)
	check(info.coord == (Rules.def_for(Worlds.side_at(Worlds.kind_of(Hyperspace), Vector2i(plunge_seed, 1))) as SideWorld).destination() and info.run.deepest == 1 + Hyperspace.DROP, "its gate drops %d levels at once, to depth %d" % [Hyperspace.DROP, info.coord.y])
	check(player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.BACK])) < 80.0, "arriving by that level's way back")

	print("parry")
	var wisp: Node2D = placed("mover_enemy.tscn")[0] as Node2D
	wisp.get_node("Wound").set("hp", 3)
	player.dash.acted = true
	var guard: Parry = player.get_node("Parry") as Parry
	player.parry.emit()
	check(guard.guard_left() > 0.9, "raising the guard shows it, full")
	player.hurt(-1, Vector2.RIGHT * 100.0, wisp.get_node("HitBox/Damager"))
	check(int(wisp.get_node("Wound").get("hp")) == 2 and bool(wisp.get_node("Mover").get("stunned")), "a parried wisp is wounded (3 -> 2 hp) and stunned")
	check(guard.guard_left() < 0.0 and guard.glory(), "a catch drops the guard and the wizard shimmers gold, not hurt pink")
	check(player.knock == Vector2.ZERO, "a catch never pushes the wizard away from the enemy (a blow that lands does, SpellStrike.recoil)")
	check(player.invulnerable.acting <= Parry.SAFE + 0.001, "and keeps them untouchable only briefly")
	check(guard.missed_at < guard.parried_at, "a catch is not a miss")
	check(not player.dash.acted and player.health.health == player.health.max_health, "the parry refunds the dash and takes no damage")
	await until(func() -> bool: return is_equal_approx(Engine.time_scale, 1.0), 2000)
	check(is_equal_approx(Engine.time_scale, 1.0), "the hit-stop passes")
	var shooter: Node2D = placed("shooter_enemy.tscn")[0] as Node2D
	var shot: Node2D = load("res://prefabs/bullet.tscn").instantiate()
	main.add_child(shot)
	shot.global_position = player.global_position + Vector2(40, -20)
	shot.call("setup", Vector2(-100, 0), [shooter], shooter)
	await process_frame
	var bolts_before: int = info.map_elements.get_children().filter(func(n: Node) -> bool: return n.get_script() == preload("res://scripts/HexBolt.gd")).size()
	player.end_invulnerable()
	player.parry.emit()
	player.hurt(-1, Vector2.RIGHT * 100.0, shot.get_node("HitBox/Damager"))
	var bolts_after: int = info.map_elements.get_children().filter(func(n: Node) -> bool: return n.get_script() == preload("res://scripts/HexBolt.gd")).size()
	check(shot.is_queued_for_deletion() and bolts_after == bolts_before + 1, "a parried shot is reflected as a bolt at its shooter")
	player.end_invulnerable()
	await within(func() -> bool: return not guard.cooldown.acted, Parry.COOLDOWN + 1.0)
	player.parry.emit()
	await until(func() -> bool: return guard.guard_left() < 0.0, 2000)
	check(not guard.glory() and guard.missed_at > guard.parried_at, "a guard that catches nothing closes as a miss")
	# Thorns underfoot: a hazard, caught all the same, bounces the wizard up (a pogo).
	var thorns: Node = placed("spikes.tscn")[0] if not placed("spikes.tscn").is_empty() else null
	if thorns != null:
		player.end_invulnerable()
		await within(func() -> bool: return not guard.cooldown.acted, Parry.COOLDOWN + 1.0)
		var hp: int = player.health.health
		player.parry.emit()
		player.hurt(-1, Vector2.UP * 400.0, thorns.get_node("Damager"))
		check(player.health.health == hp and is_equal_approx(player.velocity.y, Parry.POGO), "a parry on thorns underfoot bounces the wizard up, unhurt")
	# No guard while untouchable from a hit taken; a parry's own untouchable moment still allows one.
	player.end_invulnerable()
	await within(func() -> bool: return not guard.cooldown.acted, Parry.COOLDOWN + 1.0)
	player.hurt(-1, Vector2.RIGHT * 100.0, wisp.get_node("HitBox/Damager"))
	check(player.invulnerable.is_acting() and guard.hurt_guarded() and guard.readiness() == 0.0, "hurt, the wizard is untouchable and the parry reads not ready (untouchable %s, gold %s, guard left %.2f, readiness %.2f)" % [player.invulnerable.is_acting(), guard.glory(), guard.guard_left(), guard.readiness()])
	player.parry.emit()
	check(guard.guard_left() < 0.0 and not guard.cooldown.acted, "and no guard can be raised, and the cooldown is not spent")
	player.end_invulnerable()
	player.parry.emit()
	check(guard.guard_left() > 0.0, "once that ends, the guard rises again")
	player.hurt(-1, Vector2.RIGHT * 100.0, wisp.get_node("HitBox/Damager"))
	Engine.time_scale = 1.0
	check(guard.glory() and not guard.hurt_guarded() and guard.readiness() == 1.0, "after a catch, its own untouchable moment still allows the next guard")
	player.parry.emit()
	# Landing on an enemy with the guard up: caught, but no bounce (a slash down is what bounces,
	# parry_landing_test).
	player.knock = Vector2.ZERO
	player.knock_back.end()
	player.velocity = Vector2(250.0, 650.0)
	player.hurt(-1, Vector2.UP * 400.0, wisp.get_node("HitBox/Damager"))
	Engine.time_scale = 1.0
	check(is_equal_approx(player.velocity.y, 650.0) and is_equal_approx(player.velocity.x, 250.0), "parrying an enemy landed on leaves the wizard's motion alone")
	check(player.knock == Vector2.ZERO and not player.knock_back.is_acting(), "with control kept")
	player.end_invulnerable()
	# Every damage spell parries; with none held there is nothing to parry with.
	await until(func() -> bool: return guard.guard_left() < 0.0 and not guard.cooldown.acted, 3000)
	Abilities.set_tier(player, &"hex", 1)
	player.parry.emit()
	check(guard.guard_left() > 0.0, "hex raises the guard as slash does")
	await until(func() -> bool: return guard.guard_left() < 0.0 and not guard.cooldown.acted, 3000)
	Abilities.set_tier(player, &"hex", 0)
	player.parry.emit()
	check(guard.guard_left() < 0.0, "with no damage spell held, no guard rises")
	Abilities.set_tier(player, &"slash", 1)

	Engine.time_scale = 1.0
	finish()
