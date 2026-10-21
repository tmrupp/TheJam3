extends TestKit
## Stills of what the wizard carries and how they climb: the bag for every damage spell side by
## side (one shape for all), an exam paper and a key trailing them, standing and in the air, close
## and at the game's zoom (the paper in front of the bindle, its mark and tier readable), and the
## wizard climbing a rolling ladder in the institute, a strip of frames up it and down it.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_wizard_carry.gd

## A close view of the figure, room left for the bindle and what trails it.
const REGION: Rect2i = Rect2i(400, 60, 480, 560)
## The ladder strips' frames: how many, and the physics steps between them.
const CLIMB_FRAMES: int = 8
const CLIMB_GAP: int = 4

var wizard: RisoWizard
var camera: Camera2D
## The game's own zoom, as it booted.
var game_zoom: float = 1.0


func run() -> void:
	window()
	await boot()
	wizard = player.get_node("RisoWizard") as RisoWizard
	camera = Stage.camera()
	game_zoom = camera.zoom.x
	print("game zoom ", game_zoom)
	player.get_node("CameraControl").set_process(false)
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.position_smoothing_enabled = false
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	RisoPrint.instance.registration = &"locked"
	await _bags()
	await _papers()
	await _ladder()
	RunState.delete_save()
	finish()


## The view now, cut to `region`.
func _shot(region: Rect2i = REGION) -> Image:
	await RenderingServer.frame_post_draw
	var still: Image = root.get_texture().get_image().get_region(region)
	still.convert(Image.FORMAT_RGBA8)
	return still


## `shots` side by side.
func _strip(shots: Array[Image]) -> Image:
	var size: Vector2i = shots[0].get_size()
	var out: Image = Image.create(size.x * shots.size(), size.y, false, Image.FORMAT_RGBA8)
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(Vector2i.ZERO, size), Vector2i(k * size.x, 0))
	return out


## Look at the wizard from `zoom`, a little above their feet.
func _frame(zoom: float) -> void:
	# (No title card over the view.)
	if RisoTransition.instance != null:
		RisoTransition.instance.title_age = -1.0
	camera.zoom = Vector2.ONE * zoom
	camera.global_position = player.global_position + Vector2(0, -46)
	camera.reset_smoothing()


## A clear floor three cells wide, nothing in the cells over it.
func _clear_floor() -> Vector2i:
	for spot: Vector2i in info.world.free_floors():
		var clear: bool = true
		for x: int in range(-3, 4):
			for y: int in range(-3, 1):
				var cell: Vector2i = spot + Vector2i(x, y)
				if not info.world.is_valid(cell) or info.world.get_cell(cell).type != LevelGen.Type.EMPTY:
					clear = false
		if clear:
			return spot
	return info.world.free_floors()[0]


## Stand the wizard still on a clear floor, facing right, the rig at rest.
func _stand() -> void:
	player.set_physics_process(false)
	player.end_invulnerable()
	info.map_elements.process_mode = Node.PROCESS_MODE_DISABLED
	wizard.set_physics_process(false)
	wizard.t = 1.1
	wizard.head_y = 0.0
	wizard.bob = 0.0
	wizard.lean = 0.0
	wizard.fs = 1.0
	player.global_position = info.cell_position(_clear_floor()) + Vector2(0, 64 - wizard._feet_offset() * player.global_scale.y)


## Every damage spell's bag, side by side.
func _bags() -> void:
	_stand()
	var shots: Array[Image] = []
	for spell: StringName in Abilities.in_slot(&"damage"):
		Abilities.set_tier(player, spell, 1)
		RisoPrint.instance.robe_color = RisoPrint.ROBES[spell]
		_frame(0.9)
		await frames(3)
		shots.append(await _shot(Rect2i(400, 120, 300, 320)))
	save_still("wizard_carry/bags.png", _strip(shots))
	Abilities.set_tier(player, &"hex", 1)
	RisoPrint.instance.robe_color = RisoPrint.ROBES[&"hex"]


## An exam paper (and a key behind it) trailing the wizard: standing, then in the air, close and at
## the game's zoom.
func _papers() -> void:
	_stand()
	Abilities.set_tier(player, &"keyring", 1)
	player.keyring.set_all([2, KeyRing.paper(&"slash", 2)])
	var shots: Array[Image] = []
	for zoom: float in [0.7, game_zoom]:
		for air: bool in [false, true]:
			wizard.key_trail.clear()
			# Settled behind the shoulder, or lagging up behind a fall.
			for i: int in range(60):
				wizard._trail_keys(1.0 / 60.0)
			if air:
				for i: int in range(wizard.key_trail.size()):
					wizard.key_trail[i] += Vector2(-10.0 * float(i + 1), 28.0 + 14.0 * float(i))
			_frame(zoom)
			await frames(3)
			shots.append(await _shot())
	save_still("wizard_carry/papers.png", _strip(shots))
	player.keyring.clear()


## The wizard on the longest rolling ladder of the institute's first level: a strip climbing up it,
## one climbing down, and one holding still, each close.
func _ladder() -> void:
	info.coord = Vector2i(28, NextWorldDef.band_row(&"institute", 0))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	var best: RollingLadder = null
	for node: Node in placed("rolling_ladder.tscn"):
		var found: RollingLadder = node as RollingLadder
		if best == null or found.rungs > best.rungs:
			best = found
	check(best != null, "the institute has a rolling ladder")
	if best == null:
		return
	for node: Node in info.map_elements.get_children():
		if node is Scholar or node is Abomination:
			node.queue_free()
	info.map_elements.process_mode = Node.PROCESS_MODE_INHERIT
	wizard.set_physics_process(true)
	player.set_physics_process(true)
	player.end_invulnerable()
	for way: StringName in [&"Up", &"Down", &""]:
		var lift: float = player._feet_y() - player.global_position.y
		var start: float = (best.top_y() + best.foot_y()) * 0.5
		if way == &"Up":
			start = best.foot_y() - 40.0
		elif way == &"Down":
			start = best.top_y() + Player.LADDER_UNDER_STEP + 40.0
		player.global_position = Vector2(best.ladder_x(), start - lift)
		player.velocity = Vector2.ZERO
		player.ladder = best
		if way != &"":
			Input.action_press(way)
		var shots: Array[Image] = []
		for k: int in range(CLIMB_FRAMES):
			for i: int in range(CLIMB_GAP):
				await physics_frame
				_frame(0.7)
			await process_frame
			shots.append(await _shot(Rect2i(470, 40, 340, 560)))
		if way != &"":
			Input.action_release(way)
		check(player.ladder == best or way == &"Up", "still on the ladder for the %s strip" % way)
		save_still("wizard_carry/ladder_%s.png" % (String(way).to_lower() if way != &"" else "still"), _strip(shots))
	player.ladder = null
