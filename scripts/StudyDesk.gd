extends Area2D
class_name StudyDesk
## The library's reading desk (Institute.furnish), printed as a lesson's lectern (StudyDeskArt): a study
## hall. In class time a wizard in the library may study at it once a period: the oldest exam paper
## carried that teaches something is learned into its slot, and the spell it puts out comes back as a
## paper (MapInfo.study_at_desk). It asks nothing more: the price is the bell rung to begin class
## time, as a lantern's is the lantern (Checkpoint).

@onready var player: Player = Stage.player()

var map_info: MapInfo


func setup(info: MapInfo, _v: Vector2i, _extra: Variant) -> void:
	map_info = info


## The exam paper studying here now would teach, or 0 (MapInfo.desk_paper).
func paper() -> int:
	return map_info.desk_paper() if map_info != null and player != null else 0


## What it would teach now, as [spell, tier], or [&"", 0] for nothing.
func holds() -> Array:
	var code: int = paper()
	return [KeyRing.paper_spell(code), KeyRing.paper_tier(code)] if code != 0 else [&"", 0]


func study() -> void:
	if map_info != null:
		map_info.study_at_desk(global_position + Vector2(0, -40))


func _process(_delta: float) -> void:
	$Interactable.available = paper() != 0


func _ready() -> void:
	$Interactable.interacted.connect(study)
