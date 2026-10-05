extends SceneTree
## Switch gates (every level has one; its switch is reachable with the gate shut; throwing it, by
## hand or with a hex bolt, opens the gate for good), the rare big jump (never at depth 0, about
## PLUNGE_CHANCE % of levels deeper; drops PLUNGE_DEPTH levels for its price) and the parry
## (wounds and stuns what it catches, reflects shots, refunds the dash).
## godot --headless --path . --script res://tests/switches_test.gd

var main: Node
var info: MapInfo
var player: Player
var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func settle(frames: int = 6) -> void:
	await process_frame
	var deadline: int = Time.get_ticks_msec() + 30000
	while (info.world == null or info.travelling) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(frames):
		await physics_frame
		await process_frame


func placed(scene: String) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == scene and not node.is_queued_for_deletion():
			found.append(node)
	return found


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://switches_test.save"
	await process_frame
	var wfc: Node = main.get_node("WaveFunctionCollapse")

	print("generation")
	var gates_ok: bool = true
	var reach_ok: bool = true
	var levels: int = 0
	for world_seed: int in [1, 7, 28, 99]:
		# Garden levels: a cemetery's open terraces and the sky's islands have hardly any corridors
		# for gates.
		for depth: int in [0, 1, NextWorldDef.BAND - 1]:
			var def: NextWorldDef = MapInfo.def_for(Vector2i(world_seed, depth))
			var w: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def), def)
			levels += 1
			var pairs: int = 0
			for v: Vector2i in w.objects:
				if w.get_cell(v).type != MapInfo.Type.SWITCH_GATE:
					continue
				pairs += 1
				var lever: Vector2i = w.get_cell(v).extra_info
				if w.get_cell(lever).type != MapInfo.Type.SWITCH or w.get_cell(lever).extra_info != v:
					gates_ok = false
				# The switch is reachable from the way in with its gate shut.
				var start: Vector2i = w.exits[MapInfo.Exit.BACK]
				var seen: Dictionary = {start: true}
				var queue: Array[Vector2i] = [start]
				while not queue.is_empty():
					var c: Vector2i = queue.pop_back()
					for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var n: Vector2i = c + d
						if n != v and w.is_valid(n) and w.get_cell(n).type != MapInfo.Type.GROUND and w.get_cell(n).type != MapInfo.Type.CRACKED and not seen.has(n):
							seen[n] = true
							queue.append(n)
				if not seen.has(lever):
					reach_ok = false
			if pairs < 1:
				gates_ok = false
	check(gates_ok, "every one of %d levels has a switch gate, paired both ways with its switch" % levels)
	check(reach_ok, "every switch is reachable from the way in with its gate shut")
	var plunges: int = 0
	var surface: int = 0
	var tried: int = 0
	var plunge_seed: int = -1
	for world_seed: int in range(1, 120):
		for depth: int in [0, 1]:
			var def: NextWorldDef = MapInfo.def_for(Vector2i(world_seed, depth))
			var deals: bool = MapInfo.level_seed(def.gen_seed, 777) % 100 < Hyperspace.CHANCE
			if depth == 0 and deals:
				surface += 1
			if depth == 1:
				tried += 1
				if deals:
					plunges += 1
					if plunge_seed < 0:
						plunge_seed = world_seed
	check(plunges > tried / 10 and plunges < tried / 3, "the hyperspace door is rare: dealt in %d of %d depth-1 levels" % [plunges, tried])
	var dw: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", MapInfo.def_for(Vector2i(plunge_seed, 1))), MapInfo.def_for(Vector2i(plunge_seed, 1)))
	var d0: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", MapInfo.def_for(Vector2i(plunge_seed, 0))), MapInfo.def_for(Vector2i(plunge_seed, 0)))
	check(dw.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1)).x >= 0 and dw.get_cell(dw.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1))).type == MapInfo.Type.EXIT and int(dw.get_cell(dw.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1))).extra_info) == Worlds.door(Worlds.kind_of(Hyperspace)) and d0.exits.get(Worlds.door(Worlds.kind_of(Hyperspace)), Vector2i(-1, -1)).x < 0, "a dealt level has its hyperspace door; depth 0 never does")
	check(Worlds.proto(Worlds.kind_of(Hyperspace)).entry_price(3) == roundi(MapInfo.deeper_price(3) * Hyperspace.PRICE), "it costs %d at depth 3 (the deeper exit costs %d)" % [Worlds.proto(Worlds.kind_of(Hyperspace)).entry_price(3), MapInfo.deeper_price(3)])

	print("switches in play")
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = str(plunge_seed)
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()
	player.set_physics_process(false)
	var switches: Array[Node] = placed("switch.tscn")
	var gates: Array[Node] = placed("switch_gate.tscn")
	check(not switches.is_empty() and gates.size() == switches.size(), "the level holds %d switch and gate" % switches.size())
	var lever: Node = switches[0]
	var gate: Node = null
	for g: Node in gates:
		if g.get_meta(&"cell") == lever.get("gate_cell"):
			gate = g
	check(gate != null and not bool(lever.call("thrown")), "the switch knows its gate, and starts unthrown")
	lever.call("flip")
	await process_frame
	check(bool(lever.call("thrown")) and (not is_instance_valid(gate) or gate.is_queued_for_deletion()), "throwing it lifts the gate")
	var gate_cell: Vector2i = lever.get("gate_cell")
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	player.set_physics_process(false)
	check(not placed("switch_gate.tscn").any(func(n: Node) -> bool: return n.get_meta(&"cell") == gate_cell), "a revisit keeps the gate open")
	check(placed("switch.tscn").any(func(n: Node) -> bool: return bool(n.call("thrown"))), "and the switch thrown")
	# A hex bolt throws a switch too.
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	player.set_physics_process(false)
	var other: Node2D = placed("switch.tscn")[0] as Node2D
	var bolt: Node2D = Node2D.new()
	bolt.set_script(preload("res://scripts/HexBolt.gd"))
	bolt.set("dir", Vector2.RIGHT)
	info.map_elements.add_child(bolt)
	bolt.global_position = other.global_position + Vector2(-120, -20)
	for i: int in range(10):
		await physics_frame
	check(bool(other.call("thrown")), "a hex bolt throws a switch")

	print("the hyperspace door")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
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
	check(info.coord == (MapInfo.def_for(Worlds.side_at(Worlds.kind_of(Hyperspace), Vector2i(plunge_seed, 1))) as SideWorld).destination() and info.deepest == 1 + Hyperspace.DROP, "its gate drops %d levels at once, to depth %d" % [Hyperspace.DROP, info.coord.y])
	check(player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.BACK])) < 80.0, "arriving by that level's way back")

	print("parry")
	Abilities.set_tier(player, &"parry", 1)
	var wisp: Node2D = placed("mover_enemy.tscn")[0] as Node2D
	wisp.get_node("Wound").set("hp", 3)
	player.dash.acted = true
	player.parry.emit()
	player.hurt(-1, Vector2.RIGHT * 100.0, wisp.get_node("HitBox/Damager"))
	check(int(wisp.get_node("Wound").get("hp")) == 2 and bool(wisp.get_node("Mover").get("stunned")), "a parried wisp is wounded (3 -> 2 hp) and stunned")
	check(not player.dash.acted and player.health.health == player.health.max_health, "the parry refunds the dash and takes no damage")
	await create_timer(0.3, true, false, true).timeout
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
	Abilities.set_tier(player, &"parry", 4)
	var p: Node = player.get_node("Parry")
	check(is_equal_approx(float(p.get("duration")), 0.45) and int(p.get("damage")) == 2 and bool(p.get("heals")), "parry IV: a longer guard, 2 damage, and it heals")

	Engine.time_scale = 1.0
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: switches, hyperspace door, parry")
		quit()
