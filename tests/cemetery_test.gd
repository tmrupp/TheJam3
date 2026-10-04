extends SceneTree
## The cemetery archetype (docs/DEEPER_PLAN.md, group 3): bands of depths, its own terrain sample
## (collapsed with no symmetry), realm and decor, its gates (chasms bridged once their bell is
## rung), and what lives there: moths drawn to a lit lantern and scattered by a hex, sleep fog that
## switches the spell off, and wraiths that drift through rock at the wizard.
## godot --headless --path . --script res://tests/cemetery_test.gd

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


func settle(frames: int = 4) -> void:
	await process_frame
	var deadline: int = Time.get_ticks_msec() + 30000
	while (info.world == null or info.travelling or info.run_ending > 0.0) and Time.get_ticks_msec() < deadline:
		await process_frame
	for i: int in range(frames):
		await physics_frame
		await process_frame


func placed(file: String) -> Array[Node]:
	var found: Array[Node] = []
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == file and not n.is_queued_for_deletion():
			found.append(n)
	return found


func count(w: MapInfo.World, type: MapInfo.Type) -> int:
	var n: int = 0
	for column: Array in w.cells:
		for cell: MapInfo.Cell in column:
			if cell.type == type:
				n += 1
	return n


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://cemetery_test.save"
	await process_frame
	bands()
	generation(main.get_node("WaveFunctionCollapse"))

	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	await process_frame
	await process_frame
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()
	info.coord = Vector2i(28, 3)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	print("in a cemetery")
	check(info.here.cemetery() and MapInfo.where(info.coord) == "world 28 · depth 3 · cemetery", "world 28 depth 3 is a cemetery, and says so")
	if RisoPrint.instance != null:
		check(RisoPrint.instance.realm == &"cemetery", "printed in the cemetery's realm")

	await bridges()
	await fog()
	await moths()
	await wraiths()

	MapInfo.delete_save()
	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: the cemetery")
		quit()


func bands() -> void:
	print("archetypes by depth")
	var kinds: Array[StringName] = []
	for d: int in range(9):
		kinds.append(NextWorldDef.archetype_at(d))
	check(kinds == [&"garden", &"garden", &"garden", &"cemetery", &"cemetery", &"cemetery", &"garden", &"garden", &"garden"], "garden, then cemetery, a band of %d each: %s" % [NextWorldDef.BAND, kinds])
	var def: NextWorldDef = MapInfo.def_for(Vector2i(28, 4))
	check(def.region == NextWorldDef.GRAVEYARD and def.symmetry == 1 and def.realm() == &"cemetery", "a cemetery collapses the graveyard sample, unturned, and prints in its realm")
	var garden: NextWorldDef = MapInfo.def_for(Vector2i(28, 1))
	check(garden.region != NextWorldDef.GRAVEYARD and garden.realm() == &"" and not garden.title().contains("cemetery"), "a garden level is as before")
	check(MapInfo.region_for(0) != MapInfo.region_for(6), "garden bands still alternate tunnels and islands")
	var side: NextWorldDef = MapInfo.def_for(Worlds.side_at(0, Vector2i(28, 4)))
	check(not side.cemetery(), "a side world under a cemetery is not one")


