extends TestKit
## Focus transitions and lock hints. With a renderer, also saves review captures.

var camera: Camera2D
var output: String
## Frames a prompt is given to open or close, where nothing says when it has.
const PROMPT_FRAMES: int = 25


## Wait for the level, then hold the wizard still and free the camera of the level's limits.
func loaded() -> void:
	await settle(0)
	check(info.world != null and not info.travelling, "the level loads")
	player.set_physics_process(false)
	camera.limit_left = -1000000
	camera.limit_top = -1000000
	camera.limit_right = 1000000
	camera.limit_bottom = 1000000
	await frames(3)


func first(file: String) -> Node2D:
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == file:
			return node as Node2D
	return null

## How many other interactables stand within 200 px of `object`.
func crowd(object: Node) -> int:
	var n: int = 0
	for other: Node in get_nodes_in_group(&"interactables"):
		if not other.is_ancestor_of(object) and not object.is_ancestor_of(other) and (other as Node2D).global_position.distance_to((object as Node2D).global_position) < 200.0:
			n += 1
	return n

func focus(object: Node2D) -> Interactable:
	for node: Node in get_nodes_in_group(&"interactables"):
		(node as Interactable).touching = false
	# Stay close to bells so a nearby switch does not become the nearer interaction.
	var offset: float = -25.0 if object.scene_file_path.get_file() == "bell.tscn" else -55.0
	player.global_position = object.global_position + Vector2(offset, 0)
	camera.global_position = object.global_position + Vector2(0, -90)
	camera.reset_smoothing()
	var it: Interactable = object.get_node("Interactable") as Interactable
	it.touch(player)
	await frames(PROMPT_FRAMES)
	check(it.is_focused(), "%s gets sole interaction focus" % object.name)
	return it

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run() -> void:
	window()
	output = ProjectSettings.globalize_path("res://../art-captures/interaction-hints")
	DirAccess.make_dir_recursive_absolute(output)
	await boot()
	player = main.get_node("Player") as Player
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.invulnerable.enable()
	await loaded()
	await frames(PROMPT_FRAMES)

	var well: Node2D = first("inkwell.tscn")
	player.global_position = well.global_position + Vector2(-300, 0)
	camera.global_position = well.global_position + Vector2(0, -90)
	camera.reset_smoothing()
	await frames(PROMPT_FRAMES)
	var prompt: Node = well.get_node("RisoPrompt")
	check(not (prompt.get("hint_label") as Label).visible, "map price hidden outside interaction focus")
	await shot("inkwell_idle")
	var it: Interactable = await focus(well)
	check(it.prompt_hint().get("text") == "map · %d" % int(well.call("price")), "generic hint contains current map price")
	check((prompt.get("hint_label") as Label).visible, "map price pops up for the focused inkwell")
	await shot("inkwell_focused")
	player.global_position = well.global_position + Vector2(-300, 0)
	it.untouch(player)
	await until(func() -> bool: return not (prompt.get("hint_label") as Label).visible)
	check(not (prompt.get("hint_label") as Label).visible, "price closes after leaving")
	player.collect(100)
	well.call("buy")
	await until(func() -> bool: return not it.available)
	check(not it.available, "paid inkwell has no further interaction")

	var door: Node2D = first("door.tscn")
	it = await focus(door.get_node("Unlock") as Node2D)
	check(int(it.prompt_hint().get("key_color", -1)) == int(door.get_meta(&"key_color")), "portcullis exposes its key requirement")
	await shot("portcullis_key")
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() == "level_exit.tscn" and int(node.call("lock")) >= 0:
			it = await focus(node as Node2D)
			check(int(it.prompt_hint().get("key_color", -1)) == int(node.call("lock")), "lateral door exposes its key requirement")
			await shot("lateral_padlock")
			break

	Abilities.grant(player, &"keyring")
	Abilities.grant(player, &"keyring")
	Abilities.grant(player, &"keyring")
	player.keyring.set_all([0, 1, 2, 3])
	# Keep the whole trailing ring against open sky for the size comparison.
	player.global_position = Vector2(-2000, -2000)
	camera.global_position = player.global_position + Vector2(0, -90)
	camera.reset_smoothing()
	await frames(90)
	await shot("equal_keyring")
	player.keyring.set_all([])
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await loaded()
	var captured: Dictionary = {}
	# Bells with nothing else to interact with close by first, so focus is the bell's alone.
	var bells: Array[Node] = info.map_elements.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.get_file() == "bell.tscn")
	bells.sort_custom(func(a: Node, b: Node) -> bool: return crowd(a) < crowd(b))
	for node: Node in bells:
		# A bell whose chasm is already bridged (its partner rung) has nothing left to do.
		if bool(node.call("rung")):
			continue
		var lock: int = int(node.get("lock"))
		var kind: String = "switch" if lock < 0 else "key"
		if captured.has(kind):
			continue
		captured[kind] = true
		var chained_by: Vector2i = (node as Bell).switch_cell
		if lock < 0:
			# Chained to start with (some switches start on).
			info.set_switch(chained_by, false)
		it = await focus(node as Node2D)
		check(bool(it.prompt_hint().get("switch", false)) if lock < 0 else int(it.prompt_hint().get("key_color", -1)) == lock, "chained bell shows its %s requirement" % kind)
		await shot("bell_" + kind)
		if lock < 0:
			info.set_switch(chained_by, true)
			(node as Bell).switched(true)
		else:
			node.call("open")
		await until(func() -> bool: return it.prompt_hint().is_empty())
		check(it.prompt_hint().is_empty(), "freed bell returns to the ring interaction")
		node.call("ring")
		await until(func() -> bool: return not it.available)
		check(not it.available, "rung bell hides its prompt")
	check(captured.has("key") and captured.has("switch"), "covered both bell lock types")
	finish()
