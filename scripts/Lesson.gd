extends Area2D
class_name Lesson
## A master's lesson (Scholar): where an institute master fell, a lectern with an open book, the
## mark of the spell it had mastered floating over it (LessonArt). Interact to learn the next tier
## of that spell, free (the fight was its price), as a shrine teaches one. A spell learned in place
## of the one in its slot leaves the old one on the lectern, at its tier, to take back free (leaving
## the newer one in turn), as at a shrine. A master teaches once: beaten again after a death, it
## leaves nothing more. The level record keeps each lesson by its master's cell
## (LevelRecord.lessons: {"at": where it lies, "ability", "taken", "left": [spell, tier] or []});
## once nothing is left on it, it is gone for good.

@onready var player: Player = Stage.player()

var map_info: MapInfo
## Its master's cell (its key in the record).
var cell: Vector2i = Vector2i(-1, -1)


func setup(info: MapInfo, master_cell: Vector2i) -> void:
	map_info = info
	cell = master_cell


## Its entry in the record (see the class description), or {}.
func entry() -> Dictionary:
	if map_info == null:
		return {}
	return map_info.record().lessons.get(cell, {})


## What it teaches now, as [ability, the tier taking it gives]: its master's spell, the next tier;
## or a spell a swap left here, at its tier; [&"", 0] when there is nothing left.
func holds() -> Array:
	var e: Dictionary = entry()
	if e.is_empty():
		return [&"", 0]
	if bool(e.get("taken", false)):
		var left: Array = e.get("left", [])
		return [StringName(left[0]), int(left[1])] if left.size() == 2 else [&"", 0]
	var a: StringName = StringName(e.get("ability", &""))
	return [a, mini(Abilities.tier(player, a) + 1, Abilities.max_tier(a))]


## Would taking it replace what is in its slot?
func swap() -> bool:
	var a: StringName = holds()[0]
	return a != &"" and Abilities.is_swap(player, a)


func take() -> void:
	var e: Dictionary = entry()
	var held: Array = holds()
	var a: StringName = held[0]
	if e.is_empty() or a == &"":
		return
	var dropped: StringName = Abilities.spell(player, Abilities.slot_of(a)) if Abilities.is_swap(player, a) else &""
	var dropped_tier: int = Abilities.tier(player, dropped) if dropped != &"" else 0
	Abilities.set_tier(player, a, int(held[1]))
	# What the institute teaches stays taught (RunState.taught), the spell put down too.
	map_info.remember(a, int(held[1]))
	if dropped != &"":
		map_info.remember(dropped, dropped_tier)
	e["taken"] = true
	e["left"] = [dropped, dropped_tier] if dropped != &"" else []
	map_info.record().lessons[cell] = e
	map_info.save_run()
	RisoFx.burst(&"gain", global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.shake(8.0, 0.2)
	if dropped == &"":
		queue_free()


func _ready() -> void:
	$Interactable.interacted.connect(take)
