extends SceneTree
## Close-ups of the spell orb: hex ready, recharging (40%, 93%), just ready (ping), astral projection running (ring full),
## and its last second and a half (pink, blinking) across several frames.
## godot --path . --windowed --resolution 1280x720 --script res://tests/capture_orb.gd

func _initialize() -> void:
	call_deferred("capture")


func shot(camera: Camera2D, player: Player, frames: int) -> Image:
	for i: int in range(frames):
		camera.global_position = player.global_position + Vector2(0, -30)
		camera.reset_smoothing()
		await process_frame
	var sp: Vector2 = root.get_final_transform() * player.get_global_transform_with_canvas().origin
	var crop: Image = root.get_texture().get_image().get_region(Rect2i(int(sp.x) - 75, int(sp.y) - 110, 150, 150))
	crop.resize(300, 300, Image.INTERPOLATE_NEAREST)
	return crop


func capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var main: Node = load("res://prefabs/scenes/main.tscn").instantiate()
	root.add_child(main)
	RunState.save_path = "user://capture_orb.save"
	var menu: Node = main.get_node("Menu")
	menu.world_seed.text = "28"
	for i: int in range(5):
		await process_frame
	menu.start_game()
	var info: MapInfo = main.get_node("CanvasLayer/MapInfo") as MapInfo
	while info.world == null or info.travelling:
		await process_frame
	for i: int in range(40):
		await process_frame
	var player: Player = main.get_node("Player") as Player
	player.get_node("CameraControl").set_process(false)
	var camera: Camera2D = main.get_node("Camera2D") as Camera2D
	camera.zoom *= 1.0
	RisoPrint.instance.light.visible = false
	var shots: Array[Image] = []
	var hex: Hex = player.get_node("Hex") as Hex
	shots.append(await shot(camera, player, 4))
	hex.charges = 0
	hex.recharge = Hex.COOLDOWN * 0.4
	shots.append(await shot(camera, player, 2))
	hex.recharge = Hex.COOLDOWN * 0.93
	shots.append(await shot(camera, player, 2))
	hex.charges = 1
	hex.recharge = 0.0
	shots.append(await shot(camera, player, 6))
	Abilities.grant(player, &"astral")
	var astral: Node = player.get_node("AstralProjection")
	astral.call("toggle")
	shots.append(await shot(camera, player, 6))
	var timer: ActionTimer = astral.get("projection_timer") as ActionTimer
	for k: int in range(5):
		timer.acting = 1.2 - float(k) * 0.07
		shots.append(await shot(camera, player, 2))
	var out: Image = Image.create(300 * shots.size(), 300, false, shots[0].get_format())
	for k: int in range(shots.size()):
		out.blit_rect(shots[k], Rect2i(0, 0, 300, 300), Vector2i(k * 300, 0))
	out.save_png(ProjectSettings.globalize_path("res://../art-captures/riso-frames").path_join("orb_states.png"))
	print("CAPTURED orb")
	quit()
