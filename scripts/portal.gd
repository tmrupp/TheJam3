extends Node2D
## A teleporter: interact to step out at its partner. Generated pairs are linked by the level;
## the wizard's own rifts (Rift) link as they are opened. A tier III rift whose partner is in
## another level carries `rift_far` ([coord, position]): using it travels to that level.

@onready var player: Player = $"/root/Main/Player"
@onready var portal_sfx: AudioStreamPlayer = $AudioStreamPlayer
var go_to_pos: Vector2
var linked: bool = false
var partner: Node2D = null

func use_portal() -> void:
	if not linked:
		return
	if has_meta(&"rift_far"):
		var far: Array = get_meta(&"rift_far")
		portal_sfx.play()
		MapInfo.instance.rift_travel(far[0], far[1])
		return
	if has_meta(&"rift") and (not is_instance_valid(partner) or partner.is_queued_for_deletion()):
		unlink()
		return
	if is_instance_valid(partner):
		go_to_pos = partner.global_position
	var from: Vector2 = player.global_position
	player.global_position = go_to_pos
	player.reset_fourier_motion()
	portal_sfx.play()
	RisoPrint.portal_used(self, player, from, go_to_pos)
	player.visual_event.emit(&"teleport", go_to_pos)

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
