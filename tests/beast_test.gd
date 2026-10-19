extends TestKit
## The eldritch beast (Beast, BeastSouls, BeastSoul; docs/REGIONS_PLAN.md §6). Laid out: in every
## gate level of the institute a chamber of marble (Institute.chamber) holds the beast in the middle
## of its floor and nothing else; no other level has one;
## the same every build. In play: it sleeps until the wizard comes in, then sends its souls out
## across the run, some into levels visited (more the more were) and the rest flung far into levels
## not yet visited, never into a gate
## level, one eye for each; while any soul lives a strike glances off it; it strikes with a
## tentacle, under the wizard or along the floor, and a stun whips the tentacle back; the souls are
## saved; a soul lies on a floor of its level, the same spot every visit, with abominations round
## it, and lets more out while the wizard is near; destroyed, it is gone for the run and one eye
## shuts; with every soul gone its great eye opens, blows wound it, and it dies, slain for the run,
## leaving its relic.
## godot --headless --path . --script res://tests/beast_test.gd

const WORLD: int = 28
## Levels marked visited before the beast wakes (rows), in this world and the next ones.
const VISITED: Array[Vector2i] = [Vector2i(28, 0), Vector2i(28, 1), Vector2i(28, 2), Vector2i(27, 1), Vector2i(29, 2), Vector2i(28, 4),
	Vector2i(28, 5), Vector2i(30, 1), Vector2i(28, -1), Vector2i(28, -2), Vector2i(26, 0), Vector2i(28, 11), Vector2i(28, 3)]


func run() -> void:
	MapInfo.debug = false
	_laid_out()
	await _play()
	RunState.delete_save()
	finish()


# ------------------------------------------------------------------ laid out

func _laid_out() -> void:
	print("laid out")
	var row: int = Bosses.row_of(&"beast")
	check_eq(NextWorldDef.archetype_at(row), &"institute", "the beast guards the institute's last row")
	var chambers: int = 0
	var held: int = 0
	var bare: bool = true
	var low: int = 0
	var worlds: Array[int] = [28, 7, 99]
	for x: int in worlds:
		var w: LevelGen = build(Vector2i(x, row))
		if w == null:
			continue
		var chamber: Dictionary = Institute.chamber(w)
		if chamber.is_empty():
			continue
		chambers += 1
		var inside: Rect2i = chamber["inside"]
		var box: Rect2i = chamber["box"]
		if box.position.y * 2 >= w.size.y:
			low += 1
		var bosses: Array[Vector2i] = w.objects_of(LevelGen.Type.BOSS)
		if bosses.size() == 1 and inside.has_point(bosses[0]) and bosses[0].y == inside.end.y - 1 and StringName(w.get_cell(bosses[0]).extra_info) == &"beast":
			held += 1
		for v: Vector2i in w.objects:
			if box.has_point(v) and w.get_cell(v).type != LevelGen.Type.BOSS:
				bare = false
	check_eq(chambers, worlds.size(), "every gate level of the institute has the beast's chamber")
	check_eq(held, worlds.size(), "the beast on the middle of its floor")
	check(bare, "and nothing else in it")
	check(low >= worlds.size() - 1, "in the level's lower half (%d of %d)" % [low, worlds.size()])
	var gate: LevelGen = build(Vector2i(WORLD, row))
	var again: LevelGen = build(Vector2i(WORLD, row))
	check(gate != null and again != null and gate.objects == again.objects and gate.halls.size() == again.halls.size(), "laid out the same twice")
	var plain: LevelGen = build(Vector2i(WORLD, NextWorldDef.band_row(&"institute", 2)))
	check(plain != null and Institute.chamber(plain).is_empty(), "no other level has a chamber")


# ------------------------------------------------------------------ in play

