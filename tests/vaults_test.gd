extends TestKit
## Key rarity and vaults. Key colours are dealt by rarity (Rules.KEY_RARITY): keys, corridor
## doors and padlocks come up in sun most often and plum least, and every level's first key is sun.
## Vaults are small rooms sealed in rock behind a locked door, dealt evenly among the colours, and
## the rarer the lock the better the loot (LevelGen.VAULT_LOOT).
## godot --headless --path . --script res://tests/vaults_test.gd


## The things in `w`'s vault, as [type, extra info], in the order they were laid.
func loot_of(w: LevelGen, vault: Dictionary) -> Array:
	var out: Array = []
	for v: Vector2i in w.objects:
		if (vault["room"] as Array).has(v):
			out.append([w.get_cell(v).type, w.get_cell(v).extra_info])
	return out


## Whether `vault` is open inside, walled in rock all round but for its door, and entered at floor
## height from a floor outside.
func well_formed(w: LevelGen, vault: Dictionary) -> bool:
	var room: Array = vault["room"]
	var door: Vector2i = vault["door"]
	if w.get_cell(door).type != LevelGen.Type.DOOR or int(w.get_cell(door).extra_info) != int(vault["color"]):
		return false
	for c: Vector2i in room:
		if w.is_ground(c):
			return false
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if room.has(n) or n == door:
				continue
			if w.is_valid(n) and not w.is_ground(n):
				return false
	# Rock over and under the door, open floor on its far side.
	var outside: Vector2i = door + (Vector2i.LEFT if room.has(door + Vector2i.RIGHT) else Vector2i.RIGHT)
	return w.is_ground(door + Vector2i.UP) and w.is_ground(door + Vector2i.DOWN) and not w.is_ground(outside) and w.is_ground(outside + Vector2i.DOWN)


