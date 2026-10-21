extends TestKit
## What the wizard carries and how they climb, as printed (RisoWizard): an exam paper carried is
## written out in full (its sheet, its subject's mark and a pip a tier) on a canvas over the figure,
## in front of the bindle, while keys trail behind it; and on a rolling ladder the wizard climbs hand
## over hand, a hand always on one of its rungs, the hands and feet moving only while they climb
## and the pose gone once they let go.
## godot --headless --path . --script res://tests/wizard_carry_test.gd

var wizard: RisoWizard


func run() -> void:
	await boot()
	wizard = player.get_node("RisoWizard") as RisoWizard
	await _paper()
	await _climb()
	finish()


func _paper() -> void:
	print("a paper carried")
	check(wizard.papers.z_index > wizard.z_index and not wizard.papers.z_as_relative, "papers print over the figure and its bindle")
	check(wizard.world.z_index < wizard.z_index, "keys trail behind it")
	Abilities.set_tier(player, &"keyring", 1)
	player.keyring.set_all([1])
	await frames(3)
	check_eq(wizard.papers._used, 0, "a key alone puts nothing over the figure")
	var keys: int = wizard.world._used
	var paper: int = KeyRing.paper(&"slash", 2)
	player.keyring.set_all([1, paper])
	await frames(3)
	var used: int = wizard.papers._used
	check(used > 0, "a paper carried prints over the figure")
	# Its sheet, corner, mark and pips are the same ops as a paper lying waiting (RisoPrint.ink_paper).
	var lying: InkCanvas = InkCanvas.new()
	main.add_child(lying)
	lying.begin()
	RisoPrint.ink_paper(lying, paper, Vector2.ZERO, RisoWizard.CARRIED_PAPER, 0.0, RisoWizard.CARRIED_MARK)
	lying.finish()
	check_eq(used, lying._used, "written out in full, as one lying")
	lying.queue_free()
	player.keyring.set_all([1, KeyRing.paper(&"slash", 3)])
	await frames(3)
	check(wizard.papers._used == used, "a tier more is a pip more on the same ops")
	check(wizard.world._used == keys, "the key still trails behind")
	var hang: Vector2 = wizard.global_position + Vector2(signf(wizard.fs) * RisoWizard.KEY_HANG.x, RisoWizard.KEY_HANG.y) * player.global_scale.y * RisoWizard.ART_SCALE
	var bag: Vector2 = wizard.to_global(wizard.costume.bag_position())
	check(absf(hang.x - bag.x) > RisoWizard.CARRIED_PAPER * 10.0, "the newest hangs beside the bag, not over it")
	player.keyring.clear()


func _climb() -> void:
	print("climbing a ladder")
	var ladder: RollingLadder = null
	for world: int in [28, 7, 99, 3]:
		for k: int in range(3):
			info.coord = Vector2i(world, NextWorldDef.band_row(&"institute", k))
			info.arrival = MapInfo.Exit.BACK
			info._load_level()
			await settle()
			for node: Node in placed("rolling_ladder.tscn"):
				var found: RollingLadder = node as RollingLadder
				if found.rungs >= 4:
					ladder = found
					break
			if ladder != null:
				break
		if ladder != null:
			break
	check(ladder != null, "a ladder four cells long or more")
	if ladder == null:
		return
	for node: Node in info.map_elements.get_children():
		if node is Scholar or node is Abomination:
			node.queue_free()
	await physics_frame
	player.end_invulnerable()
	var lift: float = player._feet_y() - player.global_position.y
	player.global_position = Vector2(ladder.ladder_x(), ladder.foot_y() - 30.0 - lift)
	player.velocity = Vector2.ZERO
	Input.action_press(&"Up")
	await until(func() -> bool: return player.ladder == ladder, 3000)
	check(player.ladder == ladder, "up takes hold of the ladder")
	await within(func() -> bool: return wizard.rung > 0.99, 1.0)
	check(wizard.rung > 0.99, "the climbing pose blends in")
	var s: float = player.global_scale.y * RisoWizard.ART_SCALE
	var on_rung: bool = true
	var moved: bool = false
	var stepped: bool = false
	var hands: Array[Vector2] = wizard.climb_hands.duplicate()
	var feet: Array[Vector2] = wizard.climb_feet.duplicate()
	for i: int in range(30):
		await physics_frame
		if player.ladder != ladder:
			break
		# One hand or the other is on a real rung (or the step's top, near the top).
		var held: bool = false
		for hand: Vector2 in wizard.climb_hands:
			var y: float = wizard.global_position.y + hand.y * s
			var k: int = roundi((y - LadderArt.rung_y(ladder, 0)) / LadderArt.RUNG_GAP)
			held = held or absf(y - LadderArt.rung_y(ladder, k)) < 0.5 or absf(y - ladder.top_y()) < 0.5
		on_rung = on_rung and held
		moved = moved or wizard.climb_hands != hands
		stepped = stepped or wizard.climb_feet != feet
		hands = wizard.climb_hands.duplicate()
		feet = wizard.climb_feet.duplicate()
	check(on_rung, "a hand is always on a rung")
	check(moved and stepped, "climbing, the hands reach and the feet step")
	Input.action_release(&"Up")
	await physics_frame
	await physics_frame
	hands = wizard.climb_hands.duplicate()
	for i: int in range(10):
		await physics_frame
	check(player.ladder == ladder and wizard.climb_hands == hands, "holding still, the hands hold still")
	# Let go: a jump.
	Input.action_press(&"Jump")
	await physics_frame
	Input.action_release(&"Jump")
	await within(func() -> bool: return wizard.rung < 0.01, 1.0)
	check(player.ladder == null and wizard.rung < 0.01, "let go, the pose is gone")
