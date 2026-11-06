extends TestKit
## Silenced: drowsy (sleep fog, a librarian's hush: Player.make_drowsy), a spell's button casts
## nothing but shows it silenced (the "silenced" visual event: a dead puff from the bag), and a
## spell running when the wizard becomes drowsy is cut off with the same sign. Awake, a cast shows
## none.
## godot --headless --path . --script res://tests/silenced_test.gd


func run() -> void:
	await boot()
	var events: Array[StringName] = []
	player.visual_event.connect(func(kind: StringName, _at: Vector2) -> void: events.append(kind))
	check(Abilities.spell(player) != &"", "a damage spell in its slot (%s)" % Abilities.spell(player))

	print("pressed while drowsy")
	events.clear()
	await press(&"Spell")
	check(not events.has(&"silenced"), "awake, a cast is not silenced")
	await within(func() -> bool: return Abilities.readiness(player) >= 1.0, 3.0)
	player.make_drowsy()
	events.clear()
	await press(&"Spell")
	check(events.has(&"silenced") and not events.has(&"cast"), "drowsy, the Spell button casts nothing and shows it silenced: %s" % [events])

	print("cut off mid-spell")
	await within(func() -> bool: return not player.is_drowsy(), 1.0)
	player.levitating = true
	events.clear()
	player.make_drowsy()
	check(not player.levitating and events.has(&"silenced"), "becoming drowsy ends a levitation, and shows it silenced")
	events.clear()
	player.make_drowsy()
	check(not events.has(&"silenced"), "staying drowsy, with nothing running, shows nothing more")
	RunState.delete_save()
	finish()


## Press and let go of `action`, a physics frame or two apart.
func press(action: StringName) -> void:
	var down: InputEventAction = InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await physics_frame
	await physics_frame
	var up: InputEventAction = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await physics_frame
