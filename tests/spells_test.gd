extends TestKit
## The slots (one ability at a time in each: damage on the Spell button, movement on the Dash
## button, utility on the Utility button), levitate cast from the Dash button and awareness from
## the Utility button, and plants and lanterns swaying as the wizard passes.
## godot --headless --path . --script res://tests/spells_test.gd


func run() -> void:
	await boot()

	print("the slots")
	check(InputMap.has_action(Abilities.SPELL_ACTION) and InputMap.has_action(&"Dash") and InputMap.has_action(Abilities.UTILITY_ACTION), "a button for each slot")
	check(Abilities.spell(player, &"damage") == &"parry" and Abilities.spell(player, &"move") == &"dash" and Abilities.spell(player, &"utility") == &"" and not player.has_node("Hex"), "parry and the dash to start with, no utility")
	for a: StringName in Abilities.ids():
		var slot: StringName = Abilities.slot_of(a)
		if slot == &"":
			continue
		var before: Dictionary = {}
		for other: StringName in Abilities.SLOTS:
			before[other] = Abilities.spell(player, other)
		Abilities.grant(player, a)
		var held: int = Abilities.in_slot(slot).filter(func(s: StringName) -> bool: return Abilities.tier(player, s) > 0).size()
		var others_kept: bool = Abilities.SLOTS.all(func(other: StringName) -> bool: return other == slot or Abilities.spell(player, other) == before[other])
		check(Abilities.spell(player, slot) == a and held == 1 and others_kept, "learning %s puts it in the %s slot, alone, the others kept" % [a, slot])
	check(player.has_node("Push") and player.has_node("Ferry") and player.has_node("Mend"), "each slot's last learned node is there")
	check(not player.has_node("Hex") and not player.has_node("Slash") and not player.has_node("Nova") and not player.has_node("Levitate") and not player.has_node("Awareness") and not player.has_node("Rift") and not player.has_node("Warp") and not player.has_node("Blink"), "and only those")
	check(Abilities.tier(player, &"dash") == 0 and not player.dashes(), "the dash went with the movement slot")

	print("levitate")
	Abilities.grant(player, &"levitate")
	var lev: Levitate = player.get_node("Levitate") as Levitate
	check(not lev.drift and not lev.free_recast, "levitate I holds height, without drift")
	player.global_position += Vector2(0, -260)
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	_press(&"Dash")
	await frames(2)
	_release(&"Dash")
	check(lev.floating() and not lev.charged, "the Dash button in the air: floating")
	var y0: float = player.global_position.y
	for i: int in range(150):
		await physics_frame
	check(lev.floating() and absf(player.global_position.y - y0) < 1.0, "holds its height well past 1.5 s (moved %.1f px)" % absf(player.global_position.y - y0))
	check(is_equal_approx(Levitate.FLOAT_TIME, 6.0) and lev.remaining > 3.0 and lev.remaining < Levitate.FLOAT_TIME, "the six-second float counts down")
	var running: Vector2 = Abilities.running(player, &"move")
	check(running.x < 1.0 and is_equal_approx(running.y, lev.remaining), "the slot shows the float's remaining time")
	Abilities.cast(player, &"move")
	check(not lev.floating(), "again: drop")
	Abilities.cast(player, &"move")
	check(not lev.floating(), "one float per landing")
	var moon: Node = info.map_elements.get_children().filter(func(n: Node) -> bool: return n.scene_file_path.get_file() == "moon.tscn")[0]
	player.dash.refresh()
	moon.call("touch", player)
	check(lev.charged, "a moon brings the float back")
	lev.start()
	lev.elapse(Levitate.FLOAT_TIME - 0.1)
	check(lev.floating(), "a float lasts almost six seconds")
	lev.elapse(0.2)
	check(not lev.floating() and not lev.charged and lev.remaining == 0.0, "running out ends the float without recharging it")
	# Land on a known floor rather than hoping the generated cave has one under the float.
	var returned_to: Vector2 = player.global_position
	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.collision_layer = 4
	floor_body.collision_mask = 0
	var floor_shape: CollisionShape2D = CollisionShape2D.new()
	var floor_rect: RectangleShape2D = RectangleShape2D.new()
	floor_rect.size = Vector2(256, 32)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	main.add_child(floor_body)
	floor_body.global_position = Vector2(-10000, -9900)
	player.global_position = Vector2(-10000, -10000)
	player.velocity = Vector2.ZERO
	await until(func() -> bool: return player.is_on_floor() and lev.charged and not lev.floating())
	check(player.is_on_floor() and lev.charged and not lev.floating(), "landing recharges it")
	player.global_position = returned_to
	player.velocity = Vector2.ZERO
	floor_body.queue_free()
	Abilities.grant(player, &"levitate")
	check(lev.drift and not lev.free_recast, "levitate II drifts with the stick")
	Abilities.grant(player, &"levitate")
	check(lev.free_recast, "levitate III recasts without landing")
	lev.start()
	lev.elapse(Levitate.FLOAT_TIME)
	check(not lev.floating() and lev.charged, "tier III still expires and permits a new float")

	print("speed")
	check(is_equal_approx(player.run_speed, Player.SPEED), "base run speed without the perk")
	Abilities.grant(player, &"speed")
	Abilities.grant(player, &"speed")
	check(is_equal_approx(player.run_speed, Player.SPEED * 1.3) and Abilities.spell(player, &"move") == &"levitate", "speed II runs 30% faster and leaves the slots alone")

	print("awareness")
	Abilities.grant(player, &"awareness")
	var aware: Awareness = player.get_node("Awareness") as Awareness
	var kinds: Callable = func() -> Dictionary:
		var out: Dictionary = {}
		for target: Dictionary in aware.targets():
			out[target["kind"]] = true
		return out
	check(not aware.active(), "quiet until pinged")
	_press(Abilities.UTILITY_ACTION)
	await frames(2)
	_release(Abilities.UTILITY_ACTION)
	check(aware.active() and kinds.call().has(&"exit") and not kinds.call().has(&"inkwell"), "awareness I, from the Utility button: senses the exits")
	var fizzled: Array[bool] = [false]
	var on_event: Callable = func(kind: StringName, _at: Vector2) -> void:
		if kind == &"fizzle":
			fizzled[0] = true
	player.visual_event.connect(on_event)
	_press(Abilities.UTILITY_ACTION)
	await frames(2)
	_release(Abilities.UTILITY_ACTION)
	player.visual_event.disconnect(on_event)
	check(aware.cooldown > aware.sensing and fizzled[0], "pinging again waits for the cooldown, and the press sputters")
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

	finish()


## Press, and let go of, `action`.
func _press(action: StringName) -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)


func _release(action: StringName) -> void:
	Input.action_release(action)
