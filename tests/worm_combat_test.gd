extends TestKit
## Real dash inputs against the worm's solid body, bite recovery, round head and bite shapes,
## and an awakened worm staying active when its original burrow's chunk goes to sleep.
## godot --headless --path . --script res://tests/worm_combat_test.gd


func run() -> void:
	await boot(28)
	info.coord = Vector2i(28, NextWorldDef.GARDEN_ROWS)
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	var worm: Worm = placed("worm.tscn")[0] as Worm
	var far: Variant = LevelGen.best_of(info.world.free_floors(), func(v: Vector2i) -> int: return -LevelGen.dist(v, worm.home))
	player.global_position = info.cell_position(far as Vector2i)
	info.loader.sleep_far_chunks(true, player.global_position)
	check(not worm.awake and worm.process_mode == Node.PROCESS_MODE_DISABLED, "a dormant worm still sleeps in a distant chunk")
	player.global_position = worm.center(worm.home)
	info.loader.sleep_far_chunks(true, player.global_position)
	check(await until(func() -> bool: return worm.pieces[0].segments[0].live, 15000), "it wakes and comes out")
	var p: Worm.Piece = worm.pieces[0]
	player.global_position = info.cell_position(far as Vector2i)
	info.loader.sleep_far_chunks(true, player.global_position)
	check(not info.loader.is_awake(worm) and worm.visible and worm.process_mode == Node.PROCESS_MODE_INHERIT, "the original burrow sleeps, but the awakened worm stays visible and active")
	var was_u: float = p.u
	check(await until(func() -> bool: return p.u != was_u, 2000), "it keeps crawling while far from its original burrow")
	worm.set_physics_process(false)
	# A real collider outside the terrain: only this head is live, and gravity is off so each dash
	# meets the same solid edge without a floor, other segments or chunk sleeping affecting it.
	worm.remove_meta(&"cell")
	var head: WormSegment = p.segments[0]
	for segment: WormSegment in p.segments:
		segment.set_live(false)
		segment.sync_touch()
	var test_at: Vector2 = Vector2(-10000, -10000)
	head.global_position = test_at
	head.set_live(true)
	head.sync_touch()
	player.gravity = 0.0
	player.health.max_health = 99
	player.health.health = 99
	player.set_collision_mask_value(WormSegment.WORM_LAYER, true)
	var circle: CircleShape2D = head.bite.collision.shape as CircleShape2D
	check(circle != null and is_equal_approx(circle.radius, head.radius) and head.bite.scale == Vector2.ONE, "the bite and the solid head have the same round edge")
	var mouth_flesh: Array[PackedVector2Array] = worm._bite_out([RisoShapes.circle(test_at, head.radius)], worm._jaw(head, head.radius * 2.0, false, test_at))
	var rear: Vector2 = test_at - head.heading * head.radius * 0.8
	var nose: Vector2 = test_at + head.heading * head.radius * 0.8
	check(mouth_flesh.any(func(poly: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(rear, poly)) and not mouth_flesh.any(func(poly: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(nose, poly)), "the Pac-Man mouth cuts open the front while keeping the back of the round head")
	check(mouth_flesh.any(func(poly: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(test_at, poly)), "the shallow mouth leaves flesh across the head's middle, clear of its health dots")
	var strike: DashStrike = player.get_node("DashStrike") as DashStrike
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]:
		head.global_position = test_at
		head.wound.hp = Worm.SEGMENT_HP
		player.global_position = test_at - direction * 150.0
		player.velocity = Vector2.ZERO
		player.knock = Vector2.ZERO
		player.knock_back.end()
		player.dash.end()
		player.dash.refresh()
		player.dash_rest = 0.0
		await frames(3)
		player.set_physics_process(true)
		var blocked: bool = await _dash(direction)
		player.set_physics_process(false)
		check(head.wound.hp == Worm.SEGMENT_HP - 1 and blocked, "a solid edge blocks the dash but takes exactly one hit, heading %s (hp %d, blocked %s)" % [direction, head.wound.hp, blocked])
		check(not head.stunned() and player.health.health == 99, "the dash neither stuns the worm nor hurts the wizard")
		await frames(20)
	# A blink's virtual path also uses the body, without striking a nearby segment it misses.
	head.global_position = test_at
	head.wound.hp = Worm.SEGMENT_HP
	strike.struck.clear()
	var miss_height: float = head.radius + player.collider.shape.get_rect().size.y * player.collider.global_scale.y * 0.5 + 5.0
	strike.sweep(test_at + Vector2(-200, -miss_height), test_at + Vector2(200, -miss_height))
	check(head.wound.hp == Worm.SEGMENT_HP, "a path that misses the solid head does not wound it")
	strike.sweep(test_at + Vector2(-200, 0), test_at + Vector2(200, 0))
	check(head.wound.hp == Worm.SEGMENT_HP - 1, "a blink across the head still cuts it")
	player.dash.end()
	strike.guard_left = 0.0
	player.end_invulnerable()
	p.recovery = 0.0
	head.recovering = false
	head.sync_touch()
	player.global_position = test_at + Vector2(10, 0)
	check(await until(func() -> bool: return p.recovery > 0.0, 2000), "a real bite starts its piece's recovery")
	player.global_position = test_at + Vector2(200, 0)
	await frames(2)
	check(head.bite.collision.disabled and head.live, "its resting head is harmless but stays solid and attackable")
	var resting_hp: int = head.wound.hp
	strike.strike(head, Vector2.RIGHT)
	check(head.wound.hp == resting_hp - 1, "the resting head takes a strike, without a stun's double damage")
	was_u = p.u
	var was_clock: float = p.clock
	worm._step(p, Worm.BITE_RECOVERY * 0.5)
	check(p.u == was_u and p.clock == was_clock, "biting pauses the whole piece, including its crawl timer")
	worm._step(p, Worm.BITE_RECOVERY * 0.5 + 0.01)
	worm._place(p)
	await frames(2)
	check(not head.recovering and not head.bite.collision.disabled, "the head can bite again after recovery")
	worm._step(p, 1.0 / 60.0)
	check(p.u != was_u, "the piece resumes crawling after recovery")
	RunState.delete_save()
	finish()


## Dash through actual input, holding all components of its direction until it stops.
func _dash(direction: Vector2) -> bool:
	var held: Array[StringName] = []
	if direction.x != 0.0:
		held.append(&"Right" if direction.x > 0.0 else &"Left")
	if direction.y != 0.0:
		held.append(&"Down" if direction.y > 0.0 else &"Up")
	for action: StringName in held:
		Input.action_press(action)
	var press: InputEventAction = InputEventAction.new()
	press.action = &"Dash"
	press.pressed = true
	Input.parse_input_event(press)
	var blocked: bool = false
	for i: int in range(10):
		await frames(1)
		blocked = blocked or player.get_slide_collision_count() > 0
	Input.action_release(&"Dash")
	for action: StringName in held:
		Input.action_release(action)
	return blocked
