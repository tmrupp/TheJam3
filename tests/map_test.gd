extends TestKit
## Phase 6 of docs/DEEPER_PLAN.md: the printed map. What a level has seen grows around the
## player, all at once when its ink well is paid, and is kept in its record; the map opens on the level, then the
## world, then closes, pausing the game; the world view's links follow the records.
## godot --headless --path . --script res://tests/map_test.gd

var map: Node


func run() -> void:
	await boot()
	player.set_physics_process(false)
	map = main.get_node("RisoMap")

	print("seeing the level")
	var here: Vector2i = info.cell_at(player.global_position)
	check(info.is_seen(here) and info.is_seen(here + Vector2i(3, 0)), "cells around the wizard are seen")
	var far: Vector2i = info.world.exits[MapInfo.Exit.DEEPER]
	check(not info.is_seen(far), "the far deeper exit is not yet seen")
	var before: int = info.seen_count()
	player.global_position = info.cell_position(far)
	await settle(2)
	check(info.is_seen(far) and info.seen_count() > before, "walking there reveals it")
	var wells: Array[Node] = info.map_elements.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.get_file() == "inkwell.tscn")
	check(wells.size() == 1, "one ink well in the level")
	var well: Node = wells[0]
	check(int(well.call("price")) == Rules.map_price(0) and Rules.map_price(4) > Rules.map_price(0), "it costs %d stars here, more deeper" % Rules.map_price(0))
	player.collect(-player.coins.coins)
	well.call("buy")
	check(not bool(well.call("used")) and info.seen_count() < info.world.size.x * info.world.size.y, "too few stars: the map stays as explored")
	player.collect(Rules.map_price(0))
	well.call("buy")
	check(info.seen_count() == info.world.size.x * info.world.size.y and player.coins.coins == 0, "paid: the whole level is inked at once")
	check(bool(well.call("used")), "and the well is dry")
	var count: int = info.seen_count()
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	player.set_physics_process(false)
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	player.set_physics_process(false)
	check(info.seen_count() >= count, "a revisit keeps what was seen")
	check(bool((info.map_elements.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.get_file() == "inkwell.tscn")[0]).call("used")), "and the well stays dry")

	print("cracked walls on the map")
	var cracked: Vector2i = Vector2i(-1, -1)
	for v: Vector2i in info.world.objects:
		if info.world.get_cell(v).type == LevelGen.Type.CRACKED:
			cracked = v
			break
	var mapv: Node = main.get_node("RisoMap")
	info.ink_whole_map()
	mapv.call("_build_textures", info)
	var rock_img: Image = ((mapv.get("rock") as Sprite2D).texture as ImageTexture).get_image()
	check(rock_img.get_pixelv(cracked).a > 0.5, "an unbroken cracked wall is drawn as rock, not passage")
	info.record().broken[cracked] = true
	mapv.call("_build_textures", info)
	rock_img = ((mapv.get("rock") as Sprite2D).texture as ImageTexture).get_image()
	check(rock_img.get_pixelv(cracked).a < 0.5, "once broken it shows as open")
	(info.record().broken as Dictionary).erase(cracked)

	print("opening the map")
	map.call("toggle")
	await process_frame
	check(int(map.get("view")) == 1 and paused and map.visible, "M opens the level page, paused")
	# The page is drawn (inked whole above): its marks note their legend rows, and only those are
	# listed. Teleporters are on the map; this first level has no skeleton key.
	map.call("_level", info)
	var shown: Dictionary = map.get("_shown")
	check(shown.has("teleporter") and (shown.has("deeper") or shown.has("unpaid")) and shown.has("lantern"), "teleporters, exits and lanterns are marked: %s" % [shown.keys()])
	check(not shown.has("skeleton key") and not shown.has("rift"), "the legend leaves out what the page does not show")
	# The page is marked from the layout and the record, as another level's is: a change to the
	# record shows at once, before the things in the scene catch up.
	var rec: LevelRecord = info.record()
	var lanterns: Array[Vector2i] = info.world.objects_of(LevelGen.Type.CHECKPOINT)
	var gone: Array[Vector2i] = info.world.objects_of(LevelGen.Type.KEY) + info.world.objects_of(LevelGen.Type.DOOR)
	for v: Vector2i in lanterns:
		rec.spent_lanterns[v] = true
	for v: Vector2i in gone:
		rec.taken[v] = true
		rec.opened[v] = true
	map.call("_level", info)
	shown = map.get("_shown")
	check(shown.has("spent lantern") and not shown.has("lantern") and not shown.has("respawn"), "lanterns the record has spent are marked spent at once")
	check(not shown.has("key") and not shown.has("door"), "keys and doors the record has taken or opened are gone at once (%d)" % gone.size())
	for v: Vector2i in lanterns:
		rec.spent_lanterns.erase(v)
	for v: Vector2i in gone:
		rec.taken.erase(v)
		rec.opened.erase(v)
	map.call("_level", info)
	shown = map.get("_shown")
	check(shown.has("lantern") and not shown.has("spent lantern"), "and come back as the record has them")
	var pair: Array[Node] = []
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() == "portal.tscn" and n.has_meta(&"cell"):
			pair.append(n)
	var a_end: Node = pair[0]
	var b_end: Node = pair.filter(func(n: Node) -> bool: return n.get_meta(&"cell") == info.cell_at(a_end.get("go_to_pos")))[0]
	check(Sigils.of(a_end) >= 0 and Sigils.of(a_end) == Sigils.of(b_end), "both ends of a teleporter pair carry the same sigil")
	map.call("page", 1)
	await process_frame
	check(int(map.get("view")) == 2 and paused, "D turns to the worlds page")
	map.call("page", 1)
	check(int(map.get("view")) == 2, "and no further")
	map.call("page", -1)
	check(int(map.get("view")) == 1, "A turns back to the level")
	map.call("toggle")
	await process_frame
	check(int(map.get("view")) == 0 and not paused and not map.visible, "M again closes it, playing again")
	map.call("toggle")
	map.call("close")
	await process_frame
	check(int(map.get("view")) == 0 and not paused, "Menu closes it")

	print("the world view")
	info.record().lateral_open[MapInfo.Exit.RIGHT] = true
	info.record().deeper_paid = true
	info.travel(MapInfo.Exit.DEEPER)
	await settle()
	var links: Array = map.call("links", info)
	var pairs: Array = links.map(func(l: Array) -> String: return "%s>%s" % [l[0], l[1]])
	check(pairs.has("(28, 0)>(29, 0)") and pairs.has("(28, 0)>(28, 1)"), "links follow the opened side door and the paid deeper door: %s" % [pairs])
	check((map.call("tiles", info) as Dictionary).has(Vector2i(28, 1)) and (map.call("tiles", info) as Dictionary).has(Vector2i(29, 0)), "every visited level is a tile")

	finish()