func generation(wfc: Node) -> void:
	print("generation")
	for at: Vector2i in [Vector2i(1, 3), Vector2i(7, 4), Vector2i(28, 5), Vector2i(99, 3)]:
		var def: NextWorldDef = MapInfo.def_for(at)
		var cells: Array = wfc.call("generate_level", def)
		check(not cells.is_empty(), "%s collapses" % at)
		if cells.is_empty():
			continue
		var w: MapInfo.World = MapInfo.World.new(cells, def)
		var again: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def), def)
		check(w.objects == again.objects, "%s: the same every time" % at)
		var lanterns: int = count(w, MapInfo.Type.CHECKPOINT)
		check(count(w, MapInfo.Type.MOTHS) >= mini(lanterns, 1) and count(w, MapInfo.Type.FOG) >= 1 and count(w, MapInfo.Type.WRAITH) >= 1,
			"%s: moths (%d), fog (%d) and wraiths (%d)" % [at, count(w, MapInfo.Type.MOTHS), count(w, MapInfo.Type.FOG), count(w, MapInfo.Type.WRAITH)])
		var solid: Dictionary = {}
		for v: Vector2i in w.grounds:
			solid[v] = true
		var kinds: Dictionary = {}
		for item: Dictionary in RisoDecor.plan(solid, {}, def.gen_seed, Rect2i(Vector2i.ZERO, w.size), def.archetype):
			kinds[item["kind"]] = true
		check(kinds.has(&"headstone") and not kinds.has(&"mushroom"), "%s: graveyard decor (%s)" % [at, kinds.keys()])
		check(not w.chasms.is_empty(), "%s: %d chasms" % [at, w.chasms.size()])
		for id: int in range(w.chasms.size()):
			var chasm: Dictionary = w.chasms[id]
			var planks: Array = chasm["planks"]
			var row: int = chasm["row"]
			var shaped: bool = planks.size() >= MapInfo.World.CHASM_WIDTH.x and planks.size() <= MapInfo.World.CHASM_WIDTH.y
			for v: Vector2i in planks:
				shaped = shaped and w.get_cell(v).type == MapInfo.Type.BRIDGE and int(w.get_cell(v).extra_info) == id
				for d: int in range(-MapInfo.World.CHASM_CLEAR, MapInfo.World.CHASM_DEPTH):
					# Open, and nothing placed in it (no ledge, lift or moon to cross on).
					var c: Vector2i = v + Vector2i(0, d)
					shaped = shaped and (d == 0 or not w.is_valid(c) or w.get_cell(c).type in [MapInfo.Type.EMPTY, MapInfo.Type.GROUND])
				shaped = shaped and w.get_cell(v + Vector2i(0, MapInfo.World.CHASM_DEPTH)).type == MapInfo.Type.SPIKES
			shaped = shaped and w.is_ground((chasm["left"] as Vector2i) + Vector2i.DOWN) and w.is_ground((chasm["right"] as Vector2i) + Vector2i.DOWN)
			check(shaped, "%s: chasm %d is %d across between floors, thorns at its bottom, planks over it" % [at, id, planks.size()])
			var bells: int = 0
			for v: Vector2i in w.objects:
				if w.get_cell(v).type == MapInfo.Type.BELL and int(w.get_cell(v).extra_info) == id:
					bells += 1
					check(v.y == row and w.ground_below(v), "%s: its bell stands on the floor beside it" % at)
			check(bells == 1, "%s: chasm %d has one bell" % [at, id])
	var garden_def: NextWorldDef = MapInfo.def_for(Vector2i(28, 1))
	var garden: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", garden_def), garden_def)
	check(count(garden, MapInfo.Type.MOTHS) + count(garden, MapInfo.Type.FOG) + count(garden, MapInfo.Type.WRAITH) == 0, "none of it in the garden")


func bridges() -> void:
	print("bells and bridges")
	var bells: Array[Node] = placed("bell.tscn")
	check(not bells.is_empty(), "a bell in the level")
	var bell: Node = bells[0]
	var id: int = int(bell.get("chasm"))
	var planks: Array[Node] = placed("bridge.tscn").filter(func(n: Node) -> bool: return int(n.get("chasm")) == id)
	check(not planks.is_empty() and planks.all(func(n: Node) -> bool: return not bool(n.call("up")) and bool((n.get_node("CollisionShape2D") as CollisionShape2D).disabled)), "before the bell is rung, nothing stands over the chasm")
	# Stand the wizard over the chasm: they fall.
	var over: Vector2 = (planks[planks.size() / 2] as Node2D).global_position + Vector2(0, -130)
	player.global_position = over
	player.velocity = Vector2.ZERO
	player.invulnerable.enable()
	player.set_physics_process(true)
	for i: int in range(45):
		await physics_frame
	# Below where the planks' tops would be (130 px under the start, less half a cell).
	check(player.global_position.y > over.y + 160.0, "the wizard falls into it")
	player.set_physics_process(false)
	bell.call("hex_hit", 1, Vector2.RIGHT)
	check(bool(bell.call("rung")) and info.bridge_up(id), "a hex bolt rings the bell, and the record keeps it")
	for i: int in range(60):
		await physics_frame
	check(planks.all(func(n: Node) -> bool: return bool(n.call("up")) and not bool((n.get_node("CollisionShape2D") as CollisionShape2D).disabled)), "the bridge lays itself across")
	player.global_position = over
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	for i: int in range(30):
		await physics_frame
	check(player.is_on_floor() and player.global_position.y < over.y + 100.0, "and the wizard stands on it")
	player.set_physics_process(false)
	# Gone and back: the bridge is still up.
	info._load_level()
	await settle()
	player.set_physics_process(false)
	planks = placed("bridge.tscn").filter(func(n: Node) -> bool: return int(n.get("chasm")) == id)
	check(planks.all(func(n: Node) -> bool: return bool(n.call("up"))), "it stays up when the level is loaded again")


