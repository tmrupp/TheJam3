extends Area2D
class_name Lectern
## A lecture hall's lectern (Institute.furnish), on its floor between its portal and its master,
## printed as a lesson's (LessonArt). Learning is permanent (Timetable): every damage spell the
## institute has taught the wizard stays known for the run (RunState.taught), and here they take one
## up again, at the tier they were taught, in place of the one in their slot (which stays known in
## turn). Interact to take up the next one known, in the order of Institute.MASTERIES after the one
## held. While its hall's trial is under way it lends nothing.

@onready var player: Player = Stage.player()

var map_info: MapInfo
## Its hall (an index into LevelGen.halls).
var hall: int = -1


func setup(info: MapInfo, _v: Vector2i, extra: Variant) -> void:
	map_info = info
	hall = int(extra) if extra != null else -1


## What taking it up gives now, as [spell, tier]: the next spell taught (see the class description)
## other than the one held; [&"", 0] when there is none, or while its hall's trial is under way.
func holds() -> Array:
	if map_info == null or player == null or map_info.trial_hall == hall:
		return [&"", 0]
	var held: StringName = Abilities.spell(player, &"damage")
	var order: Array[StringName] = Institute.MASTERIES
	var start: int = order.find(held)
	for k: int in range(1, order.size() + 1):
		var a: StringName = order[posmod(start + k, order.size())]
		if a != held and int(map_info.run.taught.get(a, 0)) > 0:
			return [a, int(map_info.run.taught[a])]
	return [&"", 0]


## Take up the spell it holds, the one in the slot staying known.
func take() -> void:
	var held: Array = holds()
	var a: StringName = held[0]
	if a == &"":
		return
	var was: StringName = Abilities.spell(player, Abilities.slot_of(a))
	if was != &"":
		map_info.remember(was, Abilities.tier(player, was))
	Abilities.set_tier(player, a, int(held[1]))
	map_info.save_run()
	RisoFx.burst(&"gain", global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	Wound.shake(5.0, 0.15)


func _process(_delta: float) -> void:
	$Interactable.available = holds()[0] != &""


func _ready() -> void:
	$Interactable.interacted.connect(take)
