extends SceneTree
## The spell slot (one spell at a time on the Spell button), levitate and awareness, and plants
## and lanterns swaying as the wizard passes.
## godot --headless --path . --script res://tests/spells_test.gd

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


func settle() -> void:
	await process_frame
	while info.world == null or info.travelling:
		await process_frame
	for i: int in range(4):
		await physics_frame
		await process_frame


func run() -> void:
	main = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://test_run.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	player = main.get_node("Player") as Player
	await settle()

	print("the spell slot")
	check(InputMap.has_action(Abilities.SPELL_ACTION), "one Spell button")
	check(Abilities.spell(player) == &"hex" and player.has_node("Hex"), "the slot starts with the hex")
	for a: StringName in Abilities.SPELLS:
		Abilities.grant(player, a)
		var held: int = Abilities.SPELLS.filter(func(s: StringName) -> bool: return Abilities.tier(player, s) > 0).size()
		check(Abilities.spell(player) == a and held == 1, "learning %s puts it in the slot, alone" % a)
	check(not player.has_node("Hex") and not player.has_node("Levitate") and not player.has_node("Awareness") and player.has_node("Rift"), "only the slotted spell's node remains")

	print("levitate")
	Abilities.grant(player, &"levitate")
	var lev: Levitate = player.get_node("Levitate") as Levitate
	check(not lev.drift and not lev.free_recast, "levitate I holds height, without drift")
	player.global_position += Vector2(0, -260)
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	Abilities.cast(player)
	check(lev.floating() and not lev.charged, "Spell in the air: floating")
	var y0: float = player.global_position.y
	for i: int in range(150):
		await physics_frame
	check(lev.floating() and absf(player.global_position.y - y0) < 1.0, "holds its height until turned off, well past 1.5 s (moved %.1f px)" % absf(player.global_position.y - y0))
	Abilities.cast(player)
	check(not lev.floating(), "Spell again: drop")
	Abilities.cast(player)
	check(not lev.floating(), "one float per landing")
	var moon: Node = info.map_elements.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.get_file() == "moon.tscn")[0]
	player.dash.refresh()
	moon.call("touch", player)
	check(lev.charged, "a moon brings the float back")
	var deadline: int = Time.get_ticks_msec() + 5000
	while not player.is_on_floor() and Time.get_ticks_msec() < deadline:
		await physics_frame
	await physics_frame
	check(lev.charged and not lev.floating(), "landing recharges it")
	Abilities.grant(player, &"levitate")
	check(lev.drift and not lev.free_recast, "levitate II drifts with the stick")
	Abilities.grant(player, &"levitate")
	check(lev.free_recast, "levitate III recasts without landing")

	print("speed")
	check(is_equal_approx(player.run_speed, Player.SPEED), "base run speed without the perk")
	Abilities.grant(player, &"speed")
	Abilities.grant(player, &"speed")
	check(is_equal_approx(player.run_speed, Player.SPEED * 1.3) and Abilities.spell(player) == &"levitate", "speed II runs 30% faster and leaves the spell slot alone")

	print("awareness")
	Abilities.grant(player, &"awareness")
	var aware: Awareness = player.get_node("Awareness") as Awareness
	var kinds: Callable = func() -> Dictionary:
		var out: Dictionary = {}
		for target: Dictionary in aware.targets():
			out[target["kind"]] = true
		return out
	check(not aware.active(), "quiet until pinged")
	Abilities.cast(player)
	check(aware.active() and kinds.call().has(&"exit") and not kinds.call().has(&"inkwell"), "awareness I: senses the exits")
	Abilities.cast(player)
	check(aware.cooldown > aware.sensing, "pinging again waits for the cooldown")
	Abilities.grant(player, &"awareness")
	check(kinds.call().has(&"inkwell") and kinds.call().has(&"shrine"), "awareness II: also the ink well and the shrine")
	Abilities.grant(player, &"awareness")
	check(kinds.call().has(&"key"), "awareness III: also the keys")
	await create_timer(0.3).timeout
	var hud: Node = main.get_node("RisoHud")
	check(hud != null, "the HUD draws the pointers")

	print("swaying")
	var decor: RisoDecor = main.get_node("RisoDecor") as RisoDecor
	check(decor.swaying.size() > 50, "%d plants sway" % decor.swaying.size())
	var plant: int = -1
	for index: int in decor.swaying:
		if decor.items[index]["kind"] == &"tuft":
			plant = index
			break
	var anchor: Vector2 = decor.items[plant]["anchor"]
	player.set_physics_process(false)
	player.global_position = anchor + Vector2(-40, -40)
	player.velocity = Vector2(300, 0)
	var cam: Camera2D = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	cam.global_position = anchor
	var most: float = 0.0
	for i: int in range(30):
		await process_frame
		most = maxf(most, absf(decor.lean(plant)))
	check(most > 0.08 and most < 0.3, "walking past nudges a tuft (lean %.2f)" % most)
	player.global_position = anchor + Vector2(-2000, -2000)
	player.velocity = Vector2.ZERO
	var low: float = 0.0
	var high: float = 0.0
	for i: int in range(300):
		await process_frame
		low = minf(low, decor.lean(plant))
		high = maxf(high, decor.lean(plant))
	check(high - low < 0.4, "it eases back (%.2f to %.2f)" % [low, high])
	check(absf(decor.lean(plant)) < 0.05, "and settles")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: spells and sway")
		quit()
