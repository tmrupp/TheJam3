extends TestKit
## A sheet of the lodestone golem (Golem) moving, frame by frame, to judge how it moves: a row
## walking after the wizard on all fours, a row turning round to face them behind it, a row of a slam
## (rearing back, raising its fists, bringing them down), a row of a hurl (a magnet held up high, then
## thrown), a row stunned by a parried slam (its pieces sagging, its shards flying out) and a row of a
## leap up through its gap.
## Written to golem_motion.png. With `-- gif`, each row is taken in many more frames, closer together,
## and every frame is written on its own instead (golem_motion/r<row>_<frame>.png), to make
## animations from.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_golem_motion.gd

## Frames in a row, and the size (px) of each cut from the view round the golem and how much it is
## shrunk on the sheet.
const FRAMES: int = 8
const CROP: Vector2i = Vector2i(560, 640)
const SHRINK: float = 0.5
## With `-- gif`: frames in each row, physics steps between them, and how much each is shrunk.
const GIF_FRAMES: Array[int] = [48, 24, 48, 60, 60, 60]
const GIF_STEPS: Array[int] = [2, 1, 1, 1, 2, 2]
const GIF_SHRINK: float = 0.6
## How far over its feet (px) the camera looks.
const LOOK_UP: float = 235.0

var camera: Camera2D
var golem: Golem
## The rows of frames taken so far, and whether every frame is written on its own (`-- gif`).
var rows: Array[Array] = []
var gif: bool = false


func run() -> void:
	gif = "gif" in OS.get_cmdline_user_args()
	window()
	await boot(28)
	info.coord = Vector2i(28, Bosses.row_of(&"golem"))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	golem = placed("golem.tscn")[0] as Golem
	camera = main.get_node("Camera2D") as Camera2D
	player.get_node("CameraControl").set_process(false)
	player.health.max_health = 99
	player.health.health = 99
	player.set_physics_process(false)
	for bow: Node in placed("crossbow.tscn"):
		bow.set_physics_process(false)
	golem.hurl_wait = INF
	var ground_y: float = golem.global_position.y - 20.0
	# Walking after the wizard far off along its floor.
	player.global_position = Vector2(golem.global_position.x - 900.0, ground_y)
	await within(func() -> bool: return golem.rise >= 1.0 and absf(golem.vel) > Golem.WALK * 0.9, 5.0)
	await _row(5)
	# Turning round: the wizard well behind it, out of reach of a slam.
	player.global_position = Vector2(golem.global_position.x - float(golem.face) * 500.0, ground_y)
	await within(func() -> bool: return golem.turning(), 2.0)
	await _row(3)
	# A slam: the wizard near in front of it.
	await within(func() -> bool: return not golem.turning() and golem.state == Golem.State.HUNT, 3.0)
	player.global_position = Vector2(golem.global_position.x + float(golem.face) * 200.0, ground_y)
	await within(func() -> bool: return golem.state == Golem.State.SLAM_WARN, 4.0)
	await _row(7)
	# A hurl: the wizard far off along its floor.
	await within(func() -> bool: return golem.state == Golem.State.HUNT, 4.0)
	player.global_position = Vector2(golem.global_position.x - 900.0, ground_y)
	player.end_invulnerable()
	golem.hurl_wait = 0.0
	await within(func() -> bool: return golem.state == Golem.State.HURL_WARN, 4.0)
	await _row(7)
	golem.hurl_wait = INF
	await within(func() -> bool: return golem.called.is_empty() and golem.stones.is_empty() and golem.state == Golem.State.HUNT, 12.0)
	# Stunned: the wizard near in front of it parries its slam.
	player.global_position = Vector2(golem.global_position.x + float(golem.face) * 200.0, ground_y)
	player.end_invulnerable()
	await within(func() -> bool: return golem.state == Golem.State.SLAM, 6.0)
	(player.get_node("Parry") as Parry).parry(1, Vector2.ZERO, golem.fists.get_node("Damager"))
	await _row(10)
	await within(func() -> bool: return golem.called.is_empty() and golem.shards.is_empty() and golem.state == Golem.State.HUNT, 12.0)
	player.end_invulnerable()
	# A leap: the wizard on the gallery over it.
	var box: Rect2i = info.world.keep["box"]
	var floors: Array[int] = info.world.keep["floors"]
	var stair: Rect2i = (info.world.keep["stairs"] as Array[Rect2i])[1]
	player.global_position = info.cell_position(Vector2i(stair.position.x + (3 if stair.position.x < box.get_center().x else -2), floors[1] - 1))
	await within(func() -> bool: return golem.state == Golem.State.LEAP_WARN and golem.timer < Golem.LEAP_WARN * 0.5, 15.0)
	await _row(9)
	if not gif:
		_save()
	RunState.delete_save()
	finish()


## Take a row of FRAMES, `steps` physics steps apart, the camera on the golem (with `-- gif`, the
## row's GIF_FRAMES, GIF_STEPS apart, each written on its own).
func _row(steps: int) -> void:
	var row: Array[Image] = []
	var count: int = GIF_FRAMES[rows.size()] if gif else FRAMES
	var every: int = GIF_STEPS[rows.size()] if gif else steps
	var shrink: float = GIF_SHRINK if gif else SHRINK
	for k: int in range(count):
		camera.global_position = golem.global_position + Vector2(0.0, -LOOK_UP)
		await process_frame
		await process_frame
		var shot: Image = root.get_texture().get_image()
		var view: Vector2i = shot.get_size()
		var cut: Image = shot.get_region(Rect2i((view - CROP) / 2, CROP))
		cut.resize(int(CROP.x * shrink), int(CROP.y * shrink), Image.INTERPOLATE_BILINEAR)
		row.append(cut)
		if gif:
			save_still("golem_motion/r%d_%02d.png" % [rows.size(), k], cut)
		for s: int in range(every):
			await physics_frame
	rows.append(row)


## Lay the rows out on one sheet and save it.
func _save() -> void:
	var cell_size: Vector2i = Vector2i(int(CROP.x * SHRINK), int(CROP.y * SHRINK))
	var first: Image = rows[0][0]
	var sheet: Image = Image.create(cell_size.x * FRAMES, cell_size.y * rows.size(), false, first.get_format())
	for r: int in range(rows.size()):
		for k: int in range(rows[r].size()):
			var frame: Image = rows[r][k]
			sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, cell_size), Vector2i(k * cell_size.x, r * cell_size.y))
	save_still("golem_motion.png", sheet)
