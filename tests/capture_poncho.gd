extends TestKit
## The Fool in each cut of their poncho (RisoCostume.PONCHOS, RisoPrint.PONCHO_STYLES) side by side:
## close up (poncho_cuts.png) and at the game's own zoom (poncho_cuts_game.png), in that order left to
## right and in rows of COLUMNS, written to ../art-captures/riso-frames/.
## Run windowed: godot --path . --windowed --resolution 1280x720 --script res://tests/capture_poncho.gd

## The close view, round the Fool, and the view at the game's zoom.
const REGION: Rect2i = Rect2i(470, 190, 340, 420)
const GAME_REGION: Rect2i = Rect2i(590, 300, 100, 140)
## How many cuts to a row.
const COLUMNS: int = 7


func run() -> void:
	window()
	await boot()
	player.set_physics_process(false)
	player.end_invulnerable()
	info.map_elements.process_mode = Node.PROCESS_MODE_DISABLED
	var wizard: RisoWizard = player.get_node("RisoWizard") as RisoWizard
	wizard.set_physics_process(false)
	wizard.t = 1.1
	wizard.head_y = 0.0
	wizard.bob = 0.0
	wizard.lean = 0.0
	wizard.fs = 1.0
	var riso: RisoPrint = RisoPrint.instance
	riso.registration = &"locked"
	player.get_node("CameraControl").set_process(false)
	var floor_at: Vector2i = _clear_floor()
	player.global_position = info.cell_position(floor_at) + Vector2(0, 64 - wizard._feet_offset() * player.global_scale.y)
	info.loader.sleep_far_chunks(true)
	var camera: Camera2D = Stage.camera()
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.position_smoothing_enabled = false
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	# Past the level's title.
	await create_timer(4.0).timeout
	var styles: Array[StringName] = RisoPrint.PONCHO_STYLES
	for game: bool in [false, true]:
		var region: Rect2i = GAME_REGION if game else REGION
		@warning_ignore("integer_division")
		var rows: int = (styles.size() + COLUMNS - 1) / COLUMNS
		var strip: Image = Image.create(region.size.x * mini(COLUMNS, styles.size()), region.size.y * rows, false, Image.FORMAT_RGBA8)
		for k: int in range(styles.size()):
			riso.poncho_style = styles[k]
			camera.zoom = Vector2.ONE * (0.25 * riso.zoom_factor if game else 0.7)
			camera.global_position = player.global_position + Vector2(0, -30 if game else -46)
			camera.reset_smoothing()
			await frames(3)
			await RenderingServer.frame_post_draw
			var still: Image = root.get_texture().get_image().get_region(region)
			still.convert(Image.FORMAT_RGBA8)
			@warning_ignore("integer_division")
			strip.blit_rect(still, Rect2i(Vector2i.ZERO, region.size), Vector2i((k % COLUMNS) * region.size.x, (k / COLUMNS) * region.size.y))
		save_still("poncho_cuts_game.png" if game else "poncho_cuts.png", strip)
	riso.poncho_style = RisoCostume.WORN
	finish()


## An empty patch of floor with headroom, away from the starting lantern and other props.
func _clear_floor() -> Vector2i:
	for spot: Vector2i in info.world.free_floors():
		var clear: bool = true
		for x: int in range(-2, 3):
			for y: int in range(-2, 1):
				var cell: Vector2i = spot + Vector2i(x, y)
				if not info.world.is_valid(cell) or info.world.get_cell(cell).type != LevelGen.Type.EMPTY:
					clear = false
		if clear:
			return spot
	return info.world.free_floors()[0]
