extends TestKit
## Bone gates, which only a skeleton key opens: bone vaults of rich loot in some levels, relics
## behind a bone gate instead of a secret room in half of relic levels, bone gates on the way deep
## down; and the shrine's skeleton key, sold at full health instead of a relic's whereabouts and
## laid somewhere in the level.
## godot --headless --path . --script res://tests/bones_test.gd


func bone_vaults(w: LevelGen) -> Array:
	return w.vaults.filter(func(v: Dictionary) -> bool: return int(v["color"]) == KeyRing.SKELETON)


func in_room(vault: Dictionary, type: LevelGen.Type, w: LevelGen) -> bool:
	return (vault["room"] as Array).any(func(c: Vector2i) -> bool: return w.get_cell(c).type == type)


func run() -> void:
	print("dealt by the level seed")
	var vaulted: int = 0
	var gated: int = 0
	var surface: int = 0
	for x: int in range(400):
		vaulted += 1 if Rules.bone_vault_at(Vector2i(x, 2)) else 0
		gated += 1 if Rules.relic_gated_at(Vector2i(x, 2)) else 0
		surface += 1 if Rules.bone_vault_at(Vector2i(x, 0)) else 0
	check(surface == 0, "no bone vaults in first levels")
	check(vaulted > 60 and vaulted < 140, "bone vaults in about %d%% of levels (%d of 400)" % [Rules.BONE_VAULT_CHANCE, vaulted])
	check(gated > 150 and gated < 250, "relics gated in about %d%% of relic levels (%d of 400)" % [Rules.RELIC_GATE_CHANCE, gated])

	print("bone vaults")
	var seen: int = 0
	for x: int in range(1, 400):
		var at: Vector2i = Vector2i(x, 2)
		if not Rules.bone_vault_at(at) or Relics.at(at) != &"":
			continue
		var def: NextWorldDef = Rules.def_for(at)
		var cells: Array = collapse(def.coord)
		var w: LevelGen = LevelGen.new(cells, def)
		var bones: Array = bone_vaults(w)
		if bones.is_empty():
			continue
		var vault: Dictionary = bones[0]
		var door: Vector2i = vault["door"]
		check(w.get_cell(door).type == LevelGen.Type.DOOR and int(w.get_cell(door).extra_info) == KeyRing.SKELETON, "%s: a bone gate at %s" % [at, door])
		check(in_room(vault, LevelGen.Type.CLUSTER, w) and w.vault_loot(KeyRing.SKELETON, door) == LevelGen.BONE_LOOT, "%s: a hoard behind it" % at)
		var again: LevelGen = LevelGen.new(cells, def)
		check(again.vaults == w.vaults, "%s: the same every visit" % at)
		seen += 1
		if seen >= 3:
			break
	check(seen >= 3, "bone vaults found in %d levels" % seen)

	print("relics behind bone gates")
	var relics: int = 0
	for x: int in range(1, 4000):
		# One row past the garden's gate row (whose levels hold no relic of their own: Bosses).
		var at: Vector2i = Vector2i(x, Relics.MIN_DEPTH + 1)
		if Relics.at(at) == &"" or not Rules.relic_gated_at(at):
			continue
		var def: NextWorldDef = Rules.def_for(at)
		var w: LevelGen = LevelGen.new(collapse(def.coord), def)
		var in_secret: bool = w.secrets.any(func(s: Dictionary) -> bool: return (s["rewards"] as Array).any(func(r: Array) -> bool: return r[1] == LevelGen.Type.RELIC))
		var bones: Array = bone_vaults(w)
		if bones.is_empty():
			check(in_secret or w.objects.any(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.RELIC), "%s: no room for a bone vault, so the relic is still in the level" % at)
		else:
			check(in_room(bones[0], LevelGen.Type.RELIC, w) and not in_secret, "%s: the relic waits behind the bone gate, not in a secret room" % at)
			check((bones[0]["room"] as Array).size() >= 4, "%s: in a room two high" % at)
		relics += 1
		if relics >= 3:
			break
	check(relics >= 3, "%d gated relic levels checked" % relics)

	print("bone gates on the way, deep down")
	var shallow: int = 0
	var deep: int = 0
	var deep_doors: int = 0
	for x: int in [1, 7, 28, 99, 512, 640]:
		for d: int in [2, 7]:
			var def: NextWorldDef = Rules.def_for(Vector2i(x, d))
			var w: LevelGen = LevelGen.new(collapse(def.coord), def)
			var vault_doors: Array = w.vaults.map(func(v: Dictionary) -> Vector2i: return v["door"])
			for v: Vector2i in w.objects:
				var cell: LevelGen.Cell = w.get_cell(v)
				if cell.type != LevelGen.Type.DOOR or v in vault_doors:
					continue
				var bone: bool = int(cell.extra_info) == KeyRing.SKELETON
				if d < Rules.SKELETON_DOOR_DEPTH:
					shallow += 1 if bone else 0
				else:
					deep_doors += 1
					deep += 1 if bone else 0
	check(shallow == 0, "none above depth %d" % Rules.SKELETON_DOOR_DEPTH)
	check(deep > 0 and deep < deep_doors, "some doors below it (%d of %d)" % [deep, deep_doors])

	print("in play: a bone gate")
	await boot()
	player.set_physics_process(false)
	var target: Vector2i = Vector2i(-1, -1)
	for x: int in range(28, 400):
		if Rules.bone_vault_at(Vector2i(x, 1)) and Relics.at(Vector2i(x, 1)) == &"":
			target = Vector2i(x, 1)
			break
	info.coord = target
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	var gate: Node = null
	for n: Node in placed("door.tscn"):
		if int(n.get_meta(&"key_color", -1)) == KeyRing.SKELETON:
			gate = n
	check(gate != null, "a bone gate in %s" % Rules.where(target))
	if gate != null:
		var unlock: Node = gate.get_node("Unlock")
		check(int((unlock.call("interaction_hint") as Dictionary).get("key_color", -1)) == KeyRing.SKELETON, "its prompt asks for a skeleton key")
		player.keyring.clear()
		for c: int in range(Rules.KEY_COLOR_COUNT):
			player.keyring.take(c)
		unlock.call("interacted")
		await process_frame
		check(is_instance_valid(gate) and not gate.is_queued_for_deletion(), "no coloured key opens it")
		player.keyring.set_skeletons(1)
		unlock.call("touch", player)
		await process_frame
		check(is_instance_valid(gate) and not gate.is_queued_for_deletion() and player.keyring.skeletons() == 1, "walking into it never spends a skeleton key")
		unlock.call("interacted")
		await process_frame
		check((not is_instance_valid(gate) or gate.is_queued_for_deletion()) and player.keyring.skeletons() == 0, "a skeleton key opens it, and crumbles")

	print("in play: the shrine's skeleton key")
	var shrine: Node = placed("shrine.tscn")[0] if not placed("shrine.tscn").is_empty() else null
	check(shrine != null, "a shrine")
	player.health.health = player.health.max_health
	var home: Vector2i = info.coord
	var hints: Dictionary = info.run.relic_hints.duplicate()
	var plain: int = 0
	var hinted: int = 0
	info.run.relic_hints = {}
	for x: int in range(200):
		info.coord = Vector2i(x, 2)
		plain += 1 if bool(shrine.call("sells_skeleton")) else 0
	info.run.relic_hints = {Vector2i(999, 9): &"blink"}
	for x: int in range(200):
		info.coord = Vector2i(x, 2)
		hinted += 1 if bool(shrine.call("sells_skeleton")) else 0
	info.run.relic_hints = hints
	info.coord = home
	check(plain > 30 and plain < 100 and hinted > plain + 40, "sold in some shrines (%d of 200), and more while a marked relic waits (%d of 200)" % [plain, hinted])
	player.health.health = player.health.max_health - 1
	check(not bool(shrine.call("sells_skeleton")), "never while there is mending to do")
	player.health.health = player.health.max_health
	# Make this shrine sell one: with no relic left to point to, it always does.
	var found: Dictionary = info.run.relics_found.duplicate()
	for dx: int in range(-Relics.SEARCH - 1, Relics.SEARCH + 2):
		for dy: int in range(0, Relics.SEARCH + 2):
			info.run.relics_found[Vector2i(home.x + dx, dy)] = true
	check(bool(shrine.call("sells_skeleton")) and not bool(shrine.call("reads_relic")), "with no relic to point to, it sells a skeleton key")
	var price: int = int(shrine.call("skeleton_price"))
	check(price == roundi(2.0 * Rules.deeper_price(home.y)), "for %d stars (twice the deeper price)" % price)
	player.collect(price + 5 - player.coins.coins)
	var drops_before: int = (info.record().dropped as Dictionary).size()
	shrine.call("buy_mend")
	await process_frame
	check(player.coins.coins == 5 and bool(shrine.call("used")), "bought: paid, and the shrine is spent")
	var dropped: Dictionary = info.record().dropped
	check(dropped.size() == drops_before + 1, "a skeleton key is laid in the level, kept in its record")
	var sold: Node2D = null
	for n: Node in placed("key.tscn"):
		if int(n.get_meta(&"key_color", -1)) == KeyRing.SKELETON and n.has_meta(&"dropped_id"):
			sold = n as Node2D
	check(sold != null, "and it lies there")
	if sold != null:
		var cell: Vector2i = info.cell_at(sold.global_position)
		check(absi(cell.x - info.world.shrine.x) + absi(cell.y - info.world.shrine.y) >= MapInfo.SOLD_KEY_APART, "away from the shrine (at %s)" % cell)
		check(info.world.ground_below(cell), "on a floor")
		# A dropped key arms on a physics frame once the wizard is well away from it.
		await until(func() -> bool: return bool(sold.get("armed")))
		check(bool(sold.get("armed")), "it arms (the wizard is away at the shrine)")
		sold.call("touch", player)
		await process_frame
		check(player.keyring.skeletons() == 1 and (info.record().dropped as Dictionary).size() == drops_before, "taken, it goes in the pocket")
	info.run.relics_found = found

	finish()
