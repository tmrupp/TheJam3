extends Node2D
## Fixed integration room using the real Player and portal prefabs, without RNG/WFC generation.
var player: CharacterBody2D
var portals: Array[Node2D] = []

func _ready() -> void:
	$Menu.hide()
	$Menu.set_process_input(false)
	$UpgradeMenu.hide()
	$CanvasLayer/MapInfo.hide()
	$FourierWorld.enabled = true
	var backdrop: Polygon2D = Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2(-5000, -5000), Vector2(5000, -5000), Vector2(5000, 5000), Vector2(-5000, 5000)])
	backdrop.color = Color(0.025, 0.02, 0.045)
	backdrop.z_index = -100
	add_child(backdrop)
	var spawn: Node2D = Node2D.new()
	spawn.name = "RoomSpawn"
	spawn.position = Vector2(420, 560)
	add_child(spawn)
	player = preload("res://prefabs/player.tscn").instantiate()
	player.position = spawn.position
	add_child(player)
	player.respawn = spawn
	player.get_node("CameraControl").set_process(false)
	$CanvasLayer/MapInfo.player = player
	$Camera2D.position = Vector2(620, 350)
	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.collision_layer = 4
	floor_body.position = Vector2(620, 620)
	add_child(floor_body)
	var collider: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(1240, 40)
	collider.shape = rectangle
	floor_body.add_child(collider)
	var floor_art: Polygon2D = Polygon2D.new()
	floor_art.polygon = PackedVector2Array([Vector2(-620, -20), Vector2(620, -20), Vector2(620, 20), Vector2(-620, 20)])
	floor_art.color = Color(0.12, 0.16, 0.23)
	floor_body.add_child(floor_art)
	for index: Variant in range(2):
		var portal: Node2D = preload("res://prefabs/portal.tscn").instantiate()
		portal.position = Vector2(500 + index * 420, 540)
		add_child(portal)
		portals.append(portal)
	portals[0].go_to_pos = Vector2(900, 560)
	portals[1].go_to_pos = spawn.position
	var label: Label = Label.new()
	label.position = Vector2(8, 22)
	label.add_theme_font_size_override("font_size", 8)
	label.text = "FOURIER PLAY ROOM | Existing movement / E: portal\nF1: effect on/off | F2: reduced motion | R: respawn"
	$CanvasLayer.add_child(label)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			$FourierWorld.enabled = not $FourierWorld.enabled
		elif event.keycode == KEY_F2:
			$FourierWorld.reduced_motion = not $FourierWorld.reduced_motion
		elif event.keycode == KEY_R:
			player.reset_position()
