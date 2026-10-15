extends TestKit
## Frames for GIFs of the latest spell and crag changes, each a short scene played in real physics
## with the camera following: the ferry's raft shuttling to and fro (ferry), a slash's mark moving
## with the wizard as they run and slash (slash), hopping across a bed of thorns by slashing down
## onto them (thorns), a push's and a hex bolt's throw back on the ground and in the air (recoil),
## a lunge along the floor stabbing through wisps (lunge), seekers turning onto wisps off their line
## (seeker), the Fool swinging their bindle to cast each damage spell, close up (bindle), and a
## crossbow's quick first arrow, as big in flight as on its string (crossbow). Frames go to
## the stills folder's changes_gif/<scene>/ as frame_NNN.png, a frame every EVERY physics steps
## (played at 30 frames a second, the game's own speed); turn them into GIFs with ffmpeg.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_changes_gif.gd
## Options after a lone "--": scenes=ferry,thorns (every scene by default).

## How many physics steps apart frames are taken, the middle of the window taken, the size it is
## scaled to, and the camera's zoom against the game's own.
const EVERY: int = 2
const CROP: Vector2i = Vector2i(1120, 630)
const SIZE: Vector2i = Vector2i(640, 360)
const ZOOM: float = 1.15
## How many cells of open floor (with two rows of air over it) the floor scenes want at most, and
## how many the level picked has.
const RUN: int = 8
var run_len: int = RUN
## Every scene, in order.
const SCENES: Array[StringName] = [&"ferry", &"slash", &"thorns", &"recoil", &"lunge", &"seeker", &"bindle", &"crossbow"]

var camera: Camera2D
var base_zoom: Vector2 = Vector2.ONE
## Whether the camera follows the wizard (`lead` off them) while a scene records, else looks at
## `fixed`.
var follow: bool = true
var fixed: Vector2 = Vector2.ZERO
var lead: Vector2 = Vector2(0, -30)
## The camera's zoom for the scene recording, against the game's own.
var zoom: float = ZOOM


func run() -> void:
	window()
	var wanted: Array[StringName] = SCENES.duplicate()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("scenes="):
			wanted.clear()
			for s: String in arg.trim_prefix("scenes=").split(",", false):
				wanted.append(StringName(s))
	await boot(28)
	# A garden level with a long open floor and a short run of air to rock, for the first scenes.
	var level: Vector2i = Vector2i(28, 0)
	var found: bool = false
	for want: int in [RUN, RUN - 1, RUN - 2]:
		for world: int in range(28, 46):
			# Not the band's gate rows (±3), where a boss waits.
			for row: int in [1, 2, -1, -2]:
				var w: LevelGen = build(Vector2i(world, row))
				if not found and _floor_run(w, want).x >= 0 and _run_to_rock(w, 3, 6).x >= 0:
					level = Vector2i(world, row)
					found = true
					run_len = want
			if found:
				break
		if found:
			break
	info.region = &"garden"
	info.coord = level
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	print("  scenes in ", Rules.where(level), ", a floor ", run_len, " cells long")
	camera = main.get_node("Camera2D") as Camera2D
	base_zoom = camera.zoom
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	# Nothing hurts the wizard here: a touch would knock them about and flash them pink.
	player.hurt_ability = func(_d: int, _v: Vector2, _a: Node) -> void: pass
	# No region card over the frames.
	await until(func() -> bool: return RisoTransition.instance == null or not RisoTransition.instance.titling(), 15000)
	for scene: StringName in SCENES:
		if scene in wanted:
			await call(String(scene))
	RunState.delete_save()
	finish()


# ------------------------------------------------------------------ scenes

## The ferry: cast in the air facing right, the raft catches the wizard and carries them to the
## rock, turns back, and carries them back.
func ferry() -> void:
	var at: Vector2i = _run_to_rock(info.world, 3, 6)
	_clear_enemies(info.cell_position(at), 1600.0)
	Abilities.set_tier(player, &"ferry", 1)
	await _put(info.cell_position(at) + Vector2(0, -10), 1.0)
	follow = true
	await record(&"ferry", 170, func(f: int) -> void:
		if f == 4:
			Abilities.cast(player, &"move"))


## The slash: running right past wisps held still, slashing whenever it is ready; each mark goes
## with the wizard and narrows to a point behind.
func slash() -> void:
	var at: Vector2i = _floor_run(info.world, run_len)
	_clear_enemies(info.cell_position(at), 1600.0)
	Abilities.set_tier(player, &"slash", 1)
	var slash_node: Slash = player.get_node("Slash") as Slash
	# A wisp at the far end: the slashes before it cut only air, so the marks show going along.
	var wisp: Node2D = _wisp(at + Vector2i(run_len - 1, 0))
	await _put(info.cell_position(at) + Vector2(0, -15), 1.0)
	follow = true
	zoom = ZOOM * 1.4
	await record(&"slash", 90, func(f: int) -> void:
		if f == 3:
			Input.action_press("Right")
		if player.global_position.x > wisp.global_position.x - 150.0:
			Input.action_release("Right")
		if f > 6 and slash_node.wait <= 0.0:
			slash_node.cast(Vector2.RIGHT))
	Input.action_release("Right")
	zoom = ZOOM


