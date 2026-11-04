extends TestKit
## The tutorial (Tutorial): laid out by hand, the same on every visit and in every world, with its
## start and lantern, its control cards (ControlHint), its key and door of one colour, and stars
## enough for the shrine. A run begun with the tutorial starts in it by its lit lantern; its way out
## comes out by the start level's door into it, which every start level has, laid last (nearest the
## way in), and leads back in at the way out. Coming out marks it done, so the start menu's toggle
## starts off from then on. A card rises as the wizard comes near and goes once its control is used.
## The stretches that need the wizard's reach (the steps, the bed of thorns a jump clears and the one
## only a jump and a dash clear) are crossed with the game's own controls.
## godot --headless --path . --script res://tests/tutorial_test.gd

## The cells the reach checks start from and must get past (Tutorial.MAP): standing before the
## first step; and running at each bed of thorns from three cells before its edge, the first a jump
## clears, the second only a jump and a dash.
const STEPS_FROM: Vector2i = Vector2i(10, 10)
const STEPS_PAST: int = 18
const THORNS_FROM: Vector2i = Vector2i(21, 10)
const THORNS_PAST: int = 26
const GAP_FROM: Vector2i = Vector2i(33, 10)
const GAP_PAST: int = 39
## How far past the middle of the last cell before a bed (px) the wizard jumps.
const JUMP_AT: float = 30.0


func run() -> void:
	var at: Vector2i = Tutorial.of(28)
	_layout(at)
	_start_levels()
	await boot(28, true)
	DirAccess.remove_absolute(Tutorial.settings_path)
	await _arrival(at)
	await _hint()
	await _reach()
	await _out_and_in(at)
	RunState.delete_save()
	DirAccess.remove_absolute(Tutorial.settings_path)
	finish()


func _layout(at: Vector2i) -> void:
	print("layout")
	var w: LevelGen = build(at)
	var again: LevelGen = build(at)
	var elsewhere: LevelGen = build(Tutorial.of(-4013))
	check(w != null and again != null and w.objects == again.objects, "the tutorial is laid out the same on every visit")
	if w == null:
		return
	check(elsewhere != null and elsewhere.objects == w.objects, "and in every world")
	check(w.exits.keys() == [MapInfo.Exit.BACK], "its way out is its one exit")
	check(w.is_valid(w.start) and w.is_valid(w.start_lantern) and w.get_cell(w.start_lantern).type == LevelGen.Type.CHECKPOINT, "a run starts by its lantern")
	check_eq(count_of(w, LevelGen.Type.HINT), Tutorial.MAP.reduce(func(n: int, row: String) -> int:
			return n + Array(row.split("")).filter(func(c: String) -> bool: return Tutorial.HINTS.has(c)).size(), 0), "a control card for every digit of the map")
	var keys: Array[Vector2i] = w.objects.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.KEY)
	var doors: Array[Vector2i] = w.objects.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == LevelGen.Type.DOOR)
	check(keys.size() == 1 and doors.size() == 1 and w.get_cell(keys[0]).extra_info == w.get_cell(doors[0]).extra_info, "one key and one door, of the same colour")
	var stars: int = count_of(w, LevelGen.Type.COIN) + count_of(w, LevelGen.Type.CLUSTER) * Rules.cluster_value(0)
	check(stars >= Abilities.price(0, 1), "stars enough on the way for the shrine (%d, a first tier costs %d)" % [stars, Abilities.price(0, 1)])
	check_eq(count_of(w, LevelGen.Type.SHRINE), 1, "a shrine")


func _start_levels() -> void:
	print("the start levels' door")
	var kind: int = Tutorial.kind_number()
	var door: int = Worlds.door(kind)
	var all_have: bool = true
	for x: int in [28, 29, -7, 1003]:
		var w: LevelGen = build(Vector2i(x, 0))
		all_have = all_have and w != null and w.exits.has(door) and w.get_cell(w.exits[door]).type == LevelGen.Type.EXIT
	check(all_have, "every start level has a door into its tutorial")
	var lead: Dictionary = Rules.def_for(Vector2i(28, 0)).lead(door)
	check(lead.get("to") == Tutorial.of(28) and lead.get("arrive") == MapInfo.Exit.BACK, "which leads in at its way out")
	var out: Dictionary = Rules.def_for(Tutorial.of(28)).lead(MapInfo.Exit.BACK)
	check(out.get("to") == Vector2i(28, 0) and out.get("arrive") == door, "and the way out comes out by that door")
	check(not build(Vector2i(28, 1)).exits.has(door) and not Rules.def_for(Vector2i(28, -1)).doors.has(kind), "no other row has one")
	check_eq(Rules.def_for(Vector2i(28, 0)).price(door, LevelRecord.new()), 0, "it costs nothing")


