extends TestKit
## Stills of the crags' lodestones and empowered spells (Lodestone, Spire, Empower), in the first crag
## level from world 28 holding a lodestone: the stone untouched and touched; a warm tower's spire, a
## cold one beside its switch, and a spire crackling as an empowered bolt strikes it; the wizard's bag
## with empowerment ready, recharging and held; a plain and an empowered hex bolt in flight; a
## cracked wall before and as an empowered nova shatters it; and the map (the level's page with its
## lodestone, and the worlds page once the gondola's top has inked the levels round). Written to
## crags-lodestones/ in the stills folder.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_lodestones.gd

const DIR: String = "crags-lodestones/"
var camera: Camera2D


func run() -> void:
	window()
	await boot(28)
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.end_invulnerable()
	player.health.max_health = 99
	player.health.health = 99
	# A level holding a lodestone with another in a level beside it, so the worlds map shows one.
	var row: int = NextWorldDef.band_row(&"crags", 0)
	var at: Vector2i = Vector2i(28, row)
	while Rules.lodestone_at(at) == &"" or [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)].all(func(d: Vector2i) -> bool: return Rules.lodestone_at(at + d) == &""):
		at.x += 1
	info.coord = at
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	_clear_foes()
	# The region's title card gone.
	await within(func() -> bool: return false, 4.0)
	var zoom: Vector2 = camera.zoom
	await _stone(zoom)
	await _spires(zoom)
	await _bag(zoom)
	await _bolts(zoom)
	await _break(zoom)
	await _map()
	camera.zoom = zoom
	RunState.delete_save()
	finish()


## A still of the window as `file` (see save_still), and beside it in web/ a JPEG of its middle
## (WEB_CROP of it) for pages that show the stills.
const WEB_CROP: Vector2 = Vector2(0.7, 0.8)


func still(file: String, part: Vector2 = WEB_CROP) -> void:
	save_still(DIR + file)
	var image: Image = root.get_texture().get_image()
	var size: Vector2i = Vector2i(Vector2(image.get_size()) * part)
	var crop: Image = image.get_region(Rect2i((image.get_size() - size) / 2, size))
	var path: String = ProjectSettings.globalize_path(STILLS).path_join(DIR + "web/" + file.get_basename() + ".jpg")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	crop.save_jpg(path, 0.86)


## The camera on `at` for a moment, then a still of the window as `file`.
func look_at(at: Vector2, file: String, settle_frames: int = 20) -> void:
	for i: int in range(settle_frames):
		camera.global_position = at
		camera.reset_smoothing()
		await process_frame
	still(file)


## Every foe and shot taken out of the level, so nothing strikes the wizard in a still.
func _clear_foes() -> void:
	for n: Node in info.map_elements.get_children():
		if not n.has_meta(&"cell"):
			if n is Bullet:
				n.queue_free()
			continue
		var type: int = info.world.get_cell(n.get_meta(&"cell")).type
		if Placeables.has_flag(type, &"enemy") or type == LevelGen.Type.STALACTITE:
			n.queue_free()


## Stand the wizard (still) at `pos`.
func stand(pos: Vector2) -> void:
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.global_position = pos
	info.loader.wake_around(pos)


func _stone(zoom: Vector2) -> void:
	var stone: Lodestone = placed("lodestone.tscn")[0] as Lodestone
	print("lodestone of %s at %s" % [stone.spell, info.cell_at(stone.global_position)])
	stand(stone.global_position + Vector2(-260, 0))
	Abilities.set_tier(player, stone.spell, 1)
	camera.zoom = zoom * 1.4
	await look_at(stone.global_position + Vector2(-80, -60), "lodestone_untouched.png")
	camera.zoom = zoom * 0.6
	await look_at(stone.global_position + Vector2(0, -60), "lodestone_in_place.png")
	camera.zoom = zoom * 1.4
	info.touch_lodestone(stone.spell)
	stone.touched_at = Lodestone.now()
	await look_at(stone.global_position + Vector2(-80, -60), "lodestone_flare.png", 4)
	await look_at(stone.global_position + Vector2(-80, -60), "lodestone_touched.png", 60)
	for spell: StringName in Abilities.in_slot(&"damage"):
		info.run.tempered[spell] = true


