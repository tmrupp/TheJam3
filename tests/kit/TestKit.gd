class_name TestKit
extends SceneTree
## The shared base of the regression tests and the art captures. A test extends it, overrides
## run() and ends with finish(); everything else here is optional:
## - check() and check_eq() print an "ok" line, or a FAIL line the runner looks for;
## - boot() starts a run in the real game (world 28 unless told otherwise) and waits for its first
##   level, with the save kept apart from the player's and from every other test's;
## - until() and settle() wait on the game rather than on a guessed number of frames;
## - build() lays out the level at a place without the game scene at all, for tests of the level
##   generator alone, which are many times faster than booting the game;
## - window() and save_still() are for the captures, which write to ../art-captures/riso-frames.

## Set by any failed check; finish() exits with 1 then.
var failed: bool = false
## The game scene and its parts, once boot() has run.
var main: Node
var info: MapInfo
var player: Player
## The terrain generator collapse() and build() use (made on first use, freed by finish()).
var _wfc: Node

## Where the captures write their stills.
const STILLS: String = "res://../art-captures/riso-frames"
## How long until() and settle() wait before giving up, in milliseconds.
const WAIT_MS: int = 30000


func _initialize() -> void:
	# One physics step a frame. Under load the engine otherwise runs several physics steps in one
	# frame to catch up, while a press made with Input.parse_input_event reaches the game only at
	# the start of the next frame: a test that pressed, then counted physics frames, could count
	# them all before the press arrived. With one step a frame, a busy machine runs the game slower
	# instead, and every test sees the same order of input and physics as on an idle one.
	Engine.max_physics_steps_per_frame = 1
	run.call_deferred()


## The test itself. Override it, and end it with finish().
func run() -> void:
	finish()


## The test's name: its file name, without the extension.
func test_name() -> String:
	return (get_script() as Script).resource_path.get_file().get_basename()


# ------------------------------------------------------------------ checks

func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		failed = true
		push_error("FAIL " + what)


## A check that two values are equal, showing both when they are not.
func check_eq(got: Variant, want: Variant, what: String) -> void:
	check(got == want, what if got == want else "%s (got %s, wanted %s)" % [what, got, want])


## Report and exit: 1 if any check failed. Frees anything the kit made.
func finish(label: String = "") -> void:
	if _wfc != null:
		_wfc.free()
		_wfc = null
	var title: String = label if label != "" else test_name()
	if failed:
		print("FAILED: ", title)
		quit(1)
	else:
		print("PASS: ", title)
		quit(0)


# ------------------------------------------------------------------ waiting

## Wait until `cond` (a Callable returning bool) holds, checking each frame; false if it still
## does not after `timeout_ms`.
func until(cond: Callable, timeout_ms: int = WAIT_MS) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while not bool(cond.call()):
		if Time.get_ticks_msec() >= deadline:
			return false
		await process_frame
	return true


## Wait until `cond` holds, checking after each physics frame, for at most `seconds` of game time
## (counted in physics frames, not by the clock); false if it still does not hold. For what the
## game times itself (a cooldown, a regrowth): a busy machine runs the game slower than the clock,
## so a wait by the clock can run out before the game's own time has.
func within(cond: Callable, seconds: float) -> bool:
	for i: int in range(ceili(seconds * float(Engine.physics_ticks_per_second))):
		if bool(cond.call()):
			return true
		await physics_frame
	return bool(cond.call())


## A condition for until(): `node` is freed or going away. (A lambda holding the node itself
## would be handed null, with an error, once the node is freed: this holds its id instead.)
func gone(node: Node) -> Callable:
	var id: int = node.get_instance_id()
	return func() -> bool:
		var o: Node = instance_from_id(id) as Node
		return o == null or o.is_queued_for_deletion()


## Wait for `count` physics frames, each followed by a process frame.
func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame


## Wait until the level is loaded and nothing is travelling or ending, then `count` frames more.
func settle(count: int = 4) -> void:
	await process_frame
	await until(func() -> bool: return info.world != null and not info.travelling and info.run_ending <= 0.0)
	await frames(count)


# ------------------------------------------------------------------ the game

## Start a run in the game on `world_seed` and wait for its first level. The run's save goes to
## user://<test name>.save, so tests never touch a player's save or one another's.
func boot(world_seed: int = 28) -> void:
	RunState.save_path = "user://%s.save" % test_name()
	main = (load("res://prefabs/scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	info = main.get_node("CanvasLayer/MapInfo") as MapInfo
	var menu: Node = main.get_node("Menu")
	(menu.get("world_seed") as LineEdit).text = str(world_seed)
	# Starting the game makes the wizard.
	menu.call("start_game")
	player = main.get_node("Player") as Player
	await settle()


## The objects of the level being played that came from prefab `scene` (a file name such as
## "key.tscn"), leaving out those going away, and those hidden (a key being picked up) unless
## `hidden` (a bridge's planks are hidden until its bell is rung).
func placed(scene: String, hidden: bool = false) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in info.map_elements.get_children():
		if node.scene_file_path.get_file() != scene or node.is_queued_for_deletion():
			continue
		var sprite: CanvasItem = node.get_node_or_null("Sprite2D") as CanvasItem
		if hidden or sprite == null or sprite.visible:
			found.append(node)
	return found


## Placed keys or doors (see placed) of key colour `color`.
func colored(scene: String, color: int) -> Array[Node]:
	return placed(scene).filter(func(n: Node) -> bool: return int(n.get_meta(&"key_color", -1)) == color)


# ------------------------------------------------------------------ the level generator alone

## The terrain the place at `at` collapses to, in the generator's colours ([] if it never settles
## and the place has no fallback).
func collapse(at: Vector2i) -> Array:
	if _wfc == null:
		_wfc = _make_wfc()
	return _wfc.call("generate_level", Rules.def_for(at))


## A terrain generator with the game's own settings, read from the game scene's generator node
## without making the scene (pattern size and the rest stay in step with the game).
static func _make_wfc() -> Node:
	var wfc: Node = (load("res://scripts/WaveFunctionCollapse.gd") as GDScript).new() as Node
	var state: SceneState = (load("res://prefabs/scenes/main.tscn") as PackedScene).get_state()
	for i: int in range(state.get_node_count()):
		if state.get_node_name(i) != &"WaveFunctionCollapse":
			continue
		for p: int in range(state.get_node_property_count(i)):
			var prop: StringName = state.get_node_property_name(i, p)
			if prop != &"script":
				wfc.set(prop, state.get_node_property_value(i, p))
	return wfc


## The place at `at` laid out (terrain collapsed, then dressed), without the game scene; null if
## its terrain never settles.
func build(at: Vector2i) -> LevelGen:
	var cells: Array = collapse(at)
	if cells.is_empty():
		return null
	return LevelGen.new(cells, Rules.def_for(at))


## How many of the objects laid in `w` are of `type`.
static func count_of(w: LevelGen, type: LevelGen.Type) -> int:
	return w.objects.filter(func(v: Vector2i) -> bool: return w.get_cell(v).type == type).size()


# ------------------------------------------------------------------ captures

## Show the game in a window of `size` (captures run with --windowed).
func window(size: Vector2i = Vector2i(1280, 720)) -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = size


## Save `image` (by default the whole window as drawn now) to the stills folder as `file`.
func save_still(file: String, image: Image = null) -> void:
	var out: Image = image if image != null else root.get_texture().get_image()
	var dir: String = ProjectSettings.globalize_path(STILLS)
	DirAccess.make_dir_recursive_absolute(dir)
	out.save_png(dir.path_join(file))
	print("CAPTURED ", file)
