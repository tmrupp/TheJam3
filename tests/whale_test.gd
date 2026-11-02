extends TestKit
## The whale (Whale, WhaleHunt, Belly, WhaleHeart): in its world on the sky's top row, and in no
## gate level of its own; huge, swimming above the top of its level so only its underside hangs into
## view, from fully off one side to fully off the other and back; free, it cannot be struck and
## never swoops at a wizard low down. It swoops at a wizard standing high under open sky ahead of
## it (never one under rock, low or not standing), warning first, then lunging down ahead of them
## and scooping up through them; free, its gobble is a blow and the belly is not reached; trapped
## (the levels either side set to blow into its level), its gobble takes the wizard into its belly;
## its heart there takes HP blows, any bolt wounding it, and leaving heals it; burst, the whale is
## slain, the wizard spat out into its level by the way on, now open, its relic beside it; never
## met again.
## godot --headless --path . --script res://tests/whale_test.gd

## How far ahead of its nose (cells) the test sets it from the wizard: within its reach.
const AHEAD: int = 6

## The perch: a floor cell in the whale's level, high and under open sky, and a cell under rock in
## the high rows (shelter), found from the level's own cells.
var perch: Vector2i = Vector2i(-1, -1)
var shelter: Vector2i = Vector2i(-1, -1)


func run() -> void:
	if not needs([&"sky"]):
		finish()
		return
	var row: int = WhaleHunt.row()
	var x: int = _world_with_perch(row)
	check(x >= 0, "a whale level with a high perch under open sky and a shelter")
	if x < 0:
		finish()
		return
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
	var cam: Camera2D = info.camera()
	check(cam.limit_top == int(whale.ceiling_y), "in its level the camera goes no higher than a cell over the top")
	check(whale.global_position.y < cam.limit_top and whale.global_position.y + Whale.GIRTH > cam.limit_top, "its middle above the highest the camera goes, its underside hanging into view")
	var level_left: float = info.cell_position(Vector2i(0, 0)).x
	var level_right: float = info.cell_position(Vector2i(info.world.size.x - 1, 0)).x
	check(whale.left_x + Whale.LENGTH * 0.5 < level_left and whale.right_x - Whale.LENGTH * 0.5 > level_right, "a pass runs from fully off one side to fully off the other")
	player.global_position = info.cell_position(Vector2i(perch.x, info.world.size.y - 2))
	var from_x: float = whale.global_position.x
	var swooped: bool = await within(func() -> bool: return whale.swooping(), Whale.SWOOP_REST + 1.0)
	check(not swooped and absf(whale.global_position.x - from_x) > 100.0, "it swims its level, never swooping at a wizard low down")
	whale.global_position.x = whale.right_x - 20.0
	whale.facing = 1.0
	var turned: bool = await within(func() -> bool: return whale.phase == Whale.Phase.TURN, 2.0)
	turned = turned and await within(func() -> bool: return whale.facing < 0.0 and whale.phase == Whale.Phase.CRUISE, Whale.TURN + 1.0)
	check(turned, "out of sight past the edge, it rests and turns back")

	print("drawn down")
	var at: Vector2 = info.cell_position(perch)
	_over(whale, at)
	check(whale.drawn_to(at, true), "a wizard standing high under open sky ahead of it draws it down")
	check(not whale.drawn_to(at, false), "not one in the air")
	var low: Vector2 = info.cell_position(Vector2i(perch.x, Whale.HIGH_ROWS + 3))
	check(not whale.drawn_to(low, true), "not one low down")
	var under: Vector2 = info.cell_position(shelter)
	_over(whale, under)
	check(not whale.drawn_to(under, true) and whale.sheltered(under), "not one under rock")
	_over(whale, at)
	whale.global_position.x -= float(Whale.AHEAD_MAX + 4) * whale.cell.x
	check(not whale.drawn_to(at, true), "not one far ahead of it")

	print("swoop, free")
	var hp: int = player.health.health
	await _stand(at)
	_over(whale, at)
	var told: bool = await within(func() -> bool: return whale.telling(), 1.0)
	check(told and whale.mark.distance_to(player.global_position) < 40.0, "it warns first, marking the wizard's spot")
	var gulped: bool = await within(func() -> bool: return whale.gulped, Whale.TELL + Whale.DIVE + 1.0)
	check(gulped and player.health.health < hp and not Worlds.is_side(info.coord), "free, its gobble is a blow, and the belly is not reached")
	var climbed: bool = await within(func() -> bool: return whale.phase == Whale.Phase.CRUISE, Whale.DIVE + Whale.CLIMB + 1.0)
	check(climbed and whale.z_index == Whale.Z_CRUISE, "it climbs back and swims on behind the islands")
	player.set_physics_process(false)

	print("trapped")
	for side: int in [-1, 1]:
		var rec: LevelRecord = info.run.record(Vector2i(x + side, row))
		rec.vanes_on = {Vector2i(1, 1): -side}
		rec.wind_way = -side
	await _go(Vector2i(x, row))
	whale = placed("whale.tscn")[0] as Whale
	check(whale.trapped and _exit(MapInfo.Exit.DEEPER).sealed() == &"whale", "trapped by the winds either side; its gate sealed")
	var held: bool = await _into(whale)
	check(held, "the wizard falls into its mouth, onto its tongue, and its jaws shut over them")
	check(player.visible, "and seen again in its belly")
	var belly: int = Worlds.kind_of(Belly)
	check(Worlds.kind_at(info.coord) == belly and Worlds.origin_of(info.coord) == Vector2i(x, row), "trapped, its gobble takes the wizard into its belly")
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


