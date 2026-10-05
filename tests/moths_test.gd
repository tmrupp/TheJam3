extends SceneTree
## Moths follow a nearby wizard's lit spell orb, prefer it over a lit lantern, and
## scatter harmlessly when a real dash crosses them. They gather again rather than dying.
## godot --headless --path . --script res://tests/moths_test.gd

var failed: bool = false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame


func run() -> void:
	seed(28)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	MapInfo.save_path = "user://moths_test.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	await frames(4)
	var player: Player = main.get_node("Player") as Player
	player.set_physics_process(false)
	var lantern: Node = null
	for node: Node in info.map_elements.get_children():
		if node is Checkpoint and not info.is_lantern_spent(node):
			lantern = node
			break
	check(lantern != null and info.light_lantern(lantern), "a lantern is lit")
	if lantern == null:
		quit(1)
		return
	var glass: Vector2 = info.cell_position(info.respawn_cell) + MothSwarm.GLASS
	var swarm: MothSwarm = load("res://prefabs/moths.tscn").instantiate() as MothSwarm
	swarm.position = glass + Vector2(300, 0)
	main.add_child(swarm)
	swarm.set_physics_process(false)
	player.global_position = glass + Vector2(0, -1500)
	check(swarm.target() == glass and swarm.drawn_to == &"lantern", "a distant wizard leaves the swarm drawn to the lantern")
	check(Abilities.spell(player) == &"", "the wizard has no spell equipped")
	player.global_position = swarm.global_position + Vector2(400, 70)
	check(swarm.target() == glass and swarm.drawn_to == &"lantern", "without a spell, a nearby wizard does not distract moths from the lantern")
	var was_vulnerable: bool = info.vulnerable
	info.vulnerable = true
	check(swarm.target() == swarm.home and swarm.drawn_to == &"home", "without a spell or lit lantern, the swarm stays home")
	info.vulnerable = was_vulnerable
	Abilities.grant(player, &"hex")
	var toward: Vector2 = swarm.target()
	check(swarm.drawn_to == &"orb" and toward == player.global_position + Vector2(0, -70), "equipping a spell makes the nearby orb take priority over the lantern")
	player.drowsy = Player.DROWSY_LINGER
	check(swarm.target() == glass and swarm.drawn_to == &"lantern", "a spell dimmed by sleep fog does not draw moths")
	player.drowsy = 0.0
	var before: float = swarm.global_position.distance_to(toward)
	swarm._physics_process(0.5)
	check(swarm.global_position.distance_to(toward) < before, "the swarm moves toward the wizard carrying a spell")
	player.global_position += Vector2(0, 200)
	toward = swarm.target()
	before = swarm.global_position.distance_to(toward)
	swarm._physics_process(0.5)
	check(swarm.global_position.distance_to(toward) < before, "it follows when the wizard moves")
	Abilities.set_tier(player, &"hex", 0)
	check(swarm.target() == glass and swarm.drawn_to == &"lantern", "removing the spell ends the chase")

	print("dashing through moths")
	swarm.global_position = Vector2(-10000, -10000)
	swarm.home = swarm.global_position
	player.global_position = swarm.global_position + Vector2(-120, 40)
	player.velocity = Vector2.ZERO
	player.end_invulnerable()
	player.dash.end()
	player.dash.refresh()
	player.dash_rest = 0.0
	var hp: int = player.health.health
	player.set_physics_process(true)
	Input.action_press(&"Right")
	var press: InputEventAction = InputEventAction.new()
	press.action = &"Dash"
	press.pressed = true
	Input.parse_input_event(press)
	await frames(10)
	Input.action_release(&"Dash")
	Input.action_release(&"Right")
	var strike: DashStrike = player.get_node("DashStrike") as DashStrike
	check(swarm.is_scattered() and swarm in strike.struck, "a real dash scatters the swarm")
	player.hurt(-1, Vector2.RIGHT, swarm)
	check(strike.guards(swarm) and player.health.health == hp, "moths cannot sting through the dash")
	var scatter_left: float = swarm.scattered
	strike.sweep(swarm.global_position - Vector2(100, 0), swarm.global_position + Vector2(100, 0))
	check(swarm.scattered == scatter_left, "the swarm is hit only once per dash")
	player.set_physics_process(false)
	player.global_position = swarm.global_position + Vector2(1500, 0)
	swarm._physics_process(MothSwarm.SCATTER_TIME + 0.1)
	check(not swarm.is_scattered() and not swarm.is_queued_for_deletion(), "the swarm gathers again after six seconds")
	player.dash.end()
	strike.guard_left = 0.0
	check(not strike.guards(swarm), "the moths can sting again once the dash and guard end")
	MapInfo.delete_save()
	print("FAILED" if failed else "PASS: moth chase and dash")
	quit(1 if failed else 0)
