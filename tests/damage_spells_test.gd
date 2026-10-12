extends TestKit
## The damage spells that strike round the wizard (Slash, Nova, Push; SpellStrike), in the damage
## slot on the Spell button: a slash wounds and stuns what is in its arc in front and not what is
## behind, comes back quickly, and at IV cuts shots out of the air; a shield takes it whole; a nova
## strikes everything round the wizard within its reach and nothing past it, and is slow to come
## back; a push stuns what is in its cone and shoves it away without wounding it at I, wounds at
## II, and blows shots away.
## godot --headless --path . --script res://tests/damage_spells_test.gd


## Open air: nothing solid, and no thorns.
func open_cell(v: Vector2i) -> bool:
	return info.world.is_valid(v) and info.world.get_cell(v).type not in [LevelGen.Type.GROUND, LevelGen.Type.CRACKED, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.SPIKES, LevelGen.Type.LASER]


## A free floor cell with three open cells either side of it, over ground.
func spot() -> Vector2i:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var ok: bool = true
		for dx: int in range(-3, 4):
			ok = ok and open_cell(v + Vector2i(dx, 0)) and w.is_ground(v + Vector2i(dx, 1))
		if ok:
			return v
	return Vector2i(-1, -1)


## A wisp, held still, its middle `off` px from cell `at`'s middle, at the wizard's height.
func wisp(at: Vector2i, off: float) -> Node2D:
	var e: Node2D = Placeables.scene(LevelGen.Type.ENEMY).instantiate() as Node2D
	LevelLoader.arm(e, info.here.depth)
	info.map_elements.add_child(e)
	e.get_node("Mover").set_physics_process(false)
	e.global_position = info.cell_position(at) + Vector2(off, 16.0)
	return e


func hp(e: Node) -> int:
	return int((e.get_node("Wound") as Wound).hp) if is_instance_valid(e) and not e.is_queued_for_deletion() else 0


func stunned(e: Node) -> bool:
	return is_instance_valid(e) and bool(e.get_node("HitBox").get("stunned"))


## A watcher's shot, still, `off` px from cell `at`'s middle.
func shot(at: Vector2i, off: float) -> Bullet:
	var b: Bullet = (load("res://prefabs/bullet.tscn") as PackedScene).instantiate() as Bullet
	info.map_elements.add_child(b)
	b.global_position = info.cell_position(at) + Vector2(off, -8.0)
	b.setup(Vector2.ZERO, [], null)
	return b


func run() -> void:
	await boot()
	player.end_invulnerable()
	player.health.max_health = 99
	player.health.health = 99
	var at: Vector2i = spot()
	check(at != Vector2i(-1, -1), "open floor to cast on")
	player.set_physics_process(false)
	player.global_position = info.cell_position(at) + Vector2(0, 16 - 31)
	await frames(2)

	print("slash")
	Abilities.grant(player, &"slash")
	var slash: Slash = player.get_node("Slash") as Slash
	check(Abilities.spell(player) == &"slash" and Abilities.tier(player, &"parry") == 0, "slash takes the damage slot")
	var ahead: Node2D = wisp(at, 80.0)
	var behind: Node2D = wisp(at, -110.0)
	var hp_ahead: int = hp(ahead)
	var hp_behind: int = hp(behind)
	check(slash.cast(Vector2.RIGHT), "it slashes")
	check(hp(ahead) == hp_ahead - 1 and stunned(ahead), "what is in front is wounded and stunned")
	check(hp(behind) == hp_behind and not stunned(behind), "what is behind is not")
	check(not slash.cast(Vector2.RIGHT) and Abilities.readiness(player) < 1.0, "it is not ready again at once")
	var back: bool = await within(func() -> bool: return Abilities.readiness(player) >= 1.0, Slash.COOLDOWN + 0.2)
	check(back, "but quickly")
	var guard: Node2D = wisp(at, 60.0)
	var shield: Shield = Shield.new()
	shield.name = "Shield"
	shield.hp = 2
	guard.add_child(shield)
	var hp_guard: int = hp(guard)
	ahead.queue_free()
	await frames(1)
	slash.cast(Vector2.RIGHT)
	check(shield.hp == 1 and hp(guard) == hp_guard and not stunned(guard), "a shield takes it whole")
	guard.queue_free()
	behind.queue_free()
	Abilities.set_tier(player, &"slash", 4)
	slash.wait = 0.0
	var bolt: Bullet = shot(at, 70.0)
	slash.cast(Vector2.RIGHT)
	await frames(1)
	check(not is_instance_valid(bolt) or bolt.is_queued_for_deletion(), "slash IV cuts a shot out of the air")
	# From the Spell button.
	slash.wait = 0.0
	Input.action_press(Abilities.SPELL_ACTION)
	player.set_physics_process(true)
	await frames(2)
	Input.action_release(Abilities.SPELL_ACTION)
	player.set_physics_process(false)
	player.global_position = info.cell_position(at) + Vector2(0, 16 - 31)
	check(slash.wait > 0.0, "the Spell button slashes")

	print("nova")
	Abilities.grant(player, &"nova")
	var nova: Nova = player.get_node("Nova") as Nova
	check(Abilities.spell(player) == &"nova" and not player.has_node("Slash"), "nova takes the damage slot")
	var left: Node2D = wisp(at, -120.0)
	var right: Node2D = wisp(at, 120.0)
	var far: Node2D = wisp(at, 3.0 * 128.0)
	var hp_far: int = hp(far)
	var hp_left: int = hp(left)
	check(nova.cast(), "it bursts")
	check(hp(left) == hp_left - 1 and hp(right) == hp_left - 1 and stunned(left) and stunned(right), "everything round the wizard within its reach is wounded and stunned")
	check(hp(far) == hp_far and not stunned(far), "nothing past its reach")
	check(not nova.cast() and Nova.COOLDOWN > Slash.COOLDOWN * 4.0, "it is slow to come back")
	for e: Node2D in [left, right, far]:
		if is_instance_valid(e):
			e.queue_free()

	print("push")
	Abilities.grant(player, &"push")
	var push: Push = player.get_node("Push") as Push
	check(Abilities.spell(player) == &"push", "push takes the damage slot")
	var target: Node2D = wisp(at, 70.0)
	var hp_target: int = hp(target)
	var from_x: float = target.global_position.x
	var blown: Bullet = shot(at, 100.0)
	check(push.cast(Vector2.RIGHT), "it blows")
	await frames(1)
	check(stunned(target) and hp(target) == hp_target, "what is in its cone is stunned, not wounded at I")
	check(not is_instance_valid(blown) or blown.is_queued_for_deletion(), "and shots in it are blown away")
	var shoved: bool = await within(func() -> bool: return target.global_position.x > from_x + Push.SHOVE * 0.5, Push.SHOVE_TIME + 0.3)
	check(shoved, "and it is shoved away (%.0f px)" % (target.global_position.x - from_x))
	Abilities.grant(player, &"push")
	push.wait = 0.0
	target.global_position = info.cell_position(at) + Vector2(70.0, 16.0)
	push.cast(Vector2.RIGHT)
	# (Still stunned from the first, it takes double, as any stunned enemy does: Wound.)
	check(hp(target) < hp_target, "push II also wounds")
	if is_instance_valid(target):
		target.queue_free()
	RunState.delete_save()
	finish()