## Thorns: a bed of thorns along a floor; the wizard drops in over its near end heading right and
## slashes down whenever the thorns come within reach, bouncing from one to the next, then on the
## spot halfway along.
func thorns() -> void:
	var at: Vector2i = _floor_run(info.world, run_len)
	_clear_enemies(info.cell_position(at), 1600.0)
	Abilities.set_tier(player, &"slash", 1)
	var slash_node: Slash = player.get_node("Slash") as Slash
	var bed: Array[Spikes] = []
	for k: int in range(1, 7):
		bed.append(_lay_thorns(at + Vector2i(k, 0)))
	var top: float = info.cell_position(at).y + Spikes.BODY.y * 4.0
	await _put(info.cell_position(at + Vector2i(1, -1)) + Vector2(-40, 0), 1.0)
	player.set_physics_process(false)
	follow = true
	await record(&"thorns", 120, func(f: int) -> void:
		if f == 2:
			player.set_physics_process(true)
			Input.action_press("Right")
		# Across half the bed, then bouncing on the spot (clear of the ledges over its far end).
		if player.global_position.x > bed[2].global_position.x:
			Input.action_release("Right")
		if player.velocity.y > 0.0 and player.global_position.y > top - 82.0 and slash_node.wait <= 0.0:
			slash_node.cast(Vector2.DOWN))
	Input.action_release("Right")
	for t: Spikes in bed:
		t.queue_free()


## Recoil: a push at nothing on the ground (a shove back), then the same in the air (thrown far),
## then a push down from the air (a big bounce), then a hex bolt in the air (a nudge).
func recoil() -> void:
	var at: Vector2i = _floor_run(info.world, run_len)
	_clear_enemies(info.cell_position(at), 1600.0)
	Abilities.set_tier(player, &"push", 1)
	await _put(info.cell_position(at + Vector2i(run_len - 1, 0)) + Vector2(0, -15), 1.0)
	follow = false
	fixed = info.cell_position(at + Vector2i(int(run_len / 2.0), -1))
	await record(&"recoil", 200, func(f: int) -> void: _recoil_step(f, at))


## The recoil scene's beat at frame `f`, on the floor run from `at`.
func _recoil_step(f: int, at: Vector2i) -> void:
	var push: Push = player.get_node_or_null("Push") as Push
	match f:
		6:
			push.cast(Vector2.RIGHT)
		40:
			player.global_position = info.cell_position(at + Vector2i(run_len - 1, 0)) + Vector2(0, -15)
			player.velocity = Vector2(0, player.JUMP_VELOCITY)
		52:
			push.wait = 0.0
			push.cast(Vector2.RIGHT)
		100:
			player.global_position = info.cell_position(at + Vector2i(int(run_len / 2.0), 0)) + Vector2(0, -15)
			player.velocity = Vector2(0, player.JUMP_VELOCITY * 0.5)
		112:
			push.wait = 0.0
			push.cast(Vector2.DOWN)
		150:
			Abilities.set_tier(player, &"hex", 1)
			player.global_position = info.cell_position(at + Vector2i(run_len - 2, 0)) + Vector2(0, -15)
			player.velocity = Vector2(0, player.JUMP_VELOCITY)
		162:
			(player.get_node("Hex") as Hex).refill()
			(player.get_node("Hex") as Hex).cast(Vector2.RIGHT)


## The lunge: lunges right along the floor, the third reaching a wisp and stabbing it; each streak
## stays where it was cast, the trail of the thrust.
func lunge() -> void:
	var at: Vector2i = _floor_run(info.world, run_len)
	_clear_enemies(info.cell_position(at), 1600.0)
	Abilities.set_tier(player, &"lunge", 2)
	_wisp(at + Vector2i(4, 0))
	await _put(info.cell_position(at) + Vector2(0, -15), 1.0)
	follow = false
	fixed = info.cell_position(at + Vector2i(int(run_len / 2.0), -1))
	await record(&"lunge", 90, func(f: int) -> void:
		var node: Lunge = player.get_node_or_null("Lunge") as Lunge
		if node != null and f in [8, 26, 44]:
			node.wait = 0.0
			node.cast(1.0)
		if f == 75:
			player.global_position = info.cell_position(at) + Vector2(0, -15))