func run() -> void:
	print("rarity")
	var rolls: Array[int] = [0, 0, 0, 0]
	for r: int in range(1500):
		rolls[Rules.rarity_color(Rules.level_seed(r, 99))] += 1
	check(rolls[0] > rolls[1] and rolls[1] > rolls[2] and rolls[2] > rolls[3] and rolls[3] > 0, "each colour is dealt less often than the one before (%s)" % [rolls])
	check(Rules.rarity_color(-5) >= 0 and Rules.rarity_color(-5) < Rules.KEY_COLOR_COUNT, "any roll deals a colour")

	print("generated levels")
	var keys: Array[int] = [0, 0, 0, 0]
	var doors: Array[int] = [0, 0, 0, 0]
	var vault_colors: Dictionary = {}
	var levels: int = 0
	var with_vault: int = 0
	var ember_vaults: int = 0
	var ember_keys: int = 0
	for seed_value: int in [1, 7, 28, 99, 512]:
		for depth: int in [0, 2, 4, 7]:
			var at: Vector2i = Vector2i(seed_value, depth)
			var def: NextWorldDef = Rules.def_for(at)
			var cells: Array = collapse(def.coord)
			var w: LevelGen = LevelGen.new(cells, def)
			var label: String = "seed %d depth %d" % [seed_value, depth]
			levels += 1
			var first_key: int = -1
			var vault_doors: Dictionary = {}
			for vault: Dictionary in w.vaults:
				vault_doors[vault["door"]] = true
			for v: Vector2i in w.objects:
				var cell: LevelGen.Cell = w.get_cell(v)
				if cell.type == LevelGen.Type.KEY and cell.extra_info != null and int(cell.extra_info) != KeyRing.SKELETON and not w.vaults.any(func(vt: Dictionary) -> bool: return (vt["room"] as Array).has(v)):
					if v != w.start_key:
						keys[int(cell.extra_info)] += 1
						if first_key < 0:
							first_key = int(cell.extra_info)
				elif cell.type == LevelGen.Type.DOOR and not vault_doors.has(v) and int(cell.extra_info) != KeyRing.SKELETON:
					doors[int(cell.extra_info)] += 1
			check(first_key == 0, label + ": the first key is the commonest colour")
			if not w.vaults.is_empty():
				with_vault += 1
			else:
				print("  no vault: ", label)
			for vault: Dictionary in w.vaults:
				var color: int = vault["color"]
				# Bone vaults are bones_test's.
				if color < Rules.KEY_COLOR_COUNT:
					vault_colors[color] = int(vault_colors.get(color, 0)) + 1
				if color == 1:
					ember_vaults += 1
					if w.vault_loot(color, vault["door"]).has([LevelGen.Type.KEY, 2]):
						ember_keys += 1
				check(well_formed(w, vault), label + ": vault at %s is sealed in rock behind its door" % vault["door"])
				check(loot_of(w, vault) == w.vault_loot(color, vault["door"]), label + ": colour %d vault holds its loot %s" % [color, loot_of(w, vault)])
			var again: LevelGen = LevelGen.new(cells, def)
			var same_colors: bool = true
			for v: Vector2i in w.objects:
				if w.get_cell(v).extra_info != again.get_cell(v).extra_info and w.get_cell(v).type in [LevelGen.Type.KEY, LevelGen.Type.DOOR]:
					same_colors = false
			check(w.objects == again.objects and w.vaults == again.vaults and same_colors, label + ": vaults and colours are the same every visit")
	print("  keys by colour %s, doors %s, vaults %s, %d of %d levels with a vault" % [keys, doors, vault_colors, with_vault, levels])
	check(keys[0] > keys[1] and keys[1] > keys[3], "keys come in common colours far more than rare ones")
	check(doors[0] > doors[1] and doors[1] > doors[3], "and so do doors")
	check(with_vault * 4 >= levels * 3, "most levels have a vault")
	check(vault_colors.size() == Rules.KEY_COLOR_COUNT, "vaults come in every colour")
	var table: Array = LevelGen.VAULT_LOOT
	check(table[0] == [[LevelGen.Type.CLUSTER, 0.5]] and table[1] == [[LevelGen.Type.CLUSTER, 1.0]] and table[2] == [[LevelGen.Type.CLUSTER, 1.5]] and (table[3] as Array).has([LevelGen.Type.KEY, KeyRing.SKELETON]), "rarer locks guard better loot: half a cluster, a cluster, a cluster and a half, a cluster and a skeleton key")
	print("  ember vaults with a moss key: %d of %d" % [ember_keys, ember_vaults])
	check(ember_vaults == 0 or ember_keys > 0, "ember vaults sometimes hold a moss key")

	await boot()
	player.set_physics_process(false)
	var vault: Dictionary = {}
	for step: int in range(4):
		var keyed: Array = info.world.vaults.filter(func(vt: Dictionary) -> bool: return int(vt["color"]) < Rules.KEY_COLOR_COUNT)
		if not keyed.is_empty():
			vault = keyed[0]
			break
		info.travel(MapInfo.Exit.RIGHT)
		await settle(6)
		player.set_physics_process(false)
	check(not vault.is_empty(), "found a vault in %s" % Rules.where(info.coord))
	if vault.is_empty():
		finish()
		return
	var door: Node = null
	var loot: Array[Node] = []
	for n: Node in info.map_elements.get_children():
		if not n.has_meta(&"cell"):
			continue
		if n.get_meta(&"cell") == vault["door"] and n.scene_file_path.get_file() == "door.tscn":
			door = n
		elif (vault["room"] as Array).has(n.get_meta(&"cell")):
			loot.append(n)
	var color: int = vault["color"]
	check(door != null and int(door.get_meta(&"key_color", -1)) == color, "its door is locked in colour %d" % color)
	check(loot.size() == info.world.vault_loot(color, vault["door"]).size(), "its loot lies inside (%d)" % loot.size())
	player.keyring.clear()
	player.keyring.take((color + 1) % Rules.KEY_COLOR_COUNT)
	door.get_node("Unlock").call("try_open")
	await settle(1)
	check(is_instance_valid(door) and not door.is_queued_for_deletion(), "another colour's key does not open it")
	player.keyring.take(color)
	door.get_node("Unlock").call("try_open")
	await settle(1)
	check(not is_instance_valid(door) or door.is_queued_for_deletion(), "its own colour does")
	check((info.record().opened as Dictionary).has(vault["door"]), "and it stays open")
	finish()