func _spires(zoom: Vector2) -> void:
	var spires: Array[Node] = placed("spire.tscn")
	if spires.size() < 2:
		print("only %d spires" % spires.size())
		return
	var warm: Spire = spires[0] as Spire
	var cold: Spire = spires[1] as Spire
	info.world.towers[warm.tower]["cold"] = false
	info.world.towers[cold.tower]["cold"] = true
	info.record().woken.erase(cold.tower)
	camera.zoom = zoom * 1.8
	stand(warm.global_position + Vector2(-200, 0))
	await look_at(warm.global_position + Vector2(-60, -30), "spire_warm.png")
	stand(cold.global_position + Vector2(-200, 0))
	await look_at(cold.global_position + Vector2(-60, -30), "spire_cold.png")
	# The cold tower's switch board.
	for n: Node in placed("tower_switch.tscn", true):
		var lever: TowerSwitch = n as TowerSwitch
		if lever.tower == cold.tower:
			stand(lever.global_position + Vector2(-150, 0))
			camera.zoom = zoom * 2.2
			await look_at(lever.global_position + Vector2(0, -110), "tower_switch_cold.png")
		elif lever.tower == warm.tower:
			stand(lever.global_position + Vector2(-150, 0))
			camera.zoom = zoom * 2.2
			await look_at(lever.global_position + Vector2(0, -110), "tower_switch_warm.png")
	# An empowered bolt striking the warm spire.
	info.last_tower = -1
	var from: Vector2 = warm.head() + Vector2(-300.0, 0.0)
	if info.solid_at(from):
		from = warm.head() + Vector2(300.0, 0.0)
	stand(from + Vector2(0, 30))
	camera.zoom = zoom * 1.1
	for i: int in range(10):
		camera.global_position = (from + warm.head()) * 0.5
		camera.reset_smoothing()
		await process_frame
	var bolt: HexBolt = HexBolt.new()
	bolt.dir = (warm.head() - from).normalized()
	bolt.empowered = true
	info.map_elements.add_child(bolt)
	bolt.global_position = from
	await until(func() -> bool: return warm.struck_at > 0.0, 3000)
	await process_frame
	await process_frame
	still("spire_struck.png")


func _bag(zoom: Vector2) -> void:
	var stand_at: Vector2 = info.cell_position(info.world.exits[MapInfo.Exit.BACK])
	player.set_physics_process(true)
	player.global_position = stand_at
	player.velocity = Vector2.ZERO
	Abilities.set_tier(player, &"hex", 1)
	var empower: Empower = Empower.of(player)
	await frames(30)
	camera.zoom = zoom * 3.0
	empower.wait = 0.0
	await look_at(player.global_position + Vector2(0, -50), "bag_ready.png")
	empower.wait = Empower.recharge() * 0.6
	await look_at(player.global_position + Vector2(0, -50), "bag_recharging.png", 6)
	empower.wait = 0.0
	empower.held = Empower.HOLD * 0.75
	player.set_physics_process(false)
	await look_at(player.global_position + Vector2(0, -50), "bag_held.png", 6)
	empower.held = -1.0
	player.set_physics_process(true)


func _bolts(zoom: Vector2) -> void:
	camera.zoom = zoom * 1.8
	var from: Vector2 = player.global_position + Vector2(0, -44)
	var dir: Vector2 = Vector2.RIGHT if not info.solid_at(from + Vector2(300, 0)) else Vector2.LEFT
	for empowered: bool in [false, true]:
		var bolt: HexBolt = HexBolt.new()
		bolt.dir = dir
		bolt.empowered = empowered
		info.map_elements.add_child(bolt)
		bolt.global_position = from
		for i: int in range(7):
			camera.global_position = from + dir * 110.0
			camera.reset_smoothing()
			await physics_frame
		await process_frame
		still(("bolt_empowered.png" if empowered else "bolt_plain.png"))
		await frames(40)


func _break(zoom: Vector2) -> void:
	# A cracked wall with open air beside it along its row.
	var pick: Array = []
	for n: Node in placed("cracked_wall.tscn"):
		if n.has_meta(&"secret"):
			continue
		var c: Vector2i = n.get_meta(&"cell")
		for s: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT]:
			if pick.is_empty() and info.world.get_cell(c + s).type == LevelGen.Type.EMPTY:
				pick = [c, c + s]
	if pick.is_empty():
		print("no cracked wall to break")
		return
	var wall: Vector2i = pick[0]
	var by: Vector2i = pick[1]
	camera.zoom = zoom * 1.5
	stand(info.cell_position(by) + Vector2(0, 16 - 31))
	Abilities.set_tier(player, &"nova", 1)
	await look_at(info.cell_position(wall).lerp(info.cell_position(by), 0.5), "crack_before.png")
	var nova: Nova = player.get_node("Nova") as Nova
	nova.wait = 0.0
	nova.cast(false)
	await frames(3)
	still("crack_plain_nova.png")
	await frames(40)
	nova.wait = 0.0
	nova.cast(true)
	await frames(3)
	still("crack_empowered_nova.png")
	await frames(60)
	await look_at(info.cell_position(wall).lerp(info.cell_position(by), 0.5), "crack_after.png", 10)


func _map() -> void:
	# Ride to the top, as far as the map is concerned: the levels round inked whole.
	info.ink_neighbours()
	info.ink_whole_map()
	await frames(30)
	var map: Node = main.get_node("RisoMap")
	map.call("toggle")
	await frames(20)
	still("map_level.png", Vector2.ONE)
	map.call("page", 1)
	await frames(20)
	still("map_worlds.png", Vector2.ONE)
	map.call("toggle")
