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
	out_of_sight()
	if "layout=retuned" in OS.get_cmdline_user_args():
		Bands.use(RETUNED)
	run.call_deferred()


## A band layout of the tests' own, every band retuned from the game's (Bands.LAYOUTS): a narrower
## garden dressed more thinly, and each band shorter or longer than it is. Played with
## `bash tests/run.sh -l retuned full`, it shows which tests lean on the bands as they are tuned now
## (a row picked by counting, or a level picked for what it happens to hold) rather than on the
## rules, so the bands can be retuned without the tests breaking.
const RETUNED: Dictionary = {
	"garden": {"arch": Bands.GARDEN, "rows": 2, "down": &"worm", "up": &"bramble", "tune": {"star_share": 0.12, "wisp_share": 0.15}},
	"down": [
		{"arch": Bands.CEMETERY, "rows": 4, "boss": &"necromancer"},
		{"arch": Bands.INSTITUTE, "rows": 3, "boss": &"beast"},
	],
	"up": [
		{"arch": Bands.CRAGS, "rows": 5, "boss": &"golem"},
		{"arch": Bands.SKY, "rows": 7, "boss": &"whale"},
	],
}


## Where a windowed run's window sits: off every screen, so it draws as usual (captures and window
## tests read what it draws) without getting in the way. (Minimized, Windows stops it drawing and
## gives it another size.)
const OFF_SCREEN: Vector2i = Vector2i(-32000, -32000)

## Keep a run out of the way of someone working: silent, and its window (if it has one) off every
## screen; unless "watch" is given after a lone "--", to look on and listen. Every TestKit run does
## it as it starts and window() again; a test extending SceneTree itself can call it too.
static func out_of_sight() -> void:
	if "watch" in OS.get_cmdline_user_args():
		return
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_position(OFF_SCREEN)


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


## Whether the bands in play (Bands) hold every archetype named in `kinds`. A test of a band calls
## it first and, when it is false, finishes there: a band left out of the layout is skipped, not
## failed (run the suite with `bash tests/run.sh -l garden` to check the demo's layout).
func needs(kinds: Array[StringName]) -> bool:
	for kind: StringName in kinds:
		if not Bands.has(kind):
			print("  skip ", test_name(), ": no ", kind, " in the bands in play (", Bands.current, ")")
			return false
	return true


## Rows `ks` of the band of the archetype named `kind` (NextWorldDef.band_row), however long the
## band is tuned: a k of 0 or more counts from its row nearest the start, held to the band; a
## negative k counts back from its far end (-1 its last row, the gate's). Without `gate`, the gate
## level is left out (the rows are held short of it), for a test of the band's ordinary levels.
## Each row once, in order.
func band_rows(kind: StringName, ks: Array[int], gate: bool = true) -> Array[int]:
	var rows: int = Bands.rows_of(kind)
	if not gate and rows > 1 and Bosses.gate_at(NextWorldDef.band_row(kind, rows - 1)) != &"":
		rows -= 1
	var out: Array[int] = []
	for k: int in ks:
		var row: int = NextWorldDef.band_row(kind, clampi(k if k >= 0 else rows + k, 0, rows - 1))
		if not out.has(row):
			out.append(row)
	return out


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


## Bring the wizard to rest where they are: no speed, and no dash, knock-back or wall jump under
## way. A test that froze the wizard (physics off) mid-move and then moves them elsewhere calls it,
## or that move carries on from the new place as soon as their physics runs again.
func still() -> void:
	player.velocity = Vector2.ZERO
	player.knock = Vector2.ZERO
	player.dash.end()
	player.knock_back.end()
	player.wall_jump.end()


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

## Show the game in a window of `size` (captures run with --windowed), out of sight unless watched
## (out_of_sight).
func window(size: Vector2i = Vector2i(1280, 720)) -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = size
	out_of_sight()


## Save `image` (by default the whole window as drawn now) to the stills folder as `file` (which may
## name a folder in it, made if need be).
func save_still(file: String, image: Image = null) -> void:
	var out: Image = image if image != null else root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(STILLS).path_join(file)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	out.save_png(path)
	print("CAPTURED ", file)


## The whole level being played (with a cell of its border round it), photographed in tiles at a
## far zoom, `tiles` across and as many rows as cover it, stitched, cropped to the level and halved,
## saved as `file` (see save_still). Light by sight is turned off meanwhile, so every tile prints
## alike however far it is from the wizard.
func overview_still(file: String, tiles: int = 3) -> void:
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	var by_sight: bool = RisoLight.by_sight
	RisoLight.by_sight = false
	var half: float = float(info.tile_map.tile_set.tile_size.x) * info.tile_map.global_scale.x * 0.5
	var top_left: Vector2 = info.cell_position(Vector2i(-1, -1)) - Vector2(half, half)
	var size: Vector2 = Vector2(info.world.size + Vector2i(2, 2)) * half * 2.0
	var base: Vector2 = Vector2(root.content_scale_size)
	if base.x < 1.0:
		base = Vector2(root.size)
	var was: Vector2 = camera.zoom
	# The zoom at which `tiles` views span the level across.
	var view: Vector2 = Vector2(size.x / float(tiles), size.x / float(tiles) * base.y / base.x)
	var zoom: float = base.x / view.x
	var rows: int = ceili(size.y / view.y)
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	var sheet: Image = null
	for j: int in range(rows):
		for i: int in range(tiles):
			var center: Vector2 = top_left + Vector2((float(i) + 0.5) * view.x, (float(j) + 0.5) * view.y)
			for k: int in range(45):
				camera.zoom = Vector2(zoom, zoom)
				camera.global_position = center
				camera.reset_smoothing()
				await process_frame
			var shot: Image = root.get_texture().get_image()
			if sheet == null:
				sheet = Image.create(shot.get_width() * tiles, shot.get_height() * rows, false, shot.get_format())
			sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(i * shot.get_width(), j * shot.get_height()))
	camera.zoom = was
	RisoLight.by_sight = by_sight
	var px: float = float(sheet.get_width()) / (view.x * float(tiles))
	sheet = sheet.get_region(Rect2i(0, 0, sheet.get_width(), mini(sheet.get_height(), ceili(size.y * px))))
	sheet.resize(sheet.get_width() / 2, sheet.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	save_still(file, sheet)
