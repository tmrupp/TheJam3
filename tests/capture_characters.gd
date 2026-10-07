extends TestKit
## Render the selectable travelers and their state cues in the real game, close and at game zoom.
## Run windowed: godot --path . --windowed --resolution 1280x720 --script res://tests/capture_characters.gd.

## Review stills live with the concept sheets, outside Godot's imported resources.
const OUTPUT: String = "res://docs/mockups/wizard-replacements/game-captures"
## Close views leave room for the cape, staff, bindle and carried lantern.
const REGION: Rect2i = Rect2i(430, 90, 420, 500)
## Spell and protection combinations shown for every appearance.
const SHOTS: Array[StringName] = [&"hex", &"unprotected", &"smoke_trail", &"spent_dash", &"astral", &"awareness"]


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
	var floor: Vector2i = _clear_floor()
	player.global_position = info.cell_position(floor) + Vector2(0, 64 - wizard._feet_offset() * player.global_scale.y)
	info.loader.sleep_far_chunks(true)
	var camera: Camera2D = Stage.camera()
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.position_smoothing_enabled = false
	camera.limit_left = -100000
	camera.limit_top = -100000
	camera.limit_right = 100000
	camera.limit_bottom = 100000
	var path: String = ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(path)
	for shot: StringName in SHOTS:
		var strip: Image = Image.create(REGION.size.x * 3, REGION.size.y, false, Image.FORMAT_RGBA8)
		for index: int in range(1, RisoPrint.CHARACTER_STYLES.size()):
			riso.set_character_style(RisoPrint.CHARACTER_STYLES[index])
			Abilities.set_tier(player, shot if shot in [&"astral", &"awareness"] else &"hex", 1)
			player.health.health = 1 if shot == &"unprotected" else 3
			info.run.vulnerable = shot in [&"unprotected", &"smoke_trail"]
			player.dash.acted = shot == &"spent_dash"
			if info.run.vulnerable:
				if shot == &"smoke_trail":
					player.global_position.x -= 216.0
				for step: int in range(18):
					wizard._step_smoke(RisoWizard.SMOKE_STEP)
					if shot == &"smoke_trail":
						player.global_position.x += 12.0
			camera.zoom = Vector2.ONE * 0.7
			camera.global_position = player.global_position + Vector2(0, -46)
			camera.reset_smoothing()
			riso.robe_color = RisoPrint.ROBES[Abilities.spell(player)]
			await frames(3)
			await RenderingServer.frame_post_draw
			var still: Image = root.get_texture().get_image().get_region(REGION)
			still.convert(Image.FORMAT_RGBA8)
			strip.blit_rect(still, Rect2i(Vector2i.ZERO, REGION.size), Vector2i((index - 1) * REGION.size.x, 0))
		strip.save_png(path.path_join(String(shot) + "_comparison.png"))
	# The actual gameplay camera, rather than just the enlarged drawing.
	info.run.vulnerable = false
	player.health.health = 3
	player.dash.acted = false
	Abilities.set_tier(player, &"hex", 1)
	for style: StringName in [&"cosmonaut", &"shaman", &"fool"]:
		riso.set_character_style(style)
		camera.zoom = Vector2.ONE * 0.25 * riso.zoom_factor
		camera.global_position = player.global_position + Vector2(0, -30)
		camera.reset_smoothing()
		await frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path.path_join(String(style) + "_gameplay.png"))
	# The actual selector, unfolded and scrolled into view.
	riso.panel.visible = true
	var section: Array = riso._sections["Look"]
	if not (section[1] as VBoxContainer).visible:
		(section[0] as Button).pressed.emit()
	var picker: OptionButton = riso._options[&"character"] as OptionButton
	var scroll: ScrollContainer = riso.panel.get_child(0) as ScrollContainer
	await process_frame
	scroll.ensure_control_visible(picker)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path.path_join("f7_characters.png"))
	print("CAPTURED character comparisons: ", path)
	finish()


## Find an empty patch of floor with headroom, away from the starting lantern and other props.
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
