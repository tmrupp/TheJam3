extends Node2D
## A teleporter: interact to step out at its partner. Generated pairs are linked by the level;
## the wizard's own rifts (Rift) link as they are opened. With `auto`, stepping in is enough; the
## arrival portal ignores the wizard until they step off it, so they don't bounce straight back.

@onready var player: Player = $"/root/Main/Player"
@onready var portal_sfx: AudioStreamPlayer = $AudioStreamPlayer
var go_to_pos: Vector2
var linked: bool = false
var partner: Node2D = null
var auto: bool = false
## Set on the arrival portal until the wizard steps off it.
var resting: bool = false

func use_portal() -> void:
	if not linked:
		return
	if has_meta(&"rift") and (not is_instance_valid(partner) or partner.is_queued_for_deletion()):
		unlink()
		return
	if is_instance_valid(partner):
		go_to_pos = partner.global_position
		partner.set("resting", true)
	player.global_position = go_to_pos
	player.reset_fourier_motion()
	portal_sfx.play()

func setup(map_info: MapInfo, _coord: Vector2, partner_coord: Vector2) -> void:
	go_to_pos = map_info.tile_map.to_global(map_info.tile_map.map_to_local(partner_coord))
	linked = true

func link(other: Node2D) -> void:
	partner = other
	linked = true

func unlink() -> void:
	partner = null
	linked = false

func _touch(body: Node) -> void:
	if auto and body == player and not resting:
		use_portal()

func _leave(body: Node) -> void:
	if body == player:
		resting = false

func _ready() -> void:
	$Area2D/Interactable.interacted.connect(use_portal)
	$Area2D.body_entered.connect(_touch)
	$Area2D.body_exited.connect(_leave)
