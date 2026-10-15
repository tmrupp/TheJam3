extends TestKit
## Frame sequences of the attack tells and the feather's pop, for a page that plays them: a still
## every STEP physics steps (30 a second of game time), cropped to SHOT round what is looked at,
## each with the phase it shows, written to ../art-captures/attack-clips/<clip>/ as NNN.png and
## phases.txt (one phase a line). Clips: wisp (a lurch, world 28's first level), feather (spent,
## then filling again), skeleton (a swipe) and wraith (a dart), the last two in its first cemetery
## level. Game time runs on the default preset (Hard).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_attack_clips.gd

## Physics steps between stills, and the still's size (px).
const STEP: int = 2
const SHOT: Vector2i = Vector2i(640, 360)
## Where the clips go, under the project's parent folder.
const OUT: String = "res://../art-captures/attack-clips"

var camera: Camera2D
var base_zoom: Vector2
## The clip being recorded: its folder, how many stills so far, and their phases.
var clip_dir: String = ""
var count: int = 0
var phases: PackedStringArray = PackedStringArray()
var at: Vector2 = Vector2.ZERO


func run() -> void:
	window()
	await boot()
	camera = main.get_node("Camera2D") as Camera2D
	base_zoom = camera.zoom
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	await wisp()
	await feather()
	info.coord = Vector2i(28, NextWorldDef.first_depth(&"cemetery"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	await skeleton()
	await wraith()
	finish()


func wisp() -> void:
	player.global_position = Vector2(-9000, -9000)
	for other: Node in placed("mover_enemy.tscn").slice(1):
		other.queue_free()
	await process_frame
	var w: Node2D = placed("mover_enemy.tscn")[0] as Node2D
	var mover: Mover = w.get_node("Mover") as Mover
	var spot: Vector2i = floor_run(4)
	camera.zoom = base_zoom * 2.8
	mover.set_physics_process(false)
	w.global_position = info.cell_position(spot)
	await until(func() -> bool: return info.loader.is_awake(w))
	await frames(2)
	if mover.direction != 1:
		mover.turn()
	mover.turn_left = 0.0
	mover.lurch_wait = 0.0
	mover.set_physics_process(true)
	await within(func() -> bool: return mover.grounded, 1.0)
	await frames(30)
	player.end_invulnerable()
	player.global_position = w.global_position + Vector2(275, -15)
	look(w.global_position + Vector2(140, -30))
	var phase: Callable = func() -> String:
		if mover.winding >= 0.0:
			return "wind-up"
		if mover.lurching >= 0.0:
			return "lurch"
		if mover.resting > 0.0:
			return "rest"
		return "walk"
	await record("wisp", 2.4, phase)


func feather() -> void:
	player.global_position = info.respawn_marker.global_position
	player.set_physics_process(true)
	await until(func() -> bool: return player.is_on_floor())
	player.set_physics_process(false)
	camera.zoom = base_zoom * 3.5
	look(player.global_position + Vector2(-10, -70))
	player.dash.acted = false
	await frames(30)
	var phase: Callable = func() -> String:
		if player.dash.acted:
			return "spent"
		return "pop" if player.get_node("RisoWizard").costume.recharged < RisoCostume.RECHARGE_TIME else "charged"
	begin("feather")
	await hold(0.4, phase)
	player.dash.acted = true
	await hold(0.6, phase)
	player.dash.acted = false
	await hold(1.0, phase)
	end()


func skeleton() -> void:
	player.global_position = Vector2(-9000, -9000)
	var spot: Vector2i = floor_run(3, true)
	var node: Node2D = (load("res://prefabs/skeleton_enemy.tscn") as PackedScene).instantiate() as Node2D
	var bones: Skeleton = node.get_node("Skeleton") as Skeleton
	bones.asleep = false
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(spot)
	camera.zoom = base_zoom * 2.8
	look(node.global_position + Vector2(70, -45))
	await until(func() -> bool: return info.loader.is_awake(node))
	await frames(20)
	player.end_invulnerable()
	player.global_position = node.global_position + Vector2(150, -15)
	var phase: Callable = func() -> String:
		if bones.winding >= 0.0:
			return "wind-up"
		if bones.swiping >= 0.0:
			return "swipe"
		if bones.resting > 0.0:
			return "rest"
		return "walk"
	await record("skeleton", 2.2, phase)
	node.queue_free()
	await until(gone(node))


func wraith() -> void:
	player.global_position = Vector2(-9000, -9000)
	var spot: Vector2i = floor_run(3, true)
	var node: Node2D = (load("res://prefabs/wraith_enemy.tscn") as PackedScene).instantiate() as Node2D
	LevelLoader.arm(node, info.here.depth)
	info.map_elements.add_child(node)
	node.global_position = info.cell_position(spot) + Vector2(20, -60)
	var ghost: Wraith = node.get_node("Wraith") as Wraith
	camera.zoom = base_zoom * 1.9
	look(node.global_position + Vector2(120, 0))
	await until(func() -> bool: return info.loader.is_awake(node))
	player.end_invulnerable()
	player.global_position = node.global_position + Vector2(260, 50)
	info.snuff(player.global_position)
	var phase: Callable = func() -> String:
		if ghost.swelling >= 0.0:
			return "swell"
		if ghost.darting >= 0.0:
			return "dart"
		if ghost.resting > 0.0:
			return "hang"
		if ghost.recoil > 0.0:
			return "recoil"
		return "hunt"
	await record("wraith", 2.6, phase)
	info.relight()


## Record `seconds` of game time as clip `name`, each still's phase from `phase`.
func record(name: String, seconds: float, phase: Callable) -> void:
	begin(name)
	await hold(seconds, phase)
	end()


func begin(name: String) -> void:
	clip_dir = ProjectSettings.globalize_path(OUT).path_join(name)
	DirAccess.make_dir_recursive_absolute(clip_dir)
	count = 0
	phases = PackedStringArray()


## `seconds` of game time, a still every STEP physics steps.
func hold(seconds: float, phase: Callable) -> void:
	for i: int in range(roundi(seconds * float(Engine.physics_ticks_per_second) / float(STEP))):
		await frames(STEP)
		look(at)
		await process_frame
		var whole: Image = root.get_texture().get_image()
		whole.get_region(Rect2i((whole.get_size() - SHOT) / 2, SHOT)).save_png(clip_dir.path_join("%03d.png" % count))
		phases.append(String(phase.call()))
		count += 1


func end() -> void:
	var f: FileAccess = FileAccess.open(clip_dir.path_join("phases.txt"), FileAccess.WRITE)
	f.store_string("\n".join(phases) + "\n")
	f.close()
	print("CAPTURED %s: %d stills" % [clip_dir.get_file(), count])


## Keep the camera on `where`, unclamped by the level's edges.
func look(where: Vector2) -> void:
	at = where
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	camera.global_position = where
	camera.reset_smoothing()


## A floor cell with `n` more open floor cells to its right in a row (open over them too), away
## from the lanterns if `dark`; (-1, -1) if there is none.
func floor_run(n: int, dark: bool = false) -> Vector2i:
	var w: LevelGen = info.world
	for v: Vector2i in w.free_floors():
		var ok: bool = true
		for k: int in range(n + 1):
			var c: Vector2i = v + Vector2i(k, 0)
			if not w.is_valid(c) or w.is_ground(c) or not w.ground_below(c) or w.is_ground(c + Vector2i.UP) \
					or w.get_cell(c).type in [LevelGen.Type.DOOR, LevelGen.Type.SWITCH_GATE, LevelGen.Type.SPIKES, LevelGen.Type.PLATFORM, LevelGen.Type.LASER]:
				ok = false
				break
		if ok and dark:
			for lantern: Node in placed("checkpoint.tscn"):
				if (lantern as Node2D).global_position.distance_to(info.cell_position(v)) < RisoLight.RESPAWN_REACH + 100.0:
					ok = false
		if ok:
			return v
	return Vector2i(-1, -1)
