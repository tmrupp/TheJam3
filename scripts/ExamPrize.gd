extends Area2D
class_name ExamPrize
## One of the exam's prizes (MapInfo._spawn_exam_prizes): once a level's exam is passed, a lectern on
## the exam hall's floor for each trial the wizard passed there (LevelRecord.trials), printed as a
## lesson (ExamPrizeArt), the spell's mark over it with a pip for the tier it was taught at. The
## exam is the upgrade (Timetable): interact to learn that spell at that tier (MapInfo.take_exam_prize),
## and the others are gone; the record keeps the pick made (LevelRecord.exam_prize).

@onready var player: Player = Stage.player()

var map_info: MapInfo
## The spell it teaches, and at what tier.
var spell: StringName = &""
var tier: int = 0


func setup(info: MapInfo, a: StringName, at_tier: int) -> void:
	map_info = info
	spell = a
	tier = at_tier


## What it teaches, as [spell, tier].
func holds() -> Array:
	return [spell, tier]


## Learn it: the exam's pick.
func take() -> void:
	if map_info != null and spell != &"":
		map_info.take_exam_prize(spell, tier)


func _ready() -> void:
	add_to_group(&"exam_prize")
	$Interactable.interacted.connect(take)
