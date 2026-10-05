extends SceneTree
## The cemetery archetype (docs/DEEPER_PLAN.md, group 3): bands of depths, its own terrain sample
## (collapsed with no symmetry), realm and decor, its gates (chasms bridged once their bell is
## freed from its chain, by a key or a switch, and rung), and what lives there: moths drawn to a lit lantern and scattered by a hex, sleep fog that
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
	check(info.here.cemetery() and MapInfo.where(info.coord) == "world 28 · depth 3", "cemetery world label shows only world and depth")
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
	check(kinds == [&"garden", &"garden", &"garden", &"cemetery", &"cemetery", &"cemetery", &"sky", &"sky", &"sky"], "garden, then cemetery, then sky, a band of %d each: %s" % [NextWorldDef.BAND, kinds])
	var def: NextWorldDef = MapInfo.def_for(Vector2i(28, 4))
	check(def.region == NextWorldDef.GRAVEYARD and def.symmetry == 1 and def.realm() == &"cemetery", "a cemetery collapses the graveyard sample, unturned, and prints in its realm")
	var garden: NextWorldDef = MapInfo.def_for(Vector2i(28, 1))
	check(garden.region != NextWorldDef.GRAVEYARD and garden.realm() == &"garden" and not garden.title().contains("cemetery"), "a garden level has its own terrain and realm")
	check(MapInfo.region_for(0) == MapInfo.region_for(9) and MapInfo.region_for(0) != NextWorldDef.ISLANDS, "garden bands are the tunnels (the islands are the sky's)")
	var side: NextWorldDef = MapInfo.def_for(Worlds.side_at(0, Vector2i(28, 4)))
	check(not side.cemetery(), "a side world under a cemetery is not one")