func _play() -> void:
	await boot(WORLD)
	player.set_physics_process(false)
	# The wizard never dies here: the abominations and tentacles would end the test.
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	for c: Vector2i in VISITED:
		info.run.record(c)
	var gate: Vector2i = Vector2i(WORLD, Bosses.row_of(&"beast"))
	await _go(gate)
	player.set_physics_process(false)
	var found: Array[Node] = placed("beast.tscn")
	check(found.size() == 1, "in play the beast is there")
	if found.is_empty():
		return
	var beast: Beast = found[0] as Beast
	check(not beast.awake and info.run.souls_sent == 0, "asleep, its souls not yet sent")

	print("it wakes and sends its souls")
	# Fed by the bells (21 rings), it sends 8.
	info.run.fed = BeastSouls.FED_PER_SOUL * 7
	var floor_cell: Vector2i = Vector2i(beast.box.position.x + 2, beast.box.end.y - 1)
	player.global_position = info.cell_position(floor_cell)
	check(await within(func() -> bool: return beast.awake, 0.5), "the wizard comes into its chamber: it wakes")
	var want: int = BeastSouls.count(info.run)
	check_eq(info.run.souls_sent, want, "%d souls go out" % want)
	var near: int = 0
	var afar: int = 0
	var allowed: bool = true
	for c: Vector2i in info.run.souls:
		if VISITED.has(c):
			near += 1
		else:
			afar += 1
		if not BeastSouls.could_hold(c, gate) or info.run.souls[c] != BeastSouls.NO_SPOT:
			allowed = false
	var holdable: int = VISITED.filter(func(c: Vector2i) -> bool: return BeastSouls.could_hold(c, gate)).size()
	check(near == BeastSouls.kept_near(holdable, want) and near > 0 and afar == want - near, "%d stay in levels visited (one for every %d of the %d), %d are flung into levels not yet visited" % [near, BeastSouls.VISITS_PER_SOUL, holdable, afar])
	check(allowed, "none into a gate level or a side world, and none laid down yet")
	check_eq(beast.eyes(), Vector2i(want, want), "an eye for each, all open")
	var sent: Dictionary = info.run.souls.duplicate()
	info.beast_woke()
	check(info.run.souls == sent, "woken again, it sends no more")
	var wound: BeastWound = beast.get_node("Wound") as BeastWound
	wound.hit(1, Vector2.RIGHT)
	check(wound.hp == Beast.CORE_HP and beast.glanced < 0.2, "while any soul lives, a strike glances off it")

	print("its tentacles")
	check(await within(func() -> bool: return beast.slam.busy() or beast.sweep.busy(), Beast.ATTACK_FIRST / Difficulty.haste() + 1.0), "it strikes with a tentacle")
	var striking: BeastTentacle = beast.slam if beast.slam.busy() else beast.sweep
	if striking == beast.slam:
		check(absf(striking.global_position.x - player.global_position.x) < 2.0 * Beast.SLAM_THICK, "up out of the floor under the wizard")
	check(await within(func() -> bool: return striking.hurts(), BeastTentacle.WARN + BeastTentacle.GROW + 0.5), "after its warning it is out, and hurts")
	beast.stunner.stun(1.0, true)
	check(await within(func() -> bool: return not striking.busy() and not striking.hurts(), 0.6), "a parry's stun whips it back")
	await frames(2)
	beast.stunner.left = 0.0
	beast.stunner.set_stuns(false)
	for i: int in range(6):
		beast.attacks = 2 + i * 3
		beast.attack_in = 0.0
		await within(func() -> bool: return beast.sweep.busy() or beast.slam.busy(), 0.3)
		if beast.sweep.busy():
			break
		await within(func() -> bool: return not beast.slam.busy(), BeastTentacle.PERIOD + 0.5)
	check(beast.sweep.busy() and absf(beast.sweep.way.y) < 0.01 and beast.sweep.global_position.y > beast.global_position.y, "every few strikes it lashes along the floor instead")

	print("saved")
	info.save_run()
	var saved: Dictionary = RunState.read_save()
	check(saved.get("souls", {}) == info.run.souls and int(saved.get("souls_sent", 0)) == want, "its souls are saved with the run")

	print("a soul")
	var at: Vector2i = _a_soul(VISITED)
	await _go(at)
	player.set_physics_process(false)
	var souls: Array[Node] = placed("beast_soul.tscn")
	check(souls.size() == 1, "a soul lies in %s" % at)
	if souls.is_empty():
		return
	var soul: BeastSoul = souls[0] as BeastSoul
	var spot: Vector2i = info.run.souls[at]
	check(spot != BeastSouls.NO_SPOT and info.world.ground_below(spot) and soul.position == info.cell_position(spot), "on a floor of its level")
	check(placed("abomination.tscn").size() >= 1, "with abominations round it")
	var before: int = info.get_tree().get_nodes_in_group(&"abomination").size()
	player.global_position = info.cell_position(spot + Vector2i(0, -1))
	check(await within(func() -> bool: return info.get_tree().get_nodes_in_group(&"abomination").size() > before, Breach.FIRST + Breach.SURGE + 1.0), "and lets more out while the wizard is near")
	await _go(VISITED[0] if VISITED[0] != at else VISITED[1])
	await _go(at)
	souls = placed("beast_soul.tscn")
	check(souls.size() == 1 and (souls[0] as Node2D).position == info.cell_position(spot), "the same spot on another visit")
	if souls.is_empty():
		return
	soul = souls[0] as BeastSoul
	var alive: int = BeastSouls.alive(info.run)
	while is_instance_valid(soul) and not soul.is_queued_for_deletion():
		soul.wound.hit(1, Vector2.RIGHT)
	await settle()
	check(not info.run.souls.has(at) and BeastSouls.alive(info.run) == alive - 1, "destroyed, it is gone for the run")
	info.run.revive_slain()
	await _go(at)
	check(placed("beast_soul.tscn").is_empty(), "and stays gone")

	print("its great eye")
	for c: Vector2i in info.run.souls.keys():
		BeastSouls.destroyed(info.run, c)
	await _go(gate)
	player.set_physics_process(false)
	found = placed("beast.tscn")
	check(found.size() == 1, "back in its chamber, it is there")
	if found.is_empty():
		return
	beast = found[0] as Beast
	check_eq(beast.eyes(), Vector2i(want, 0), "every eye shut")
	player.global_position = info.cell_position(Vector2i(beast.box.position.x + 2, beast.box.end.y - 1))
	check(await within(func() -> bool: return beast.awake, 0.5) and beast.open(), "awake, its great eye open")
	wound = beast.get_node("Wound") as BeastWound
	wound.hit(1, Vector2.RIGHT)
	check_eq(wound.hp, Beast.core_hp(info.run) - 1, "a strike wounds it (fed, %d blows)" % Beast.core_hp(info.run))
	while wound.hp > 0 and not beast.dying():
		wound.hit(1, Vector2.RIGHT)
	check(beast.dying(), "its last blow: it sinks")
	check(await until(gone(beast)), "and is gone")
	await settle()
	check(info.run.bosses.has(&"beast") and info.run.souls.is_empty(), "slain for the run")
	check(placed("relic.tscn").any(func(n: Node) -> bool: return n.get_meta(&"boss", &"") == &"beast"), "its relic left where it lay")


## A level holding a soul, preferring one already visited (the first in VISITED's order).
func _a_soul(order: Array[Vector2i]) -> Vector2i:
	for c: Vector2i in order:
		if info.run.souls.has(c):
			return c
	return info.run.souls.keys()[0]


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
