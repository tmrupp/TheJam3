extends TestKit
## The difficulty presets (Difficulty, picked on the F7 panel): Normal changes nothing, each harder
## one holds more foes and runs the bosses faster, and a game starts on Hard. Levels hold more
## enemies and hazards on a harder preset, stay the same every build under one, are kept apart per
## preset by the loader, and stay whole (every open cell joined to the way in, every switch reached
## with its gate shut) even on Brutal; the spider rears for less time; and picking a preset on the
## F7 panel lays the place out again under it; and the other enemies attack more often (a hopper
## rests for less) and move a little faster (wisps walk faster).
## godot --headless --path . --script res://tests/difficulty_test.gd

## The kinds of thing counted as foes: enemies and hazards a level is dressed with.
const FOES: Array[LevelGen.Type] = [
	LevelGen.Type.ENEMY, LevelGen.Type.SHOOTER, LevelGen.Type.HOPPER, LevelGen.Type.MOTHS,
	LevelGen.Type.FOG, LevelGen.Type.WRAITH, LevelGen.Type.BUG, LevelGen.Type.STALACTITE,
	LevelGen.Type.NEST, LevelGen.Type.BIRD,
]


func run() -> void:
	MapInfo.debug = false
	print("the presets")
	check(Difficulty.DEFAULT == Difficulty.Preset.HARD and Difficulty.preset == Difficulty.Preset.HARD, "a game starts on Hard")
	check(Difficulty.FOES[Difficulty.Preset.NORMAL] == 1.0 and Difficulty.HASTE[Difficulty.Preset.NORMAL] == 1.0, "Normal changes nothing")
	var rising: bool = Difficulty.NAMES.size() == Difficulty.Preset.size() and Difficulty.FOES.size() == Difficulty.Preset.size() and Difficulty.HASTE.size() == Difficulty.Preset.size()
	for p: int in range(1, Difficulty.Preset.size()):
		rising = rising and Difficulty.FOES[p] > Difficulty.FOES[p - 1] and Difficulty.HASTE[p] > Difficulty.HASTE[p - 1]
	check(rising, "each harder preset holds more foes and runs the bosses faster")
	var enemies: bool = Difficulty.ATTACK.size() == Difficulty.Preset.size() and Difficulty.SPEED.size() == Difficulty.Preset.size() \
			and Difficulty.ATTACK[Difficulty.Preset.NORMAL] == 1.0 and Difficulty.SPEED[Difficulty.Preset.NORMAL] == 1.0
	for p: int in range(1, Difficulty.Preset.size()):
		enemies = enemies and Difficulty.ATTACK[p] > Difficulty.ATTACK[p - 1] and Difficulty.SPEED[p] > Difficulty.SPEED[p - 1] \
				and Difficulty.SPEED[p] - 1.0 < Difficulty.ATTACK[p] - 1.0 and Difficulty.SPEED[p] <= 1.2
	check(enemies, "and the other enemies attack more often, and move a little faster (at most a fifth)")

	print("levels")
	var places: Array[Vector2i] = [Vector2i(28, 0), Vector2i(7, 2), Vector2i(28, NextWorldDef.band_row(&"cemetery", 1)),
		Vector2i(28, NextWorldDef.band_row(&"catacombs", 1)), Vector2i(28, NextWorldDef.band_row(&"crags", 1)),
		Vector2i(28, NextWorldDef.band_row(&"sky", 1))]
	var totals: Array[int] = []
	for p: int in range(Difficulty.Preset.size()):
		Difficulty.preset = p as Difficulty.Preset
		var total: int = 0
		var same: bool = true
		var whole: bool = true
		for at: Vector2i in places:
			var w: LevelGen = build(at)
			total += _foes(w)
			same = same and build(at).objects == w.objects
			whole = whole and _whole(w)
		totals.append(total)
		check(same, "%s: the same every build" % Difficulty.NAMES[p])
		check(whole, "%s: every level stays whole (its open air joined, its switches reached with their gates shut)" % Difficulty.NAMES[p])
	check(totals[1] > totals[0] and totals[2] > totals[1], "harder presets hold more foes (%s)" % [totals])
	Difficulty.preset = Difficulty.Preset.NORMAL
	var normal_key: String = LevelLoader._world_key(Vector2i(28, 0))
	Difficulty.preset = Difficulty.Preset.BRUTAL
	check(normal_key != LevelLoader._world_key(Vector2i(28, 0)), "the loader keeps each preset's layouts apart")

	print("the spider")
	await boot(28)
	player.health.max_health = 99
	player.health.health = 99
	info.coord = Worlds.side_at(Worlds.kind_of(Arena), Vector2i(28, Bosses.row_of(&"spider")))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	var spider: Spider = placed("spider.tscn")[0] as Spider
	var floors: Array[int] = info.world.keep["floors"]
	var inside: Rect2i = info.world.keep["inside"]
	player.global_position = info.cell_position(Vector2i(inside.position.x + 1, floors[0] - 1))
	var normal: int = await _rearing(spider, Difficulty.Preset.NORMAL)
	var brutal: int = await _rearing(spider, Difficulty.Preset.BRUTAL)
	check(normal > 0 and brutal > 0 and brutal < normal, "it rears for less time on Brutal (%d physics steps against %d)" % [brutal, normal])

	print("the F7 row")
	var here: Vector2i = Vector2i(28, NextWorldDef.band_row(&"cemetery", 1))
	Difficulty.preset = Difficulty.Preset.HARD
	info.coord = here
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var hard_foes: int = _foes(info.world)
	var pick: OptionButton = RisoPrint.instance._options[&"difficulty"]
	pick.select(Difficulty.Preset.BRUTAL)
	pick.item_selected.emit(Difficulty.Preset.BRUTAL)
	var again: bool = await until(func() -> bool: return info.world != null and info.coord == here and _foes(info.world) > hard_foes and not info.travelling)
	check(Difficulty.preset == Difficulty.Preset.BRUTAL and again, "picking Brutal lays the place out again, with more foes (%d against %d)" % [_foes(info.world), hard_foes])

	print("the other enemies")
	# Each stepped by hand (out of the game's own steps), the same step on each preset; kept awake
	# wherever it is (a sleeping chunk takes its body out of the physics).
	var hoppers: Array[Node] = placed("hopper_enemy.tscn")
	var rested: Array[float] = []
	if not hoppers.is_empty():
		var hopper: Hopper = (hoppers[0] as Node).get_node("Hopper") as Hopper
		await _keep_awake(hoppers[0])
		player.global_position = Vector2(-9000, -9000)
		await until(func() -> bool: return hopper.grounded)
		hopper.set_physics_process(false)
		for p: Difficulty.Preset in [Difficulty.Preset.NORMAL, Difficulty.Preset.BRUTAL]:
			Difficulty.preset = p
			hopper.grounded = true
			hopper.rest = 1.0
			hopper._physics_process(0.1)
			rested.append(1.0 - hopper.rest)
	check(rested.size() == 2 and rested[1] > rested[0] * 1.3, "a hopper rests between leaps for less on Brutal (%s of a second gone in a tenth)" % [rested])
	var walked: Array[float] = []
	for n: Node in placed("mover_enemy.tscn"):
		var mover: Mover = n.get_node("Mover") as Mover
		await _keep_awake(n)
		mover.set_physics_process(false)
		walked.clear()
		for p: Difficulty.Preset in [Difficulty.Preset.NORMAL, Difficulty.Preset.BRUTAL]:
			Difficulty.preset = p
			mover.turn_left = 0.0
			var from: float = (n as Node2D).global_position.x
			mover._physics_process(1.0 / 60.0)
			walked.append(absf((n as Node2D).global_position.x - from))
		if walked[0] > 0.5:
			break
	check(walked.size() == 2 and walked[1] > walked[0] and walked[1] < walked[0] * 1.3, "a wisp walks a little faster on Brutal (%s px in a step)" % [walked])
	RunState.delete_save()
	finish()


