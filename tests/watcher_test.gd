extends TestKit
## The watcher's eye charges (opens) only while it can see the wizard, fires when full, and
## resets the moment it loses sight.
## godot --headless --path . --script res://tests/watcher_test.gd



func run() -> void:
	await boot(28)
	player.set_physics_process(false)
	# A watcher with open air beside it, to stand in its view.
	var shooter: Shooter = null
	var spot: Vector2 = Vector2.ZERO
	for n: Node in info.map_elements.get_children():
		if n.scene_file_path.get_file() != "shooter_enemy.tscn":
			continue
		var c: Vector2i = n.get_meta(&"cell")
		for d: int in [-1, 1]:
			if info.world.get_cell(c + Vector2i(d, 0)).type != LevelGen.Type.GROUND and info.world.get_cell(c + Vector2i(2 * d, 0)).type != LevelGen.Type.GROUND:
				shooter = n.get_node("Shooter") as Shooter
				spot = info.cell_position(c + Vector2i(2 * d, 0))
				break
		if shooter != null:
			break
	check(shooter != null, "found a watcher with a clear view")
	player.global_position = Vector2(-9000, -9000)
	for i: int in range(10):
		await physics_frame
	check(shooter.charge == 0.0 and not shooter.sees, "out of sight: no charge")
	player.global_position = spot
	for i: int in range(40):
		await physics_frame
	var mid: float = shooter.charge
	check(shooter.sees and mid > 0.1 and mid < 1.0, "in sight: the eye charges slowly (%.2f after 40 frames)" % mid)
	player.global_position = Vector2(-9000, -9000)
	for i: int in range(4):
		await physics_frame
	check(shooter.charge == 0.0, "losing sight resets the charge")
	player.global_position = spot
	var fired: bool = false
	for i: int in range(int(shooter.cooldown * 60.0) + 30):
		await physics_frame
		if (shooter.get_node("AudioStreamPlayer") as AudioStreamPlayer).playing:
			fired = true
			break
	check(fired, "kept in sight, it fires when fully charged")
	finish()