func generation(wfc: Node) -> void:
	print("generation")
	for at: Vector2i in [Vector2i(1, 3), Vector2i(7, 4), Vector2i(28, 3), Vector2i(28, 5), Vector2i(99, 3)]:
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
		check(w.chasms.size() >= MapInfo.CHASMS_MIN, "%s: %d chasms, and as many bells" % [at, w.chasms.size()])
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
					shaped = shaped and (d == 0 or not w.is_valid(c) or w.get_cell(c).type in [MapInfo.Type.EMPTY, MapInfo.Type.GROUND, MapInfo.Type.CRACKED])
				shaped = shaped and w.get_cell(v + Vector2i(0, MapInfo.World.CHASM_DEPTH)).type == MapInfo.Type.SPIKES
			for edge: Vector2i in [chasm["left"], chasm["right"]]:
				shaped = shaped and w.get_cell(edge + Vector2i.DOWN).type in [MapInfo.Type.GROUND, MapInfo.Type.CRACKED]
			check(shaped, "%s: chasm %d is %d across between floors, thorns at its bottom, planks over it" % [at, id, planks.size()])
			var bells: int = 0
			var sides: Dictionary = {}
			for v: Vector2i in w.objects:
				if w.get_cell(v).type == MapInfo.Type.BELL and int((w.get_cell(v).extra_info as Array)[0]) == id:
					bells += 1
					sides[signi(v.x - (planks[0] as Vector2i).x)] = true
					# Rock under it (maybe cracked: broken, a ledge takes its place, MapInfo.prop_up).
					check(v.y == row and w.get_cell(v + Vector2i.DOWN).type in [MapInfo.Type.GROUND, MapInfo.Type.CRACKED], "%s: its bell stands on the floor beside it" % at)
					var lock: int = int((w.get_cell(v).extra_info as Array)[1])
					if lock == -1:
						var levers: int = 0
						for q: Vector2i in w.objects:
							if w.get_cell(q).type == MapInfo.Type.SWITCH and w.get_cell(q).extra_info == v:
								levers += 1
								check(absi(q.x - v.x) + absi(q.y - v.y) >= MapInfo.World.BELL_SWITCH and w.ground_below(q), "%s: its switch stands on a floor away from it" % at)
						check(levers == 1, "%s: a bell chained to a switch has one" % at)
					else:
						check(lock < MapInfo.KEY_COLOR_COUNT, "%s: or a padlock in a key colour (%d)" % [at, lock])
			check(bells == 2 and sides.has(-1) and sides.has(1), "%s: chasm %d has a bell on each side" % [at, id])
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
	# A run up, a jump at the edge and a dash: still short of the far side.
	var shore: Vector2 = info.cell_position(info.cell_at((planks[0] as Node2D).global_position) + Vector2i(-3, -1))
	var far: float = info.cell_position(info.cell_at((planks[planks.size() - 1] as Node2D).global_position) + Vector2i(1, -1)).x
	player.global_position = shore
	player.velocity = Vector2.ZERO
	player.end_invulnerable()
	player.health.health = player.health.max_health
	var hp: int = player.health.health
	player.dash.refresh()
	player.set_physics_process(true)
	Input.action_press(&"Right")
	var jumped: bool = false
	var dashed: int = -1
	var reached: bool = false
	for i: int in range(120):
		await physics_frame
		if not jumped and player.global_position.x > shore.x + 300.0:
			jumped = true
			var jump: InputEventAction = InputEventAction.new()
			jump.action = &"Jump"
			jump.pressed = true
			Input.parse_input_event(jump)
			dashed = i + 10
		if i == dashed:
			var dash: InputEventAction = InputEventAction.new()
			dash.action = &"Dash"
			dash.pressed = true
			Input.parse_input_event(dash)
		if player.is_on_floor() and player.global_position.x > far - 64.0 and player.health.health == hp:
			reached = true
	Input.action_release(&"Right")
	Input.action_release(&"Jump")
	Input.action_release(&"Dash")
	player.set_physics_process(false)
	check(jumped and not reached, "a run, a jump and a dash do not get the wizard over it unhurt")
	player.health.health = player.health.max_health
	player.invulnerable.enable()
	# Chained up: struck or rung, it only rattles.
	KeyRing.clear(player)
	bell.call("hex_hit", 1, Vector2.RIGHT)
	bell.call("use")
	check(not bool(bell.call("unchained")) and not bool(bell.call("rung")) and not info.bridge_up(id), "chained, the bell only rattles")
	var lock: int = int(bell.get("lock"))
	if lock >= 0:
		# Its padlock opens to a key of its colour (kept, as keys are).
		KeyRing.set_all(player, [lock])
		bell.call("use")
		check(bool(bell.call("unchained")) and KeyRing.has(player, lock), "a key of the padlock's colour frees it")
	else:
		var lever: Node = placed("switch.tscn").filter(func(n: Node) -> bool: return n.get("gate_cell") == bell.get_meta(&"cell"))[0]
		lever.call("flip")
		check(bool(bell.call("unchained")), "throwing its switch frees it")
	check(info.bell_free(bell.get_meta(&"cell")), "the record keeps it free")
	var other: Node = bells.filter(func(b: Node) -> bool: return b != bell and int(b.get("chasm")) == id)[0]
	check(not bool(other.call("unchained")), "the bell across the chasm is still chained: each has its own chain")
	bell.call("hex_hit", 1, Vector2.RIGHT)
	check(bool(bell.call("rung")) and info.bridge_up(id), "then a hex bolt rings the bell, and the record keeps it")
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
	var swarms: Array[Node] = placed("moths.tscn")
	check(not swarms.is_empty(), "moth swarms in the level")
	# An unspent lantern with a swarm near enough for it to draw.
	var lantern: Node = null
	var swarm: MothSwarm = null
	var glass: Vector2 = Vector2.ZERO
	for n: Node in info.map_elements.get_children():
		if not (n is Checkpoint) or info.is_lantern_spent(n):
			continue
		for s: Node in swarms:
			if swarm == null and (s as MothSwarm).home.distance_to((n as Node2D).global_position) <= MothSwarm.DRAW - 100.0:
				swarm = s as MothSwarm
				lantern = n
				glass = (n as Node2D).global_position
	check(swarm != null, "one waits near a lantern")
	if swarm == null:
		return
	# Near enough that this part of the level is awake, too far to be stung.
	player.global_position = glass + Vector2(0, -420)
	info.light_lantern(lantern)
	var before: float = swarm.global_position.distance_to(swarm.target())
	for i: int in range(60):
		await physics_frame
	check(swarm.drawn_to == &"lantern" and swarm.global_position.distance_to(swarm.target()) < before, "a lit lantern draws it")
	# A moth touching the wizard stings.
	player.end_invulnerable()
	var hp: int = player.health.health
	player.global_position = swarm.global_position + swarm.spots[0] + Vector2(0, 40)
	await physics_frame
	await physics_frame
	check(player.health.health < hp, "the moths sting")
	player.health.health = player.health.max_health
	swarm.hex_hit(1, Vector2.RIGHT)
	check(swarm.is_scattered(), "a hex scatters them")
	# Any other swarm the lantern drew is scattered too, so only these moths are near the wizard.
	for other: Node in swarms:
		if other != swarm:
			(other as MothSwarm).scatter(Vector2.LEFT)
	# Nothing else that stings near where the wizard will stand (whatever the level put there).
	for n: Node in info.map_elements.get_children():
		if n != swarm and (n.has_node("Wound") or n.scene_file_path.get_file() == "spikes.tscn") and (n as Node2D).global_position.distance_to(swarm.global_position) < 500.0:
			n.queue_free()
	await physics_frame
	player.end_invulnerable()
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
