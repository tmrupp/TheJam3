extends TestKit
## The whale (Whale, WhaleHunt, Belly, WhaleHeart): in its world on the sky's top row, and in no
## gate level of its own; free, it swims its level with its mouth shut and cannot be struck; trapped
## (the levels either side set to blow into its level), it holds and its mouth opens now and then,
## taking the wizard into its belly; its heart there takes HP blows, any bolt wounding it, and leaving
## heals it; burst, the whale is slain, the wizard spat out into its level by the way on, now open,
## its relic beside it; never met again.
## godot --headless --path . --script res://tests/whale_test.gd


func run() -> void:
	var row: int = WhaleHunt.row()
	var x: int = 28
	check(build(Vector2i(x, row)).objects_of(LevelGen.Type.BOSS).is_empty(), "no gate level holds the whale")
	await boot(x)
	player.health.max_health = 99
	player.health.health = 99
	print("free")
	info.run.whale_x = x
	await _go(Vector2i(x, row))
	var whales: Array[Node] = placed("whale.tscn")
	check(whales.size() == 1, "the whale is in its world's level on its row")
	if whales.is_empty():
		finish()
		return
	var whale: Whale = whales[0] as Whale
	check(not whale.trapped and not whale.is_in_group(&"hex_target"), "free, and not to be struck")
	var from_x: float = whale.global_position.x
	var opened: bool = await within(func() -> bool: return whale.open(), Whale.MOUTH_EVERY + 1.0)
	check(not opened and absf(whale.global_position.x - from_x) > 100.0, "it swims its level, its mouth shut")

	print("trapped")
	for side: int in [-1, 1]:
		var rec: LevelRecord = info.run.record(Vector2i(x + side, row))
		rec.vanes_on = {Vector2i(1, 1): -side}
		rec.wind_way = -side
	await _go(Vector2i(x, row))
	whale = placed("whale.tscn")[0] as Whale
	check(whale.trapped and _exit(MapInfo.Exit.DEEPER).sealed() == &"whale", "trapped by the winds either side; its gate sealed")
	await _into(whale)
	var belly: int = Worlds.kind_of(Belly)
	check(Worlds.kind_at(info.coord) == belly and Worlds.origin_of(info.coord) == Vector2i(x, row), "its open mouth takes the wizard into its belly")
	var hearts: Array[Node] = placed("whale_heart.tscn")
	check(hearts.size() == 1, "its heart is there")
	if hearts.is_empty():
		finish()
		return
	var heart: WhaleHeart = hearts[0] as WhaleHeart
	check(heart.wound.hp == WhaleHeart.HP and heart.wound.least == 1 and heart.is_in_group(&"hex_target"), "whole, %d blows, any bolt wounding it" % WhaleHeart.HP)
	for i: int in range(3):
		heart.wound.hit(1, Vector2.RIGHT)
	info.travel(MapInfo.Exit.BACK)
	await settle()
	player.set_physics_process(false)
	check(info.coord == Vector2i(x, row), "its way back leads out to its level")
	whale = placed("whale.tscn")[0] as Whale
	await _into(whale)
	heart = placed("whale_heart.tscn")[0] as WhaleHeart
	check(heart.wound.hp == WhaleHeart.HP, "leaving heals its heart")

	print("burst")
	for i: int in range(WhaleHeart.HP):
		if is_instance_valid(heart) and not heart.is_queued_for_deletion():
			heart.wound.hit(1, Vector2.RIGHT)
	var out: bool = await until(func() -> bool: return info.coord == Vector2i(x, row) and not info.travelling, 15000)
	await settle()
	player.set_physics_process(false)
	check(out and info.run.bosses.has(&"whale"), "its heart burst, the whale is slain and the wizard spat out into its level")
	var on: Vector2 = info.cell_position(info.world.exits[MapInfo.Exit.DEEPER])
	check(player.global_position.distance_to(on) < 140.0 and _exit(MapInfo.Exit.DEEPER).sealed() == &"", "by the way on, now open")
	var relics: Array[Node] = placed("relic.tscn").filter(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"whale")
	check(relics.size() == 1 and (relics[0] as Node2D).global_position.distance_to(on) < 300.0, "its relic beside it")
	check(placed("whale.tscn").is_empty() and not WhaleHunt.move(info.run, Vector2i(x + 1, row)), "never met again")
	RunState.delete_save()
	finish()


## Wait for `whale`'s mouth to open and put the wizard in it: into its belly.
func _into(whale: Whale) -> void:
	await within(func() -> bool: return whale.open() and whale.gape > 0.7, Whale.MOUTH_EVERY + 2.0)
	player.global_position = whale.mouth()
	await until(func() -> bool: return Worlds.is_side(info.coord) and not info.travelling, 15000)
	await settle()
	player.set_physics_process(false)


## Load place `at` (arriving at its way back) and wait for it.
func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)


## The place's exit `which`.
func _exit(which: int) -> LevelExit:
	for n: Node in placed("level_exit.tscn"):
		if (n as LevelExit).exit == which:
			return n as LevelExit
	return null
