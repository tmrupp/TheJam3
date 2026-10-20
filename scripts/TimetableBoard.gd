extends Node2D
class_name TimetableBoard
## The library's timetable board (Institute.furnish), on the back wall of its ground floor (printed by
## BoardArt): every classroom of the level, its day and where it stands, so the way through is
## planned here.

var map_info: MapInfo
## Its cell: the middle of the floor under it.
var cell: Vector2i = Vector2i(-1, -1)


func setup(info: MapInfo, v: Vector2i, _extra: Variant) -> void:
	map_info = info
	cell = v


## The period of the day it is now (Timetable.period).
func period() -> int:
	return Timetable.period(map_info.record().rings) if map_info != null and map_info.world != null else 0


## Each classroom of the level, in the halls' order, as {"dept", "subjects": what it teaches in each
## of the day's periods (&"" while closed), "tier": the tier it teaches now, "need": what it asks for
## now ([department, tier], [&"", 0] for nothing), "box": where it stands (cells), "way_on": whether it
## holds the way on}.
func rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if map_info == null or map_info.world == null:
		return out
	var w: LevelGen = map_info.world
	var rings: int = map_info.record().rings
	var dawn: int = rings - Timetable.period(rings)
	for i: int in range(w.halls.size()):
		if w.halls[i]["kind"] != &"lecture":
			continue
		var subjects: Array[StringName] = []
		for k: int in range(Timetable.PERIODS):
			subjects.append(Timetable.subject(w, i, dawn + k))
		var tier: int = map_info.tier_of(i)
		out.append({"dept": w.halls[i]["dept"], "subjects": subjects, "tier": tier,
			"need": Timetable.needs(w.halls[i]["dept"], tier) if map_info.subject_of(i) != &"" else [&"", 0],
			"box": w.halls[i]["box"], "way_on": i == Timetable.way_on_hall(w)})
	return out


## The stretch of the level holding every hall, a cell round them (cells), and the library's box
## (cells), for the board's locators.
func halls_bounds() -> Rect2i:
	if map_info == null or map_info.world == null or map_info.world.halls.is_empty():
		return Rect2i(0, 0, 1, 1)
	var out: Rect2i = map_info.world.halls[0]["box"]
	for hall: Dictionary in map_info.world.halls:
		out = out.merge(hall["box"])
	return out.grow(1)


func library_box() -> Rect2i:
	if map_info == null or map_info.world == null:
		return Rect2i()
	for hall: Dictionary in map_info.world.halls:
		if hall["kind"] == &"library":
			return hall["box"]
	return Rect2i()
