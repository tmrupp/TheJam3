extends SceneTree
## Astral projection as an ability (toggle out and back; hurt snaps you back; running out
## leaves you where the projection is) and moons as dash resets.
## godot --headless --path . --script res://tests/astral_moon_test.gd

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
	player.set_physics_process(false)

	print("astral projection")
	var astral: AstralProjection = player.get_node("AstralProjection") as AstralProjection
	check(InputMap.has_action(Abilities.SPELL_ACTION), "the Spell action exists")
	check(info.map_elements.get_children().all(func(n: Node) -> bool: return n.scene_file_path.get_file() != "astral_projection_point.tscn"), "no astral orbs in the level")
	astral.toggle()
	check(not astral.projecting(), "locked until learned")
	Abilities.grant(player, &"astral")
	var home: Vector2 = player.position
	astral.toggle()
	check(astral.projecting(), "tap: projecting, body left behind")
	player.position += Vector2(300, -40)
	astral.toggle()
	check(not astral.projecting() and player.position == home, "tap again: back in the body")
	astral.toggle()
	player.position += Vector2(200, 0)
	player.hurt(-1, Vector2.RIGHT, null)
	check(not astral.projecting() and player.position == home and player.health.health == player.health.max_health, "hurt while projected: back in the body, unhurt")
	astral.toggle()
	var away: Vector2 = home + Vector2(250, -30)
	player.position = away
	astral.projection_timer.elapse(astral.projection_timer.MAX_TIME + 0.1)
	check(not astral.projecting() and player.position == away, "run out: stay where the projection is")
	check(player.hurt_ability == player.normal_hurt and player.get_collision_layer_value(6), "and vulnerable again")

	print("moons")
	var moons: Array[Node] = info.map_elements.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.get_file() == "moon.tscn")
	check(not moons.is_empty() and moons.size() <= info.world.per_area(MapInfo.MOONS_PER_K), "%d moons within the level's area budget" % moons.size())
	if moons.is_empty():
		quit(1)
		return
	var moon: Node = moons[0]
	player.dash.refresh()
	moon.call("touch", player)
	check(bool(moon.call("is_full")), "with the dash unused, a moon is left alone")
	player.dash.end()
	player.dash.enable()
	check(player.dash.acted, "dash spent")
	moon.call("touch", player)
	check(not player.dash.acted and not bool(moon.call("is_full")), "a moon gives the dash back and wanes")
	player.dash.end()
	player.dash.enable()
	moon.call("touch", player)
	check(player.dash.acted, "a waning moon does nothing")
	player.global_position = Vector2(-9000, -9000)
	await create_timer(2.8).timeout
	check(bool(moon.call("is_full")), "and it comes back")
	info.travel(MapInfo.Exit.RIGHT)
	await settle()
	info.travel(MapInfo.Exit.LEFT)
	await settle()
	check(info.map_elements.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.get_file() == "moon.tscn").size() == moons.size(), "moons are never used up")

	if failed:
		print("FAILED")
		quit(1)
	else:
		print("PASS: astral and moons")
		quit()
