extends SceneTree
## Secret rooms and relics: rooms are pockets of rock behind a false wall beside a floor, hidden
## (plain rock, even on the map) until stepped into or struck by a hex bolt; then the room opens
## for good and its rewards appear. Relic levels keep a move in theirs; taking it teaches tier I
## (for a lot of stars), which shrines never offer; at full health a shrine sells the whereabouts of
## the nearest relic not yet found.
## godot --headless --path . --script res://tests/secrets_test.gd

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


## Whether every secret in `w` is a pocket of rock with rock under it, entered from a floor.
func well_formed(w: MapInfo.World) -> bool:
	for id: int in range(w.secrets.size()):
		var s: Dictionary = w.secrets[id]
		var cells: Dictionary = {}
		for c: Vector2i in s["room"] + s["entrance"]:
			cells[c] = true
			if w.get_cell(c).type != MapInfo.Type.CRACKED or int(w.get_cell(c).extra_info) != id:
				return false
		# Rock under its floor, so it has one once opened.
		for c: Vector2i in s["room"]:
			var n: Vector2i = c + Vector2i.DOWN
			if cells.has(n) or not w.is_valid(n):
				continue
			if w.get_cell(n).type != MapInfo.Type.GROUND and w.get_cell(n).type != MapInfo.Type.CRACKED:
				return false
		var door: Vector2i = s["entrance"][0]
		var beside: bool = false
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			var o: Vector2i = door + d
			if w.is_valid(o) and not cells.has(o) and w.get_cell(o).type != MapInfo.Type.GROUND and w.get_cell(o).type != MapInfo.Type.CRACKED and w.ground_below(o):
				beside = true
		if not beside:
			return false
		for r: Array in s["rewards"]:
			if not (s["room"] as Array).has(r[0]):
				return false
	return true


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://secrets_test.save"
	await process_frame
	var wfc: Node = main.get_node("WaveFunctionCollapse")

	print("generation")
	var levels: int = 0
	var with_secret: int = 0
	var formed: bool = true
	var relic_levels: int = 0
	var relic_in_room: int = 0
	var relic_seed: int = -1
	for world_seed: int in range(1, 26):
		for depth: int in [0, 1, 3]:
			var def: NextWorldDef = MapInfo.def_for(Vector2i(world_seed, depth))
			var w: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def), def)
			levels += 1
			if not w.secrets.is_empty():
				with_secret += 1
			formed = formed and well_formed(w)
			if def.relic != &"":
				relic_levels += 1
				var held: bool = w.secrets.any(func(s: Dictionary) -> bool: return (s["rewards"] as Array).any(func(r: Array) -> bool: return r[1] == MapInfo.Type.RELIC and StringName(r[2]) == def.relic))
				if held:
					relic_in_room += 1
					if depth == 1 and relic_seed < 0:
						relic_seed = world_seed
	# Relics are rare (about one level in 20): if the sample had none at depth 1, find one.
	if relic_seed < 0:
		relic_seed = 1
		while Relics.at(Vector2i(relic_seed, 1)) == &"":
			relic_seed += 1
		var def: NextWorldDef = MapInfo.def_for(Vector2i(relic_seed, 1))
		var w: MapInfo.World = MapInfo.World.new(wfc.call("generate_level", def), def)
		relic_levels += 1
		if w.secrets.any(func(s: Dictionary) -> bool: return (s["rewards"] as Array).any(func(r: Array) -> bool: return r[1] == MapInfo.Type.RELIC and StringName(r[2]) == def.relic)):
			relic_in_room += 1
	print("  %d levels, %d with a secret room; %d relic levels, %d with the relic in a room" % [levels, with_secret, relic_levels, relic_in_room])
	check(with_secret >= levels * 9 / 10, "nearly every level has a secret room")
	check(formed, "every room is a pocket of rock with rock under it, its entrance beside a floor")
	check(relic_levels > 0 and relic_in_room == relic_levels, "every relic waits in a secret room")
	var depth0: int = 0
	for s: int in range(1, 200):
		if Relics.at(Vector2i(s, 0)) != &"":
			depth0 += 1
	check(depth0 == 0, "no relics at depth 0 (outside debug)")

	print("shrines hold the moves back")
	menu_start(relic_seed)
	await settle()
	player.set_physics_process(false)
	var gated: bool = true
	for s: int in range(0, 60):
		for a: StringName in Abilities.offers(s, player, 2):
			if a in Relics.MOVES:
				gated = false
	check(gated, "no shrine offers a move not yet found")

	print("a hex bolt reveals a secret room")
	check(not info.world.secrets.is_empty(), "the first level has a secret room")
	var first: Dictionary = info.world.secrets[0]
	var entry: Vector2i = first["entrance"][0]
	var stand: Vector2i = beside(entry)
	player.global_position = info.cell_position(stand)
	await physics_frame
	await physics_frame
	var bolt: Node2D = Node2D.new()
	bolt.set_script(preload("res://scripts/HexBolt.gd"))
	bolt.set("dir", Vector2(entry - stand))
	info.map_elements.add_child(bolt)
	bolt.global_position = info.cell_position(stand)
	for i: int in range(20):
		await physics_frame
	check((info.record().get("secrets", {}) as Dictionary).has(0), "a bolt passes the false wall and, striking the rock behind it, opens the room")
	await process_frame
	check(placed("cracked_wall.tscn").filter(func(n: Node) -> bool: return int(n.get_meta(&"secret", -1)) == 0).is_empty(), "the whole room crumbles")
	check((first["room"] as Array).all(func(c: Vector2i) -> bool: return (info.record()["broken"] as Dictionary).has(c)), "and stays broken in the record")

	print("a false wall")
	player.collect(100)
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	player.set_physics_process(false)
	check(info.coord == Vector2i(relic_seed, 1) and not info.world.secrets.is_empty(), "level (%d, 1) has a secret room" % relic_seed)
	var secret: Dictionary = info.world.secrets[0]
	var hidden: Array[Node] = placed("cracked_wall.tscn").filter(func(n: Node) -> bool: return int(n.get_meta(&"secret", -1)) == 0 and bool(n.get_meta(&"hidden")))
	var door_node: Array[Node] = placed("cracked_wall.tscn").filter(func(n: Node) -> bool: return int(n.get_meta(&"secret", -1)) == 0 and not bool(n.get_meta(&"hidden")))
	check(hidden.size() == (secret["room"] as Array).size() and door_node.size() == 1, "its room is %d cells of hidden rock behind one false wall" % hidden.size())
	check((door_node[0] as CollisionObject2D).collision_layer == 0 and (hidden[0] as CollisionObject2D).collision_layer != 0, "the false wall can be walked through; the rock behind it is solid")
	check(placed("relic.tscn").is_empty(), "its relic is not out until it opens")
	info.ink_whole_map()
	var map: Node = main.get_node("RisoMap")
	map.call("_build_textures_for", info.world, info.seen(), info.record().get("broken", {}))
	var img: Image = (map.get("rock") as Sprite2D).texture.get_image()
	var room_cell: Vector2i = secret["room"][0]
	var door: Vector2i = secret["entrance"][0]
	check(img.get_pixel(room_cell.x, room_cell.y).a > 0.5 and img.get_pixel(door.x, door.y).a > 0.5, "an inked map shows the room and its false wall as rock")
	player.global_position = info.cell_position(beside(door))
	for i: int in range(3):
		await physics_frame
	check(not (info.record().get("secrets", {}) as Dictionary).has(0), "standing beside it opens nothing")
	player.global_position = info.cell_position(door)
	for i: int in range(3):
		await physics_frame
	check((info.record().get("secrets", {}) as Dictionary).has(0), "stepping into the false wall opens the room")
	await process_frame
	var relics: Array[Node] = placed("relic.tscn")
	check(relics.size() == 1 and StringName(relics[0].get("ability")) == info.here.relic, "the relic (%s) is out" % info.here.relic)
	var stars_in_room: int = placed("coin.tscn").filter(func(n: Node) -> bool: return (secret["room"] as Array).has(n.get_meta(&"cell"))).size()
	check(stars_in_room > 0, "with %d stars" % stars_in_room)

	print("the relic")
	var move: StringName = info.here.relic
	var before: int = Abilities.tier(player, move)
	var cost: int = int(relics[0].call("price"))
	check(cost == Relics.price(1) and cost >= 4 * MapInfo.deeper_price(1), "it costs %d stars, a lot" % cost)
	player.collect(cost - 1 - player.coins.coins)
	relics[0].call("take")
	await process_frame
	check(Abilities.tier(player, move) == before and is_instance_valid(relics[0]) and not relics[0].is_queued_for_deletion(), "a star short: it stays")
	player.collect(1)
	relics[0].call("take")
	await process_frame
	check(Abilities.tier(player, move) == before + 1 and info.relics_found.has(info.coord) and player.coins.coins == 0, "paid: it teaches %s %s" % [move, Abilities.roman(before + 1)])
	var upgrades: bool = false
	for s: int in range(0, 60):
		if move in Abilities.offers(s, player, Abilities.ORDER.size()):
			upgrades = true
	check(upgrades or Abilities.tier(player, move) >= int(Abilities.MAX[move]), "and shrines now offer its higher tiers")
	info.travel(MapInfo.Exit.BACK)
	await settle()
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	player.set_physics_process(false)
	check(placed("cracked_wall.tscn").filter(func(n: Node) -> bool: return n.has_meta(&"secret") and int(n.get_meta(&"secret")) == 0).is_empty() and placed("relic.tscn").is_empty(), "on a revisit the room is still open and the relic gone")

	print("a shrine points to a relic")
	var shrines: Array[Node] = placed("shrine.tscn")
	check(not shrines.is_empty(), "the level has a shrine")
	var shrine: Node = shrines[0]
	player.health.health = player.health.max_health - 1
	check(bool(shrine.call("can_mend")) and not bool(shrine.call("reads_relic")), "while hurt, its third station mends")
	player.health.health = player.health.max_health
	var next: Variant = info.next_relic()
	check(bool(shrine.call("reads_relic")) and next != null and next != info.coord and StringName(shrine.call("relic_move")) == Relics.at(next), "at full health it offers the whereabouts of the nearest relic not yet found (%s, at %s)" % [shrine.call("relic_move"), next])
	var hint_cost: int = int(shrine.call("relic_price"))
	player.collect(hint_cost - player.coins.coins)
	shrine.call("buy_mend")
	check(info.relic_hints.has(next) and player.coins.coins == 0 and bool(shrine.call("used")), "bought (%d stars): marked on the worlds map, and the shrine is spent" % hint_cost)
	check(info.next_relic() != next, "the next shrine would point to another one")
	check(main.get_node("RisoMap").call("pickable", info).has(next), "the marked level can be picked on the worlds map")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASSED")
		quit()


func menu_start(world_seed: int) -> void:
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = str(world_seed)
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player


## The floor spot beside a secret's entrance (outside the room).
func beside(door: Vector2i) -> Vector2i:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
		var o: Vector2i = door + d
		if info.world.is_valid(o) and info.world.get_cell(o).type != MapInfo.Type.GROUND and info.world.get_cell(o).type != MapInfo.Type.CRACKED and info.world.ground_below(o):
			return o
	return door