func _arrival(at: Vector2i) -> void:
	print("starting in it")
	check_eq(info.coord, at, "a run begun with the tutorial starts in it")
	check(player.global_position.distance_to(info.cell_position(info.world.start)) < 80.0, "by its start")
	check(info.run.respawn_coord == at and info.run.respawn_cell == info.world.start_lantern, "its lantern lit")
	check(not Tutorial.done(), "not yet done")


func _hint() -> void:
	print("a card")
	var cards: Array[Node] = placed("control_hint.tscn")
	var jump: ControlHint = null
	for n: Node in cards:
		if (n as ControlHint).action == &"Jump":
			jump = n as ControlHint
	check(jump != null, "the jump's card is there")
	if jump == null:
		return
	check(not jump.showing(), "down while the wizard is far")
	player.global_position = jump.global_position
	still()
	check(await until(func() -> bool: return jump.showing() and jump.up_for >= ControlHint.SEEN), "up as they come near")
	_press(&"Jump", true)
	await physics_frame
	_press(&"Jump", false)
	await settle(30)
	check(ControlHint.learned.has(&"Jump") and not jump.showing(), "and gone once they jump")


## The two stretches that need the wizard's reach, crossed with the game's controls.
func _reach() -> void:
	print("reach")
	Health.invincible = true
	# Up the steps: walk right, jumping at each.
	await _go(STEPS_FROM)
	var steps: bool = false
	for i: int in range(240):
		Input.action_press("Right")
		if i % 30 == 0:
			_press(&"Jump", true)
		elif i % 30 == 18:
			_press(&"Jump", false)
		await physics_frame
		if info.cell_at(player.global_position).x >= STEPS_PAST:
			steps = true
			break
	_release()
	check(steps, "the steps are climbed by jumping")
	# Over the beds of thorns: the first by a running jump; the second only with a dash at the top.
	check(await _leap(THORNS_FROM, THORNS_PAST, false), "the first bed of thorns is cleared by a jump")
	check(not await _leap(GAP_FROM, GAP_PAST, false), "a jump alone falls short of the second")
	check(await _leap(GAP_FROM, GAP_PAST, true), "which is cleared by a jump and a dash")
	Health.invincible = false


## Run right from `from` and jump from the edge two cells on (dashing at the top with `dash`):
## whether the wizard lands at its height at or past column `past`.
func _leap(from: Vector2i, past: int, dash: bool) -> bool:
	await _go(from)
	var rose: bool = false
	var over: bool = false
	var edge: float = info.cell_position(from + Vector2i(2, 0)).x + JUMP_AT
	Input.action_press("Right")
	for i: int in range(150):
		if player.global_position.x >= edge and not rose and not Input.is_action_pressed("Jump"):
			_press(&"Jump", true)
		rose = rose or player.velocity.y < -300.0
		if dash and rose and player.velocity.y > -150.0 and not Input.is_action_pressed("Dash"):
			_press(&"Dash", true)
		await physics_frame
		if rose and player.is_on_floor():
			var cell: Vector2i = info.cell_at(player.global_position)
			over = cell.x >= past and cell.y == from.y
			break
	_release()
	await frames(10)
	return over


## Put the wizard on cell `v`, at rest.
func _go(v: Vector2i) -> void:
	player.set_physics_process(false)
	player.global_position = info.cell_position(v)
	still()
	player.set_physics_process(true)
	await settle(20)


func _press(a: StringName, down: bool) -> void:
	var e: InputEventAction = InputEventAction.new()
	e.action = a
	e.pressed = down
	Input.parse_input_event(e)


func _release() -> void:
	for a: StringName in [&"Left", &"Right", &"Jump", &"Dash"]:
		Input.action_release(a)
		_press(a, false)


func _out_and_in(at: Vector2i) -> void:
	print("out and back")
	var door: int = Worlds.door(Tutorial.kind_number())
	info.travel(MapInfo.Exit.BACK)
	await settle()
	check(info.coord == Vector2i(28, 0), "the way out leads to the start level")
	check(player.global_position.distance_to(info.cell_position(info.world.exits.get(door, Vector2i(-1, -1)))) < 80.0, "coming out by its door")
	check(Tutorial.done(), "and marks the tutorial done")
	info.travel(door)
	await settle()
	check(info.coord == at and player.global_position.distance_to(info.cell_position(info.world.exits[MapInfo.Exit.BACK])) < 80.0, "the door leads back in, at the way out")
