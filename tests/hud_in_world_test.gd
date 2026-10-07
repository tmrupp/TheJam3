extends TestKit
## What the HUD's plaques showed now lives in the game: sitting to count the stars carried and see
## the place, and the ghost's pointer at the edge of the view. Places print as marks and numbers,
## never words. The signpost (not placed in levels for now, kept for later) is checked on its own.
## godot --headless --path . --script res://tests/hud_in_world_test.gd


func run() -> void:
	await boot()
	var hud: RisoHud = main.get_node("RisoHud") as RisoHud
	await settle()
	check(not hud.coin_label.visible and not hud.world_label.visible and not hud.ghost_label.visible, "no standing plaques: no stars, place or ghost on screen")

	print("the signpost")
	check(placed("signpost.tscn").is_empty(), "levels place no signposts for now")
	var post: Signpost = (load("res://prefabs/signpost.tscn") as PackedScene).instantiate() as Signpost
	info.map_elements.add_child(post)
	post.global_position = player.global_position
	await settle()
	var start: Vector2 = player.global_position
	player.set_physics_process(false)
	player.global_position = post.global_position + Vector2(Signpost.READ_REACH.x * 3.0, 0)
	await process_frame
	await process_frame
	check(not post.reading, "from afar it is not read")
	player.global_position = post.global_position
	await process_frame
	await process_frame
	check(post.reading and not post.has_node("Interactable"), "standing by it reads it, with nothing to press")
	var art: SignArt = post.get_node_or_null("RisoArt") as SignArt
	check(art != null, "it is printed as a signpost")
	check(await until(func() -> bool: return art.open >= 1.0), "its card opens")
	var shown: Array[String] = []
	for label: Label in art.labels.slice(0, art.labels_used):
		shown.append(label.text)
	var n: Vector3i = Rules.place_numbers(info.coord)
	check(shown.has(str(n.x)) and shown.has(str(n.y)), "the card prints the world's and depth's numbers")
	check(shown.all(func(text: String) -> bool: return text.is_valid_int()), "and no words")
	player.global_position = post.global_position + Vector2(Signpost.READ_REACH.x * 3.0, 0)
	await process_frame
	await process_frame
	check(not post.reading, "walking away closes it")
	player.global_position = start
	player.set_physics_process(true)
	post.queue_free()
	await settle()

	print("sitting")
	var wizard: RisoWizard = player.get_node("RisoWizard") as RisoWizard
	var standing_head: float = wizard.costume.head_y
	Input.action_press(&"Down")
	check(await until(func() -> bool: return player.is_sitting()), "holding Down while standing still sits")
	check(await until(func() -> bool: return wizard.costume.seated() >= 1.0), "the Fool settles down")
	check(await until(func() -> bool: return hud.coin_label.visible), "once the view settles, a card shows")
	var shown_at: Vector2 = hud.coin_label.position
	await create_timer(0.5).timeout
	check(hud.coin_label.position == shown_at, "and holds still while the wizard sits")
	check(hud.coin_label.text == str(player.coins.coins), "sitting shows the stars carried")
	var here: Vector3i = Rules.place_numbers(info.coord)
	check(hud.world_label.text == str(here.x) and hud.depth_label.text == str(here.y), "and the place, as its world's and depth's numbers")
	check(wizard.costume.head_y - standing_head > RisoCostume.SIT_DROP * 0.7, "the head sits down with the body")
	Input.action_release(&"Down")
	check(await until(func() -> bool: return not player.is_sitting() and wizard.costume.seated() < 0.5), "letting go gets up")
	await process_frame
	check(not hud.coin_label.visible, "and the stars are put away")
	Input.action_press(&"Down")
	Input.action_press(&"Right")
	await create_timer(Player.SIT_DELAY * 2.0).timeout
	check(not player.is_sitting(), "walking while holding Down never sits")
	Input.action_release(&"Right")
	Input.action_release(&"Down")

	print("the ghost")
	info.run.leave_ghost(info.coord + Vector2i(0, 1), Vector2.ZERO, 7)
	await process_frame
	await process_frame
	check(hud.ghost_label.visible and hud.ghost_label.text == "7", "a ghost elsewhere: a pointer with its stars")
	var there: Vector3i = Rules.place_numbers(info.coord + Vector2i(0, 1))
	check(hud.ghost_world.visible and hud.ghost_world.text == str(there.x) and hud.ghost_depth.text == str(there.y), "and its place, as numbers")
	info.run.leave_ghost(info.coord, player.global_position + Vector2(5000, 0), 3)
	await process_frame
	await process_frame
	check(hud.ghost_label.visible and not hud.ghost_world.visible, "a ghost off screen here: a pointer, no place")
	info.run.leave_ghost(info.coord, player.global_position + Vector2(60, 0), 3)
	await process_frame
	await process_frame
	check(not hud.ghost_label.visible, "a ghost in view needs no pointer")
	info.run.clear_ghost()
	finish()