## Keep `node` awake however far from the wizard (LevelLoader.sleep_far_chunks) for the rest of the
## test, and let it settle back into the physics.
func _keep_awake(node: Node) -> void:
	node.remove_meta(&"cell")
	node.process_mode = Node.PROCESS_MODE_INHERIT
	await frames(3)


## How many foes level `w` holds.
func _foes(w: LevelGen) -> int:
	return w.objects.filter(func(v: Vector2i) -> bool: return FOES.has(w.get_cell(v).type)).size()


## Whether level `w` is whole: every open cell joined to its way in, and every switch reached from
## there with its gate shut.
func _whole(w: LevelGen) -> bool:
	var start: Vector2i = w.exits[MapInfo.Exit.BACK]
	var all: Dictionary = w.reach_from(start, func(n: Vector2i) -> bool: return true)
	for x: int in range(w.size.x):
		for y: int in range(w.size.y):
			if w._open(Vector2i(x, y)) and not all.has(Vector2i(x, y)):
				return false
	for v: Vector2i in w.objects:
		if w.get_cell(v).type == LevelGen.Type.SWITCH_GATE:
			var reach: Dictionary = w.reach_from(start, func(n: Vector2i) -> bool: return n != v)
			if not reach.has(w.get_cell(v).extra_info):
				return false
	return true


## How many physics steps `spider` rears for, on preset `p` (read as it goes), the next time it
## rears at the wizard.
func _rearing(spider: Spider, p: Difficulty.Preset) -> int:
	Difficulty.preset = p
	if not await within(func() -> bool: return spider.state == Spider.State.WARN, 15.0):
		return -1
	var steps: int = 0
	while spider.state == Spider.State.WARN and steps < 600:
		await physics_frame
		steps += 1
	return steps