## The seeker: at tier III, two seekers loosed straight ahead, each turning onto a wisp off its line
## (one up on the air, one down by the floor), and the cast's small throw back.
func seeker() -> void:
	var at: Vector2i = _floor_run(info.world, run_len)
	_clear_enemies(info.cell_position(at), 1600.0)
	Abilities.set_tier(player, &"seeker", 3)
	var high: Node2D = _wisp(at + Vector2i(run_len - 2, -2))
	var low: Node2D = _wisp(at + Vector2i(run_len - 1, 0))
	await _put(info.cell_position(at) + Vector2(0, -15), 1.0)
	follow = false
	fixed = info.cell_position(at + Vector2i(int(run_len / 2.0), -1))
	await record(&"seeker", 90, func(f: int) -> void:
		var node: Seeker = player.get_node_or_null("Seeker") as Seeker
		if node != null and f in [6, 50]:
			node.wait = 0.0
			node.cast(Vector2.RIGHT)
		if f == 46:
			player.global_position = info.cell_position(at) + Vector2(0, -15)
			for e: Node2D in [high, low]:
				(e.get_node("Wound") as Wound).hp = 99)


## The bindle, close up: the Fool casts each damage spell in turn from the Spell slot
## (Abilities.cast), swinging the bindle round to point the bag the spell's way: a slash ahead, a
## slash up, a hex, a nova (straight up), a push, a seeker and a lunge.
func bindle() -> void:
	var at: Vector2i = _floor_run(info.world, run_len)
	_clear_enemies(info.cell_position(at), 1600.0)
	var home: Vector2 = info.cell_position(at + Vector2i(1, 0)) + Vector2(0, -15)
	await _put(home, 1.0)
	follow = true
	zoom = ZOOM * 2.4
	lead = Vector2(10, -40)
	var beats: Dictionary = {5: [&"slash", Vector2.ZERO], 26: [&"slash", Vector2.UP], 47: [&"hex", Vector2.ZERO],
		68: [&"nova", Vector2.ZERO], 89: [&"push", Vector2.ZERO], 110: [&"seeker", Vector2.ZERO], 131: [&"lunge", Vector2.ZERO]}
	await record(&"bindle", 156, func(f: int) -> void:
		if f - 3 in beats:
			player.global_position = home
			player.velocity = Vector2.ZERO
			Abilities.set_tier(player, (beats[f - 3] as Array)[0], 1)
		if f in beats:
			var aim: Vector2 = (beats[f] as Array)[1]
			if aim == Vector2.UP:
				Input.action_press("Up")
			Abilities.cast(player, &"damage")
			Input.action_release("Up"))
	zoom = ZOOM
	lead = Vector2(0, -30)


## The crossbow: the wizard comes into sight of a crag tower's crossbow; its first arrow comes at
## once, as big in flight as it lay on the string; the next after its reload and draw.
func crossbow() -> void:
	var place: Vector2i = Vector2i.ZERO
	for k: int in range(NextWorldDef.BAND):
		var c: Vector2i = Vector2i(29, NextWorldDef.band_row(&"crags", k))
		var w: LevelGen = build(c)
		if w.objects_of(LevelGen.Type.CROSSBOW).any(func(v: Vector2i) -> bool: return _bow_open(w, v)):
			place = c
			break
	info.region = &"crags"
	info.coord = place
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var cell: float = info.cell_position(Vector2i(1, 0)).x - info.cell_position(Vector2i.ZERO).x
	var bow: Crossbow = null
	for n: Node in placed("crossbow.tscn"):
		var b: Crossbow = n as Crossbow
		if range(2, 6).all(func(k: int) -> bool: return not info.solid_at(info.cell_position(b.cell) + Vector2(float(b.facing) * cell * float(k), 0.0))):
			bow = b
			break
	if bow == null:
		print("no crossbow with open air before it")
		return
	var room: Vector2 = info.cell_position(bow.cell)
	var outside: Vector2 = room + Vector2(float(bow.facing) * cell * 4.0, 0.0)
	player.set_physics_process(false)
	player.global_position = outside + Vector2(0, 4000)
	await frames(90)
	follow = false
	fixed = (room + outside) * 0.5
	await record(&"crossbow", 110, func(f: int) -> void:
		if f == 10:
			player.global_position = outside
			info.loader.wake_around(outside))


# ------------------------------------------------------------------ recording

## Record `count` frames of scene `scene`, calling `step` with the frame's number before each.
func record(scene: StringName, count: int, step: Callable) -> void:
	var dir: String = ProjectSettings.globalize_path(STILLS).path_join("changes_gif").path_join(String(scene))
	DirAccess.make_dir_recursive_absolute(dir)
	for old: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))
	for f: int in range(count):
		step.call(f)
		for k: int in range(EVERY):
			_aim_camera()
			await physics_frame
		_aim_camera()
		await process_frame
		var image: Image = root.get_texture().get_image()
		var corner: Vector2i = (image.get_size() - CROP) / 2
		var region: Image = image.get_region(Rect2i(corner, CROP))
		region.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		region.save_png(dir.path_join("frame_%03d.png" % f))
	print("CAPTURED %d frames of %s" % [count, scene])


