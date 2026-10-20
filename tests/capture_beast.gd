extends TestKit
## Stills of the eldritch beast (Beast): asleep in its chamber (beast_0.png); awake, its eyes open
## for its souls, a tentacle bursting up under the wizard (beast_1.png) and one lashing along the
## floor (beast_2.png); a soul in a garden level with abominations round it (beast_soul.png); and
## every soul gone, its great eye open (beast_3.png); then the worlds map with the souls marked
## (beast_map_level.png, beast_map.png).
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_beast.gd

## Levels marked visited before it wakes.
const VISITED: Array[Vector2i] = [Vector2i(28, 0), Vector2i(28, 1), Vector2i(28, 2), Vector2i(27, 1), Vector2i(29, 2), Vector2i(28, 4),
	Vector2i(28, 5), Vector2i(30, 1), Vector2i(28, -1), Vector2i(28, -2), Vector2i(26, 0), Vector2i(28, 11), Vector2i(28, 3)]

var camera: Camera2D


func run() -> void:
	window()
	await boot(28)
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	process_frame.connect(func() -> void: player.health.health = player.health.max_health)
	for c: Vector2i in VISITED:
		info.run.record(c)
	var gate: Vector2i = Vector2i(28, Bosses.row_of(&"beast"))
	await _go(gate)
	# The region's title card gone.
	await frames(240)
	var beast: Beast = placed("beast.tscn")[0] as Beast
	var view: Vector2 = beast.global_position + Vector2(0, -60)
	# Asleep: the wizard out of reach.
	player.global_position = beast.global_position + Vector2(-2000, -2000)
	await _look(view, "beast_0.png", 0.8)
	# Awake: a tentacle under the wizard, a few cells off.
	player.global_position = beast.global_position + Vector2(-520, 60)
	await until(func() -> bool: return beast.awake)
	beast.attack_in = 0.0
	beast.attacks = 0
	await until(func() -> bool: return beast.slam.hurts() and beast.slam.length >= beast.slam.full * 0.95)
	await _look(view + Vector2(-200, 0), "beast_1.png", 0.8)
	await until(func() -> bool: return not beast.slam.busy())
	beast.attacks = SWEEP_PREV
	beast.attack_in = 0.0
	await until(func() -> bool: return beast.sweep.busy() and beast.sweep.length >= beast.sweep.full * 0.95)
	await _look(view + Vector2(-200, 0), "beast_2.png", 0.8)
	# A soul.
	var at: Vector2i = Vector2i(29, 2) if info.run.souls.has(Vector2i(29, 2)) else info.run.souls.keys()[0]
	await _go(at)
	await frames(240)
	var soul: BeastSoul = placed("beast_soul.tscn")[0] as BeastSoul
	player.global_position = soul.global_position + Vector2(-2000, -2000)
	await _look(soul.global_position + Vector2(0, -40), "beast_soul.png", 1.4)
	# The worlds map, the souls marked.
	await _map("beast_map.png")
	# Every soul gone: its great eye open.
	for c: Vector2i in info.run.souls.keys():
		BeastSouls.destroyed(info.run, c)
	await _go(gate)
	await frames(240)
	beast = placed("beast.tscn")[0] as Beast
	player.global_position = beast.global_position + Vector2(-700, 60)
	await until(func() -> bool: return beast.awake)
	beast.attack_in = 99.0
	(beast.get_node("Wound") as BeastWound).hit(1, Vector2.RIGHT)
	(beast.get_node("Wound") as BeastWound).hit(1, Vector2.RIGHT)
	await frames(20)
	await _look(view, "beast_3.png", 0.8)
	RunState.delete_save()
	finish()

## The strike count just before a sweep (Beast.SWEEP_EVERY).
const SWEEP_PREV: int = Beast.SWEEP_EVERY - 1


func _go(at: Vector2i) -> void:
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)


## The map open on this level's page (`file` with _level), then on the worlds page (`file`).
func _map(file: String) -> void:
	var map: Node = main.get_node("RisoMap")
	map.call("toggle")
	await frames(20)
	save_still(file.get_basename() + "_level.png")
	map.call("page", 1)
	await frames(20)
	save_still(file)
	map.call("close")
	await frames(4)


## The camera on `at` (zoomed by `zoom`) for a moment, then a still of the window as `file`.
func _look(at: Vector2, file: String, zoom: float = 1.0) -> void:
	var was: Vector2 = camera.zoom
	camera.zoom = was * zoom
	info.loader.wake_around(at)
	for i: int in range(30):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	save_still(file)
	camera.zoom = was
