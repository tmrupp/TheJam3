extends TestKit
## Windowed close-ups of wisps turning round on their teardrops: for each of a few wisps, a strip
## of frames through its turn (wisp_turn.png holds the first), and all of them side by side, a few
## frames of each turn laid over one another with the head's path marked (wisp_turn_drops.png).
## godot --path . --windowed --resolution 1280x720 --fixed-fps 60 --script res://tests/capture_wisp_turn.gd
## (--fixed-fps keeps every frame a 60th of a second where drawing is slow, so a turn still has
## its 42 frames.)

## The part of the window kept, round the wisp.
const CROP: Rect2i = Rect2i(340, 135, 600, 450)
## How many wisps' turns are recorded, and frames kept through each turn for its strip.
const TURNS: int = 3
const STRIP: int = 8
## Frames of each turn laid over one another.
const OVERLAY: int = 6


func run() -> void:
	window()
	await boot()
	player.set_physics_process(false)
	player.get_node("CameraControl").set_process(false)
	player.global_position = Vector2(-9000, -9000)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.zoom *= 3.0
	var strips: Array[Image] = []
	var drops: Array[Image] = []
	for e: Node in placed("mover_enemy.tscn"):
		if strips.size() >= TURNS:
			break
		var shots: Array = await record_turn(e as Node2D, camera)
		if shots.is_empty():
			continue
		strips.append(strip_of(shots[0] as Array[Image]))
		drops.append(shots[1] as Image)
	check(not strips.is_empty(), "a wisp turned round")
	if not strips.is_empty():
		save_still("wisp_turn.png", strips[0])
		var all: Image = Image.create(CROP.size.x * drops.size(), CROP.size.y, false, drops[0].get_format())
		for k: int in range(drops.size()):
			all.blit_rect(drops[k], Rect2i(Vector2i.ZERO, CROP.size), Vector2i(k * CROP.size.x, 0))
		save_still("wisp_turn_drops.png", all)
	finish()


## Follow wisp `w` until it turns round, then record the turn: [STRIP frames through it, OVERLAY
## frames laid over one another (the lighter of each pixel) with the head's path in yellow], or []
## if it does not turn soon.
func record_turn(w: Node2D, camera: Camera2D) -> Array:
	var mover: Mover = w.get_node("Mover") as Mover
	var art: WispArt = null
	for c: Node in w.get_children():
		if c is WispArt:
			art = c as WispArt
	var start_dir: int = mover.direction
	for f: int in range(600):
		camera.global_position = w.global_position + Vector2(0, -50)
		camera.reset_smoothing()
		await process_frame
		if mover.direction != start_dir:
			break
	if mover.direction == start_dir or art == null:
		return []
	var frames_seen: Array[Image] = []
	var heads: PackedVector2Array = PackedVector2Array()
	var t0: float = art.t
	while art.t - t0 < Mover.TURN_TIME + 0.1:
		await process_frame
		var window_image: Image = root.get_texture().get_image()
		frames_seen.append(window_image.get_region(CROP))
		if not art._trail.is_empty():
			heads.append(on_image(art._trail[0], camera, window_image.get_size()) - Vector2(CROP.position))
	# The camera holds still through the turn (so does the wisp), so the lighter of each pixel
	# keeps the background and every pose of the pink wisp over it.
	var lit: PackedByteArray = frames_seen[0].get_data()
	for k: int in range(OVERLAY):
		var data: PackedByteArray = frames_seen[roundi(float(k) / float(OVERLAY - 1) * float(frames_seen.size() - 1))].get_data()
		for i: int in range(lit.size()):
			if data[i] > lit[i]:
				lit[i] = data[i]
	var over: Image = Image.create_from_data(CROP.size.x, CROP.size.y, false, frames_seen[0].get_format(), lit)
	for p: Vector2 in heads:
		over.fill_rect(Rect2i(Vector2i(p) - Vector2i(2, 2), Vector2i(4, 4)), Color(1.0, 0.85, 0.2))
	var kept: Array[Image] = []
	for k: int in range(STRIP):
		kept.append(frames_seen[roundi(float(k) / float(STRIP - 1) * float(frames_seen.size() - 1))])
	return [kept, over]


## Where world point `p` is drawn in an image of the window `size` pixels big, seen through
## `camera`.
func on_image(p: Vector2, camera: Camera2D, size: Vector2i) -> Vector2:
	var view: Vector2 = root.get_visible_rect().size
	return ((p - camera.get_screen_center_position()) * camera.zoom + view * 0.5) * (Vector2(size) / view)


## Frames in two rows of four.
func strip_of(shots: Array[Image]) -> Image:
	var out: Image = Image.create(CROP.size.x * 4, CROP.size.y * 2, false, shots[0].get_format())
	for k: int in range(mini(STRIP, shots.size())):
		out.blit_rect(shots[k], Rect2i(Vector2i.ZERO, CROP.size), Vector2i((k % 4) * CROP.size.x, (k / 4) * CROP.size.y))
	return out
