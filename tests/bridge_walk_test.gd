extends TestKit
## Walking a chasm's bridge (Bridge): in the dark, laid, the wizard walks from one shore to the
## other and back without catching on the joins between its planks, however it sags.
## godot --headless --path . --script res://tests/bridge_walk_test.gd

## How many frames a walk across may take before it counts as stuck.
const WALK_FRAMES: int = 360


func run() -> void:
	if not needs([&"cemetery"]):
		finish()
		return
	await boot()
	var walked: int = 0
	for k: int in range(2):
		info.coord = Vector2i(28, NextWorldDef.band_row(&"cemetery", k))
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.set_physics_process(false)
		player.invulnerable.enable()
		for id: int in range(info.world.chasms.size()):
			if info.world.relic_chasms.has(id):
				continue
			info.ring_bell(id)
			info.snuff(player.global_position)
			var planks: Array[Node] = placed("bridge.tscn", true).filter(func(n: Node) -> bool: return (n as Bridge).chasm == id)
			if planks.is_empty():
				continue
			await until(func() -> bool: return planks.all(func(n: Node) -> bool: return (n as Bridge).bears()))
			await frames(2)
			var gap: Dictionary = info.world.chasms[id]
			var left: Vector2 = info.cell_position((gap["left"] as Vector2i) + Vector2i.UP)
			var right: Vector2 = info.cell_position((gap["right"] as Vector2i) + Vector2i.UP)
			# Only the bridge is being walked: anything that moves and stands in the way (enemies are
			# solid to the wizard) is taken away first.
			for n: Node in info.map_elements.get_children():
				var at: Node2D = n as Node2D
				var moves: bool = n is CharacterBody2D or n is RigidBody2D or n.has_node("Wound")
				if moves and absf(at.global_position.y - left.y) < 600.0 and absf(at.global_position.x - (left.x + right.x) * 0.5) < 1600.0:
					n.free()
			var there: float = await walk(left, right.x, &"Right")
			check(there >= right.x - 8.0, "level %s, chasm %d: walked right across its %d planks (reached %.0f of %.0f)" % [info.coord, id, planks.size(), there, right.x])
			var back: float = await walk(right, left.x, &"Left")
			check(back <= left.x + 8.0, "level %s, chasm %d: and back left (reached %.0f of %.0f)" % [info.coord, id, back, left.x])
			walked += 1
	check(walked >= 2, "walked %d bridges" % walked)
	RunState.delete_save()
	finish()


## Stand the wizard at `from`, hold `action` until they pass `to` (or WALK_FRAMES run out), and
## return how far along they got.
func walk(from: Vector2, to: float, action: StringName) -> float:
	player.global_position = from
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await frames(6)
	Input.action_press(action)
	var sign: float = 1.0 if action == &"Right" else -1.0
	var best: float = player.global_position.x
	for i: int in range(WALK_FRAMES):
		await physics_frame
		best = maxf(best, player.global_position.x) if sign > 0.0 else minf(best, player.global_position.x)
		if (player.global_position.x - to) * sign >= 0.0:
			break
	Input.action_release(action)
	player.set_physics_process(false)
	return best
