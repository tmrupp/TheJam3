extends TestKit
## Frames for a GIF of the bramble's finale (Bramble), played in real physics with the camera on the
## head of its shaft: the knot at rest, the last bulb bursting and the knot splitting to bare its
## heart (the bud), barbs dropping at the wizard on the top ledge, four slashes into the bud, and its
## death: every vine drying from the bud out and drawing back into the rock, then the relic on the
## landing. Frames go to the stills folder's bramble_gif/ as frame_NNN.png, a frame every EVERY
## physics steps (played at 30 frames a second); turn them into a GIF with ffmpeg.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_bramble_gif.gd

## How many physics steps apart frames are taken, the middle of the window taken, the size it is
## scaled to, how many cells of the shaft the view is tall, and how long (frames) the level's title
## is given to clear first.
const EVERY: int = 2
const CROP: Vector2i = Vector2i(720, 720)
const SIZE: Vector2i = Vector2i(480, 480)
const VIEW_CELLS: float = 6.5
const SETTLE: int = 480
## The frames the last bulb bursts at, the wizard slashes the bud at, and how many frames are
## recorded after the bramble is slain.
const LAST_BULB: int = 20
const SLASHES: Array[int] = [80, 110, 140, 170]
const TAIL: int = 40

var camera: Camera2D
var zoom: Vector2 = Vector2.ONE
var bramble: Bramble
var head: Vector2 = Vector2.ZERO


func run() -> void:
	window()
	await boot(28)
	info.coord = Vector2i(28, -Bands.garden_rows())
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	bramble = placed("bramble.tscn")[0] as Bramble
	camera = main.get_node("Camera2D") as Camera2D
	zoom = Vector2.ONE * root.get_visible_rect().size.y / (VIEW_CELLS * bramble.cell)
	player.get_node("CameraControl").set_process(false)
	info.run.vulnerable = false
	player.health.max_health = 99
	player.health.health = 99
	Abilities.set_tier(player, &"slash", 1)
	# The shaft's middle, its roof a little under the top of the view.
	var shaft_x: float = bramble.center(bramble.inside.position).x + float(bramble.inside.size.x - 1) * bramble.cell * 0.5
	head = Vector2(shaft_x, bramble.knot_rect.position.y - bramble.cell * 0.4 + VIEW_CELLS * bramble.cell * 0.5)
	# Every bulb but one burst before it starts: the shaft as it is near the fight's end.
	var last: BrambleBulb = null
	for b: BrambleBulb in bramble.bulbs:
		if last == null:
			last = b
			continue
		bramble.bloom_on(b)
		b.wound.hit(Bramble.BULB_HP, Vector2.RIGHT)
	bramble.bloom_on(last)
	# The wizard on the top ledge, beside where the bud will hang.
	var ledge: Vector2i = info.world.shaft["ledges"][0]
	player.global_position = info.cell_position(ledge + Vector2i.UP)
	player.set_physics_process(false)
	still()
	for i: int in range(SETTLE):
		_aim()
		await process_frame
	var dir: String = ProjectSettings.globalize_path(STILLS).path_join("bramble_gif")
	DirAccess.make_dir_recursive_absolute(dir)
	for old: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(old))
	var f: int = 0
	var slain_at: int = -1
	while slain_at < 0 or f < slain_at + TAIL:
		if f == LAST_BULB:
			last.wound.hit(last.wound.hp, Vector2.RIGHT)
		if f in SLASHES and is_instance_valid(bramble) and bramble.heart != null and bramble.heart.alive:
			_slash(bramble.heart)
		if slain_at < 0 and (not is_instance_valid(bramble) or bramble.slain):
			slain_at = f
		for k: int in range(EVERY):
			_aim()
			await physics_frame
		_aim()
		await process_frame
		var image: Image = root.get_texture().get_image()
		var corner: Vector2i = (image.get_size() - CROP) / 2
		var region: Image = image.get_region(Rect2i(corner, CROP))
		region.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		region.save_png(dir.path_join("frame_%03d.png" % f))
		f += 1
		if f > 600:
			break
	print("CAPTURED %d frames of the bramble's finale" % f)
	RunState.delete_save()
	finish()


## A slash at the bud from the top ledge; if it does not reach, the blow lands anyway, so the
## GIF shows all four.
func _slash(heart: BrambleHeart) -> void:
	var hp: int = heart.wound.hp
	var slash: Slash = player.get_node("Slash") as Slash
	slash.wait = 0.0
	player.sprite.scale.x = absf(player.sprite.scale.x) * signf(heart.global_position.x - player.global_position.x)
	slash.cast((heart.global_position - SpellStrike.origin(player)).normalized())
	await physics_frame
	await physics_frame
	if is_instance_valid(heart) and heart.alive and heart.wound.hp == hp:
		heart.wound.hit(1, (heart.global_position - player.global_position).normalized())


## The camera on the head of the shaft, VIEW_CELLS tall.
func _aim() -> void:
	camera.zoom = zoom
	camera.global_position = head
	camera.reset_smoothing()
