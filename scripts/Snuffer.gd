class_name Snuffer
extends Area2D
## A snuffing font: a stone basin of still black water, standing by a crypt's doorway (Crypts) and
## about the cemetery's terraces (CemeteryArchetype.scatter_fonts). Interact while the lantern the wizard carries is lit and they dip
## its flame in the water and put it out (MapInfo.snuff): snuffed, they are hidden from what light
## wakes (the skeletons asleep in the crypts, Skeleton) and from the moths, but the wraiths hunt
## them (Wraith) and in a crypt they see almost nothing. It lights again when they dash or light a
## lantern; their lantern protects them all the while. A font is never used up.

@onready var player: Player = Stage.player()
var map_info: MapInfo
## How long ago (s) a flame was last put out here, for the ripples and smoke drawn after (SnufferArt).
var dipped: float = INF


func setup(info: MapInfo, _v: Vector2i) -> void:
	map_info = info


## Whether there is a flame to put out.
func can_snuff() -> bool:
	return map_info != null and map_info.run != null and map_info.flame_lit()


func snuff() -> void:
	if can_snuff() and map_info.snuff(global_position + Vector2(0, -40)):
		dipped = 0.0


func _process(delta: float) -> void:
	($Interactable as Interactable).available = can_snuff()
	dipped += delta


func _ready() -> void:
	($Interactable as Interactable).interacted.connect(snuff)
