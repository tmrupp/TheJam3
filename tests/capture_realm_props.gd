extends TestKit
## The same small things close up in each band's realm, side by side, to compare how they print on
## each realm's inks (a realm whose rock ink is dark, as the institute's brown, can muddy what is
## shaded with it): a sheet, a row a band and a column a kind, written to
## ../art-captures/riso-frames/realm_props.png. A kind a level does not hold is left blank.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_realm_props.gd

## The bands, each by its first row.
const BANDS: Array[StringName] = [&"garden", &"cemetery", &"institute", &"crags", &"sky"]
## The kinds, by prefab.
const KINDS: Array[String] = ["moon.tscn", "mover_enemy.tscn", "coin.tscn", "key.tscn", "shooter_enemy.tscn", "hopper_enemy.tscn", "checkpoint.tscn"]
## The part of the window kept round each thing.
const REGION: Rect2i = Rect2i(490, 210, 300, 300)


func run() -> void:
	window()
	await boot()
	player.set_physics_process(false)
	player.invulnerable.enable()
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = Stage.camera()
	camera.position_smoothing_enabled = false
	var sheet: Image = Image.create(REGION.size.x * KINDS.size(), REGION.size.y * BANDS.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color.WHITE)
	for b: int in range(BANDS.size()):
		info.coord = Vector2i(28, NextWorldDef.band_row(BANDS[b], 0))
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.set_physics_process(false)
		player.global_position = Vector2(-90000, -90000)
		RisoLight.by_sight = false
		for k: int in range(KINDS.size()):
			var found: Array[Node] = placed(KINDS[k])
			if found.is_empty():
				continue
			var thing: Node2D = found[0] as Node2D
			camera.limit_left = -10000000
			camera.limit_top = -10000000
			camera.limit_right = 10000000
			camera.limit_bottom = 10000000
			for f: int in range(20):
				if not is_instance_valid(thing):
					break
				camera.zoom = Vector2.ONE * 0.5 * RisoPrint.instance.zoom_factor
				camera.global_position = thing.global_position + Vector2(0, -30)
				camera.reset_smoothing()
				await process_frame
			await RenderingServer.frame_post_draw
			var shot: Image = root.get_texture().get_image().get_region(REGION)
			shot.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, REGION.size), Vector2i(k * REGION.size.x, b * REGION.size.y))
	save_still("realm_props.png", sheet)
	finish()
