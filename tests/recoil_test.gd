extends TestKit
## The throw back off a spell (SpellStrike.recoil): a push throws the wizard hard back whether it
## catches anything or not, a hex bolt a little, and either far more in the air than on the ground;
## a slash down from the air onto thorns strikes them and bounces the wizard up (as onto an enemy,
## parry_landing_test), and one down at nothing does not; a hex bolt aimed down bounces them a
## little, and a bolt ends on thorns as on rock.
## godot --headless --path . --script res://tests/recoil_test.gd


## How far over the floor (px) the wizard is put to be in the air.
const AIR_UP: float = 40.0


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


## Thorns laid on the floor of cell `v` (pointing up, always out), as a level lays them.
func lay_thorns(v: Vector2i) -> Spikes:
	var thorns: Spikes = (load("res://prefabs/spikes.tscn") as PackedScene).instantiate() as Spikes
	info.map_elements.add_child(thorns)
	thorns.global_position = info.cell_position(v)
	return thorns


## Where the wizard stands on the test's floor.
var floor_at: Vector2 = Vector2.ZERO


## Put the wizard at `at` and let one physics step pass, so they stand (on a floor) or fall.
func put(at: Vector2) -> void:
	player.set_physics_process(true)
	player.knock = Vector2.ZERO
	player.knock_back.end()
	player.global_position = at
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	if at.is_equal_approx(floor_at):
		await within(func() -> bool: return player.is_on_floor(), 1.0)
	player.knock = Vector2.ZERO
	player.knock_back.end()
	player.knock_back.refresh()


func run() -> void:
	await boot()
	player.health.max_health = 99
	player.health.health = 99
	var at: Vector2i = spot()
	check(at != Vector2i(-1, -1), "open floor")
	floor_at = info.cell_position(at) + Vector2(0, 16 - 31)
	# A little over the floor: in the air for a few steps.
	var air_at: Vector2 = floor_at + Vector2(0, -AIR_UP)

	print("push")
	Abilities.set_tier(player, &"push", 1)
	var push: Push = player.get_node("Push") as Push
	await put(floor_at)
	check(player.is_on_floor(), "the wizard stands on the floor")
	push.cast(Vector2.RIGHT)
	var ground: float = -player.knock.x
	check(is_equal_approx(ground, SpellStrike.RECOIL * Push.RECOIL) and player.knock_back.is_acting(), "a push at nothing throws the wizard back all the same (%d px/s)" % int(ground))
	push.wait = 0.0
	await put(air_at)
	check(not player.is_on_floor(), "now in the air")
	push.cast(Vector2.RIGHT)
	var air: float = -player.knock.x
	check(is_equal_approx(air, ground * SpellStrike.AIR_RECOIL) and player.knock_back.acting > SpellStrike.RECOIL_TIME, "far harder and longer in the air (%d px/s)" % int(air))
	push.wait = 0.0
	await put(air_at)
	push.cast(Vector2.DOWN)
	check(is_equal_approx(player.velocity.y, SpellStrike.POGO * SpellStrike.POGO_MOST), "a push down from the air is a big bounce up")

	print("slash and thorns")
	# Thorns of the test's own, on open floor.
	Abilities.set_tier(player, &"slash", 1)
	var slash: Slash = player.get_node("Slash") as Slash
	var thorns: Spikes = lay_thorns(at + Vector2i.RIGHT * 2)
	if thorns != null:
		player.grace()
		await put(thorns.global_position + Vector2(0, -20))
		check(not player.is_on_floor(), "the wizard over the thorns, in the air")
		check(slash.cast(Vector2.DOWN) and is_equal_approx(player.velocity.y, SpellStrike.POGO), "a slash down strikes the thorns and bounces the wizard up")
	slash.wait = 0.0
	await put(air_at)
	var falling: float = player.velocity.y
	slash.cast(Vector2.DOWN)
	check(is_equal_approx(player.velocity.y, falling) and player.knock == Vector2.ZERO, "a slash down at nothing throws the wizard nowhere")

	print("hex")
	Abilities.set_tier(player, &"hex", 1)
	var hex: Hex = player.get_node("Hex") as Hex
	await put(floor_at)
	hex.refill()
	hex.cast(Vector2.RIGHT)
	check(is_equal_approx(-player.knock.x, SpellStrike.RECOIL * Hex.RECOIL), "a hex bolt knocks the wizard back a little (%d px/s), hitting or not" % int(-player.knock.x))
	await put(air_at)
	hex.refill()
	hex.cast(Vector2.DOWN)
	check(is_equal_approx(player.velocity.y, SpellStrike.POGO * Hex.RECOIL), "aimed down from the air, it bounces them a little")
	if thorns != null:
		var bolt: HexBolt = HexBolt.new()
		info.map_elements.add_child(bolt)
		var over: Vector2 = thorns.global_position + Vector2(0, -60)
		var meets: Vector2 = bolt._thorns(over, over + Vector2(0, 200))
		check(meets.is_finite() and meets.y < thorns.global_position.y + 64.0, "a bolt meets thorns in its way, short of the rock under them")
		thorns.out = false
		check(not bolt._thorns(over, over + Vector2(0, 200)).is_finite(), "but not thorns that are down")
		thorns.out = true
		bolt.queue_free()
	finish()