## The camera on the wizard (or the fixed point), at the capture's zoom.
func _aim_camera() -> void:
	camera.zoom = base_zoom * zoom
	camera.global_position = (player.global_position + lead) if follow else fixed
	camera.reset_smoothing()


# ------------------------------------------------------------------ setting up

## The wizard at `at`, physics on, facing `facing` (1 right, -1 left), after a moment to settle.
func _put(at: Vector2, facing: float) -> void:
	player.set_physics_process(true)
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.knock = Vector2.ZERO
	player.knock_back.end()
	player.end_invulnerable()
	player.sprite.scale.x = absf(player.sprite.scale.x) * facing
	for i: int in range(10):
		_aim_camera()
		await physics_frame


## Open air in level `w`, no thorns.
static func _open(w: LevelGen, v: Vector2i) -> bool:
	return w.is_valid(v) and not w.is_ground(v) and w.get_cell(v).type not in [LevelGen.Type.CRACKED, LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.SPIKES, LevelGen.Type.LASER]


## A floor cell starting a run of `n` open floor cells to its right (ground under each, two open
## rows over each), the run nearest the level's middle.
static func _floor_run(w: LevelGen, n: int) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var middle: Vector2 = Vector2(w.size) * 0.5
	for x: int in range(1, w.size.x - n - 1):
		for y: int in range(3, w.size.y - 2):
			var ok: bool = true
			for k: int in range(n):
				var v: Vector2i = Vector2i(x + k, y)
				ok = ok and _open(w, v) and _open(w, v + Vector2i.UP) and _open(w, v + Vector2i.UP * 2) and w.is_ground(v + Vector2i.DOWN)
				if not ok:
					break
			if ok and (best.x < 0 or Vector2(x, y).distance_to(middle) < Vector2(best).distance_to(middle)):
				best = Vector2i(x, y)
	return best


## An open cell in the air of level `w` with between `least` and `most` open cells to its right
## before rock (two open over and one under each), so a raft from it meets rock soon; (-1, -1)
## when there is none.
static func _run_to_rock(w: LevelGen, least: int, most: int) -> Vector2i:
	for y: int in range(3, w.size.y - 3):
		for x: int in range(2, w.size.x - most - 2):
			var v: Vector2i = Vector2i(x, y)
			if not (_open(w, v + Vector2i.LEFT) and _open(w, v + Vector2i.LEFT + Vector2i.UP)):
				continue
			var n: int = 0
			while n <= most and _open(w, v + Vector2i(n, 0)) and _open(w, v + Vector2i(n, -1)) and _open(w, v + Vector2i(n, -2)) and _open(w, v + Vector2i(n, 1)):
				n += 1
			if n >= least and n <= most and w.is_ground(v + Vector2i(n, 0)):
				return v
	return Vector2i(-1, -1)


## Thorns laid on the floor of cell `v`, pointing up, always out.
func _lay_thorns(v: Vector2i) -> Spikes:
	var t: Spikes = (load("res://prefabs/spikes.tscn") as PackedScene).instantiate() as Spikes
	info.map_elements.add_child(t)
	t.global_position = info.cell_position(v)
	return t


## A wisp held still on the floor of cell `v`, hard to kill.
func _wisp(v: Vector2i) -> Node2D:
	var e: Node2D = Placeables.scene(LevelGen.Type.ENEMY).instantiate() as Node2D
	LevelLoader.arm(e, info.here.depth)
	info.map_elements.add_child(e)
	e.get_node("Mover").set_physics_process(false)
	e.global_position = info.cell_position(v) + Vector2(0, 16.0)
	(e.get_node("Wound") as Wound).hp = 99
	return e


## The level's own enemies within `r` px of `at`, gone, so nothing wanders into a scene.
func _clear_enemies(at: Vector2, r: float) -> void:
	for n: Node in info.map_elements.get_children():
		var e: Node2D = n as Node2D
		if e != null and Placeables.has_flag(Placeables.type_of(e), &"enemy") and e.global_position.distance_to(at) < r:
			e.queue_free()


## Whether crossbow `v` in `w` has four cells of open air before its slit.
static func _bow_open(w: LevelGen, v: Vector2i) -> bool:
	var facing: int = int((w.get_cell(v).extra_info as Dictionary)["facing"])
	for k: int in range(2, 6):
		var c: Vector2i = v + Vector2i(facing * k, 0)
		if not w.is_valid(c) or w.is_ground(c):
			return false
	return true
