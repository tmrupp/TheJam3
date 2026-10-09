extends TestKit
## Moths follow the lantern a nearby wizard carries while it is lit, prefer it over the lit lantern
## itself, ignore the spell orb, stay home with no lantern lit, and scatter harmlessly when a real
## dash crosses them. They gather again rather than dying.
## godot --headless --path . --script res://tests/moths_test.gd

func run() -> void:
	seed(28)
	await boot(28)
	player.set_physics_process(false)
	var lantern: Node = null
	for node: Node in info.map_elements.get_children():
		if node is Checkpoint and not info.is_lantern_spent(node):
			lantern = node
			break
	check(lantern != null and info.light_lantern(lantern), "a lantern is lit")
	if lantern == null:
		finish()
		return
	var glass: Vector2 = info.cell_position(info.run.respawn_cell) + MothSwarm.GLASS
	var swarm: MothSwarm = load("res://prefabs/moths.tscn").instantiate() as MothSwarm
	swarm.position = glass + Vector2(300, 0)
	main.add_child(swarm)
	swarm.set_physics_process(false)
	player.global_position = glass + Vector2(0, -1500)
	check(swarm.target() == glass and swarm.drawn_to == &"lantern", "a distant wizard leaves the swarm drawn to the lantern")
	player.global_position = swarm.global_position + Vector2(400, 70)
	var toward: Vector2 = swarm.target()
	check(swarm.drawn_to == &"carried" and toward == player.global_position + MothSwarm.CARRIED, "near by, the wizard's lit lantern takes priority over the lantern itself")
	Abilities.set_tier(player, &"parry", 0)
	check(Abilities.spell(player) == &"" and swarm.drawn_to == &"carried" and swarm.target() == toward, "with no spell equipped, the lit lantern still draws them")
	Abilities.grant(player, &"hex")
	var before: float = swarm.global_position.distance_to(toward)
	swarm._physics_process(0.5)
	check(swarm.global_position.distance_to(toward) < before, "the swarm moves toward the wizard's lantern")
	player.global_position += Vector2(0, 200)
	toward = swarm.target()
	before = swarm.global_position.distance_to(toward)
	swarm._physics_process(0.5)
	check(swarm.global_position.distance_to(toward) < before, "it follows when the wizard moves")
	var was_vulnerable: bool = info.run.vulnerable
	info.run.vulnerable = true
	check(swarm.target() == swarm.home and swarm.drawn_to == &"home", "with no lantern lit, a nearby wizard and their spell orb leave the swarm home")
	info.run.vulnerable = was_vulnerable
	Abilities.set_tier(player, &"hex", 0)

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
	RunState.delete_save()
	finish("moth chase and dash")
