class_name Snuffer
extends Area2D
## A snuffing font: a stone basin of still black water, standing by a crypt's doorway
## (CemeteryArchetype, Crypts). Interact while the lantern the wizard carries is lit and they dip
## its flame in the water and put it out (MapInfo.snuff): snuffed, they are hidden from what light
## wakes (the skeletons asleep in the crypts, Skeleton) and from the moths, but the wraiths hunt
## them (Wraith) and in a crypt they see almost nothing. It lights again when they dash or light a
## lantern; their lantern protects them all the while. A font is never used up.

@onready var player: Player = Stage.player()
var map_info: MapInfo


func setup(info: MapInfo, _v: Vector2i) -> void:
	map_info = info


## Whether there is a flame to put out.
func can_snuff() -> bool:
	return map_info != null and map_info.run != null and map_info.flame_lit()


func snuff() -> void:
	if can_snuff():
		map_info.snuff(global_position + Vector2(0, -40))


func _process(_delta: float) -> void:
	($Interactable as Interactable).available = can_snuff()


func _ready() -> void:
	($Interactable as Interactable).interacted.connect(snuff)
