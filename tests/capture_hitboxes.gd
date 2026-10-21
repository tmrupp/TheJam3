extends TestKit
## Every kind of enemy close up, with its body (blue: what blocks and is stood on) and its hit box
## (pink: what hurts the wizard to touch) outlined over its art, to check the two fit what is
## printed. A strip per kind, written to ../art-captures/riso-frames/hitboxes/<prefab>.png.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_hitboxes.gd

## The places looked through for enemies, by band and row in the band.
const PLACES: Array = [[&"garden", 0], [&"garden", 1], [&"cemetery", 0], [&"cemetery", 1], [&"institute", 0], [&"institute", 1], [&"crags", 0], [&"crags", 1], [&"sky", 0], [&"sky", 1]]
## The part of the window kept, round the enemy in the middle.
const REGION: Rect2i = Rect2i(440, 160, 400, 400)
## Stills a kind, a few frames apart, so a moving enemy is seen in more than one pose.
const SHOTS: int = 4


func run() -> void:
	window()
	await boot()
	player.set_physics_process(false)
	player.invulnerable.enable()
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = Stage.camera()
	camera.position_smoothing_enabled = false
	var done: Dictionary = {}
	for place: Array in PLACES:
		info.coord = Vector2i(28, NextWorldDef.band_row(StringName(place[0]), int(place[1])))
		info.arrival = MapInfo.Exit.BACK
		info._load_level()
		await settle()
		player.set_physics_process(false)
		player.global_position = Vector2(-90000, -90000)
		RisoLight.by_sight = false
		for n: Node in info.map_elements.get_children():
			var file: String = n.scene_file_path.get_file()
			if done.has(file) or not n.has_node("Wound") or not n is CollisionObject2D:
				continue
			done[file] = true
			# A skeleton is seen standing, not asleep in its niche.
			var bones: Skeleton = n.get_node_or_null("Skeleton") as Skeleton
			if bones != null:
				bones.asleep = false
			await _shoot(n as Node2D, file.get_basename(), camera)
	finish()


## A strip of SHOTS stills of `enemy`, its shapes outlined, saved as `name`.
func _shoot(enemy: Node2D, name: String, camera: Camera2D) -> void:
	camera.limit_left = -10000000
	camera.limit_top = -10000000
	camera.limit_right = 10000000
	camera.limit_bottom = 10000000
	camera.zoom = Vector2.ONE * 0.5 * RisoPrint.instance.zoom_factor
	var strip: Image = Image.create(REGION.size.x * SHOTS, REGION.size.y, false, Image.FORMAT_RGBA8)
	for k: int in range(SHOTS):
		for f: int in range(15):
			if not is_instance_valid(enemy):
				return
			camera.global_position = enemy.global_position
			camera.reset_smoothing()
			await process_frame
		await RenderingServer.frame_post_draw
		var shot: Image = root.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		_outline(shot, enemy as CollisionObject2D, camera)
		strip.blit_rect(shot.get_region(REGION), Rect2i(Vector2i.ZERO, REGION.size), Vector2i(k * REGION.size.x, 0))
	save_still("hitboxes/%s.png" % name, strip)


## Outline on `shot` each shape of `body`: blue for the body, pink for a hit box (an Area2D's).
func _outline(shot: Image, body: CollisionObject2D, camera: Camera2D) -> void:
	var half: Vector2 = Vector2(shot.get_size()) * 0.5
	var centre: Vector2 = camera.get_screen_center_position()
	var to_screen: Callable = func(p: Vector2) -> Vector2: return (p - centre) * camera.zoom * (Vector2(shot.get_size()) / Vector2(root.get_visible_rect().size)) + half
	# A tick every 16 px round its origin (yellow), to measure the art against.
	var origin: Vector2 = to_screen.call(body.global_position)
	var px_per: float = (to_screen.call(body.global_position + Vector2(100, 0)) as Vector2).x - origin.x
	print("  %s: origin at %s on the window, %.3f window px a world px" % [body.name, origin, px_per / 100.0])
	for k: int in range(-8, 9):
		for d: int in range(-3, 4):
			for p: Vector2i in [Vector2i(origin + Vector2(k * 16.0 * px_per / 100.0, 0)) + Vector2i(0, d), Vector2i(origin + Vector2(0, k * 16.0 * px_per / 100.0)) + Vector2i(d, 0)]:
				if p.x >= 0 and p.y >= 0 and p.x < shot.get_width() and p.y < shot.get_height():
					shot.set_pixelv(p, Color(1.0, 0.9, 0.1))
	for node: Node in body.find_children("*", "CollisionShape2D", true, false):
		var cs: CollisionShape2D = node as CollisionShape2D
		if cs.shape == null or cs.disabled:
			continue
		var colour: Color = Color(1.0, 0.1, 0.55) if cs.get_parent() is Area2D else Color(0.1, 0.6, 1.0)
		var r: Rect2 = cs.shape.get_rect()
		var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for i: int in range(4):
			var a: Vector2 = to_screen.call(cs.global_transform * corners[i])
			var b: Vector2 = to_screen.call(cs.global_transform * corners[(i + 1) % 4])
			var steps: int = maxi(1, ceili(a.distance_to(b)))
			for t: int in range(steps + 1):
				var q: Vector2i = Vector2i(a.lerp(b, float(t) / float(steps)).round())
				for d: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
					var px: Vector2i = q + d
					if px.x >= 0 and px.y >= 0 and px.x < shot.get_width() and px.y < shot.get_height():
						shot.set_pixelv(px, colour)