## The first world from 28 whose level on the whale's row has a perch (a floor three cells wide in
## the high rows, nothing that shelters straight above its middle) and a shelter (a cell in the high
## rows that is no cover itself, with rock above it); -1 if none of the first few dozen has. Found
## from the cells, so it holds however the sky's levels are laid out.
func _world_with_perch(row: int) -> int:
	for x: int in range(28, 60):
		var w: LevelGen = build(Vector2i(x, row))
		perch = Vector2i(-1, -1)
		shelter = Vector2i(-1, -1)
		for cx: int in range(2, w.size.x - 2):
			for cy: int in range(2, Whale.HIGH_ROWS):
				var v: Vector2i = Vector2i(cx, cy)
				if perch.x < 0 and _floor(w, v) and _open_above(w, v):
					perch = v + Vector2i.UP
				if shelter.x < 0 and not w.get_cell(v).type in COVER and _rock_above(w, v):
					shelter = v
		if perch.x >= 0 and shelter.x >= 0:
			return x
	return -1


## The kinds of cell that shelter a wizard from the whale (as MapInfo.solid_at takes them, shut).
const COVER: Array[LevelGen.Type] = [LevelGen.Type.GROUND, LevelGen.Type.CRACKED, LevelGen.Type.DOOR, LevelGen.Type.TRAPDOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.LIGHT_GATE, LevelGen.Type.OSSUARY_DOOR]


## Whether `v` and the cells either side are rock with room to stand over each: open air, or
## something floating there to be picked up (a star, a moon).
func _floor(w: LevelGen, v: Vector2i) -> bool:
	for dx: int in [-1, 0, 1]:
		var at: Vector2i = v + Vector2i(dx, 0)
		var over: LevelGen.Type = w.get_cell(at + Vector2i.UP).type
		if not w.is_ground(at) or not (over == LevelGen.Type.EMPTY or Placeables.has_flag(over, &"floats")):
			return false
	return true


## Whether nothing straight above `v`, up to the level's top, shelters it (COVER).
func _open_above(w: LevelGen, v: Vector2i) -> bool:
	for y: int in range(0, v.y):
		if w.get_cell(Vector2i(v.x, y)).type in COVER:
			return false
	return true


## Whether rock stands anywhere straight above `v`.
func _rock_above(w: LevelGen, v: Vector2i) -> bool:
	for y: int in range(0, v.y):
		if w.is_ground(Vector2i(v.x, y)):
			return true
	return false


## Set `whale` cruising right, rested, with `at` a little ahead of its nose.
func _over(whale: Whale, at: Vector2) -> void:
	whale.phase = Whale.Phase.CRUISE
	whale.u = 0.0
	whale.facing = 1.0
	whale.since = 99.0
	whale.bend = Vector2.ZERO
	whale.aim = Vector2.RIGHT
	whale.gape = 0.0
	whale.global_position.x = at.x - Whale.LENGTH * 0.5 - float(AHEAD) * whale.cell.x


## Put the wizard on the perch at `at`, standing.
func _stand(at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	await until(func() -> bool: return player.is_on_floor())


## Stand the wizard on the perch with the trapped `whale` coming, and wait to be gobbled: into its
## belly. Returns whether the wizard, caught, fell into its mouth in sight, came to rest on its
## tongue, and was hidden by its jaws shutting before it took them in.
func _into(whale: Whale) -> bool:
	var at: Vector2 = info.cell_position(perch)
	await _stand(at)
	_over(whale, at)
	var held: bool = await within(func() -> bool: return whale.holding, Whale.TELL + Whale.DIVE * 2.0 + 1.0)
	held = held and player.visible
	held = held and await within(func() -> bool: return not whale.holding, Whale.SWALLOW + 0.5)
	held = held and not player.visible and player.global_position.distance_to(whale._world(whale._resting())) < 60.0
	await until(func() -> bool: return Worlds.is_side(info.coord) and not info.travelling, 15000)
	await settle()
	player.set_physics_process(false)
	return held


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
