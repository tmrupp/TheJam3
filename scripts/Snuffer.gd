class_name Snuffer
extends Area2D
## A snuffing font: a stone basin of still black water, standing by a crypt's doorway (Crypts) and
## about the cemetery's terraces (CemeteryArchetype.scatter_fonts). Interact while it holds darkness
## and the wizard douses their flame in it and takes all it holds (MapInfo.douse_font): CHARGES in a
## font never touched. The flame of the lantern they carry goes out in the water (MapInfo.snuff).
## Snuffed, they are hidden from what light wakes (the skeletons asleep in the crypts, Skeleton) and
## from the moths, but the wraiths hunt them (Wraith) and in a crypt they see almost nothing; their
## lantern protects them all the while. Taken, it is dry (LevelRecord.fonts), through a death and
## every visit after, so darkness is farmed from the fonts of other levels. A dash spends darkness
## in any world (MapInfo.dash_switch), so interact at a dry font while carrying some and they pour
## it all back in, to keep it there for later (MapInfo.fill_font).

## How many charges of darkness a font never touched holds.
const CHARGES: int = 3

@onready var player: Player = Stage.player()
var map_info: MapInfo
var cell: Vector2i = Vector2i(-1, -1)
## How long ago (s) a flame was last put out here, for the ripples and smoke drawn after (SnufferArt),
## and how long ago darkness was last poured back in, for the ripples and the water rising.
var dipped: float = INF
var filled: float = INF


func setup(info: MapInfo, v: Vector2i) -> void:
	map_info = info
	cell = v


## The charges of darkness it holds.
func held() -> int:
	return map_info.font_held(cell) if map_info != null and map_info.run != null else CHARGES


## Whether it has run dry.
func dry() -> bool:
	return map_info != null and map_info.run != null and map_info.font_dry(cell)


## Whether there is darkness to take.
func can_snuff() -> bool:
	return map_info != null and map_info.run != null and not dry()


## Whether darkness carried can be poured back in: it is dry, and the wizard carries some.
func can_fill() -> bool:
	return map_info != null and map_info.run != null and dry() and map_info.run.dark_charges > 0


## Take its darkness, or, dry, pour back in what the wizard carries.
func use() -> void:
	if can_snuff():
		if map_info.douse_font(cell, global_position + Vector2(0, -40)):
			dipped = 0.0
	elif can_fill():
		if map_info.fill_font(cell, global_position + Vector2(0, -40)) > 0:
			filled = 0.0


func interaction_hint() -> Dictionary:
	if can_snuff():
		return {"text": "douse · %d" % held()}
	if can_fill():
		return {"text": "pour · %d" % map_info.run.dark_charges}
	return {}


func _process(delta: float) -> void:
	($Interactable as Interactable).available = can_snuff() or can_fill()
	dipped += delta
	filled += delta


func _ready() -> void:
	($Interactable as Interactable).interacted.connect(use)
