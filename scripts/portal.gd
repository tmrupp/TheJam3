extends Node2D
## A teleporter: interact to step through to its partner. Generated pairs are linked by the level;
## the wizard's own rifts (Rift) link as they are opened. A tier III rift whose partner is in
## another level carries `rift_far` ([coord, position]): using it travels to that level.
## A trip takes a moment, in three beats that read on their own: the wizard is drawn into this
## portal (DEPART), the view cuts to the far one, and the wizard is pushed out of it (ARRIVE),
## held still throughout. RisoPrint prints it (RisoPortalWarp); `trip_done` fires at the end.

signal trip_done

const DEPART: float = 0.3
## Into the arrival, when the wizard is seen again, and when they can move.
const REVEAL: float = 0.16
const ARRIVE: float = 0.32

@onready var player: Player = $"/root/Main/Player"
@onready var portal_sfx: AudioStreamPlayer = $AudioStreamPlayer
var go_to_pos: Vector2
var linked: bool = false
var partner: Node2D = null

func use_portal() -> void:
	# A trip under way (through any portal; kept on the wizard, so a new run starts clear): no other.
	if not linked or player.has_meta(&"portal_trip"):
		return
	if has_meta(&"rift") and not has_meta(&"rift_far") and (not is_instance_valid(partner) or partner.is_queued_for_deletion()):
		unlink()
		return
	player.set_meta(&"portal_trip", true)
	var moving: bool = player.is_physics_processing()
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	portal_sfx.play()
	RisoPrint.portal_depart(self, player)
	await get_tree().create_timer(DEPART).timeout
	if has_meta(&"rift_far"):
		# Out in another level: the level's own transition takes it from here.
		var far: Array = get_meta(&"rift_far")
		RisoPrint.portal_reveal(player)
		player.remove_meta(&"portal_trip")
		MapInfo.instance.rift_travel(far[0], far[1])
		trip_done.emit()
		return
	var exit: Node2D = _far_end()
	var to: Vector2 = exit.global_position if exit != null else go_to_pos
	player.global_position = to
	_snap_camera()
	RisoPrint.portal_arrive(self, exit, player, to)
	await get_tree().create_timer(REVEAL).timeout
	RisoPrint.portal_reveal(player)
	player.visual_event.emit(&"teleport", to)
	await get_tree().create_timer(ARRIVE - REVEAL).timeout
	player.set_physics_process(moving)
	player.grace()
	player.remove_meta(&"portal_trip")
	trip_done.emit()

## The portal at the other end: the partner, or for a level's own pair, the portal standing where
## this one leads.
func _far_end() -> Node2D:
	if is_instance_valid(partner) and not partner.is_queued_for_deletion():
		return partner
	for node: Node in get_parent().get_children():
		if node != self and node is Node2D and node.scene_file_path == scene_file_path and (node as Node2D).global_position.distance_to(go_to_pos) < 2.0:
			return node as Node2D
	return null

## The view cuts to the far end at once, rather than sweeping across the level.
func _snap_camera() -> void:
	var control: Node = player.get_node_or_null("CameraControl")
	var camera: Camera2D = get_node_or_null("/root/Main/Camera2D") as Camera2D
	if control != null:
		control.set("target_location", player.position)
	if camera != null:
		camera.position = player.position
		camera.reset_smoothing()

func setup(map_info: MapInfo, _coord: Vector2, partner_coord: Vector2) -> void:
	go_to_pos = map_info.tile_map.to_global(map_info.tile_map.map_to_local(partner_coord))
	linked = true

func link(other: Node2D) -> void:
	partner = other
	linked = true

## Link to the other end of a tier III rift in another level.
func link_far(far_coord: Vector2i, far_at: Vector2) -> void:
	set_meta(&"rift_far", [far_coord, far_at])
	linked = true

func unlink() -> void:
	partner = null
	linked = false
	if has_meta(&"rift_far"):
		remove_meta(&"rift_far")

func _ready() -> void:
	$Area2D/Interactable.interacted.connect(use_portal)