func fog() -> void:
	print("sleep fog")
	var bank: SleepFog = placed("sleep_fog.tscn")[0] as SleepFog
	Abilities.set_tier(player, &"hex", 1)
	var hex: Hex = player.get_node("Hex") as Hex
	hex.refill()
	player.global_position = bank.middle() + Vector2(0, 40)
	# Its part of the level wakes round the wizard within a few frames.
	for i: int in range(12):
		await physics_frame
		player.global_position = bank.middle() + Vector2(0, 40)
	check(player.is_drowsy(), "in the fog, the wizard is drowsy")
	Abilities.cast(player)
	check(hex.charges == hex.charges_max, "and the spell does nothing")
	player.levitating = true
	player.drowsy = 0.0
	for i: int in range(3):
		await physics_frame
		player.global_position = bank.middle() + Vector2(0, 40)
	check(not player.levitating, "becoming drowsy ends a levitate float")
	player.global_position = bank.middle() + Vector2(0, -2000)
	for i: int in range(30):
		await physics_frame
	player.drowsy = maxf(0.0, player.drowsy - 0.5)
	check(not player.is_drowsy(), "out of it, it wears off")
	Abilities.cast(player)
	check(hex.charges == hex.charges_max - 1, "and the spell works again")


func moths() -> void:
	print("moths")
	var lantern: Node = null
	for n: Node in info.map_elements.get_children():
		if n is Checkpoint and not info.is_lantern_spent(n):
			lantern = n
			break
	var swarms: Array[Node] = placed("moths.tscn")
	check(not swarms.is_empty(), "moth swarms in the level")
	var swarm: MothSwarm = null
	var glass: Vector2 = (lantern as Node2D).global_position
	for s: Node in swarms:
		if (s as MothSwarm).home.distance_to(glass) <= MothSwarm.DRAW:
			swarm = s as MothSwarm
	check(swarm != null, "one waits near the lantern")
	if swarm == null:
		return
	player.global_position = glass + Vector2(0, -3000)
	info.light_lantern(lantern)
	var before: float = swarm.global_position.distance_to(swarm.target())
	for i: int in range(60):
		await physics_frame
	check(swarm.drawn_to == &"lantern" and swarm.global_position.distance_to(swarm.target()) < before, "a lit lantern draws it")
	# A moth touching the wizard stings.
	player.invulnerable.end()
	var hp: int = player.health.health
	player.global_position = swarm.global_position + swarm.spots[0] + Vector2(0, 40)
	await physics_frame
	await physics_frame
	check(player.health.health < hp, "the moths sting")
	player.health.health = player.health.max_health
	swarm.hex_hit(1, Vector2.RIGHT)
	check(swarm.is_scattered(), "a hex scatters them")
	player.invulnerable.end()
	hp = player.health.health
	player.global_position = swarm.global_position + Vector2(0, 40)
	for i: int in range(10):
		await physics_frame
	check(player.health.health == hp, "scattered, they sting no one")
	swarm.scattered = 0.0
	player.global_position = glass + Vector2(0, -3000)


func wraiths() -> void:
	print("wraiths")
	var wraith: Node2D = placed("wraith_enemy.tscn")[0] as Node2D
	var brain: Node = wraith.get_node("Wraith")
	# Put the wizard a few cells off with rock between, if there is some: it comes anyway.
	var from: Vector2 = wraith.global_position
	player.global_position = from + Vector2(500, 0)
	player.invulnerable.enable()
	for i: int in range(90):
		await physics_frame
	check(bool(brain.get("awake")) and wraith.global_position.distance_to(player.global_position) < from.distance_to(player.global_position), "it senses the wizard and drifts at them")
	# Straight through rock: put it in rock beside the wizard and it keeps coming.
	var rock: Variant = null
	for v: Vector2i in info.world.grounds:
		if info.world.is_valid(v + Vector2i.RIGHT * 3) and not info.solid_at(info.cell_position(v + Vector2i.RIGHT * 3)):
			rock = v
			break
	if rock != null:
		wraith.global_position = info.cell_position(rock)
		player.global_position = info.cell_position(rock + Vector2i.RIGHT * 3)
		var start: Vector2 = wraith.global_position
		for i: int in range(30):
			await physics_frame
		check(bool(brain.call("in_rock")) or wraith.global_position.distance_to(start) > 20.0, "rock does not stop it")
		check(wraith.global_position.x > start.x, "it moves through the rock toward the wizard")
	var wound: Wound = wraith.get_node("Wound") as Wound
	var hp: int = wound.hp
	wound.hit(1, Vector2.RIGHT)
	check(not is_instance_valid(wraith) or wraith.is_queued_for_deletion() or wound.hp < hp, "the hex wounds it")
	if is_instance_valid(wraith) and not wraith.is_queued_for_deletion():
		(wraith.get_node("Stunner") as Stunner).stun(2.0)
		var held: Vector2 = wraith.global_position
		for i: int in range(10):
			await physics_frame
		check(wraith.global_position == held, "stunned, it stops")
