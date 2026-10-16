extends StaticBody2D
class_name GlyphSeal
## A glyph seal (docs/REGIONS_PLAN.md §9, the timetable): a slab of marble across a doorway bearing a
## damage spell's glyph (GlyphSealArt), laid just inside each doorway of the exam hall and the
## library (Institute.furnish, asking for the spell Timetable.seal_of deals). It opens only to that
## spell used for what it does (literal), and to nothing else: no other spell, no plain blow. Each
## spell's use:
## - hex: a hex bolt cast from at least HEX_FAR px off (a little over three cells: the institute's
##   rooms are close, and further would leave some seals out of reach);
## - seeker: a seeker's bolt that has turned at least SEEKER_BEND radians on its way, round to it;
## - slash, nova, push, lunge: struck by that spell (all strike where the wizard stands).
## Anything else glances off it. Broken, it crumbles, and the level record keeps it open for good
## (MapInfo.mark_opened). A trial's mock seal (`mock`, MapInfo.begin_trial) is the same seal on a
## stand (or, for a bolt, mounted on the lectern's wall), barring nothing: breaking it passes the
## trial.

## How far off (px) a hex bolt must be cast from, and how far (radians) a seeker's bolt must turn.
const HEX_FAR: float = 400.0
const SEEKER_BEND: float = 1.2
## How long it takes to crumble once broken (seconds).
const CRUMBLE: float = 0.5

var map_info: MapInfo
## The spell it asks for (Institute.MASTERIES).
var spell: StringName = &""
## A trial's mock seal (see the class description), and whether it hangs on a wall.
var mock: bool = false
var mounted: bool = false
## Seconds since a blow glanced off it, and since it was broken (-1 until it is) (the art).
var since_glance: float = 99.0
var crumbling: float = -1.0


func setup(info: MapInfo, _v: Vector2i, extra: Variant) -> void:
	map_info = info
	spell = StringName(extra) if extra != null else &""


## Made a trial's mock seal for `info`, asking for `a`, mounted on a wall or not.
func make_mock(info: MapInfo, a: StringName, on_wall: bool) -> void:
	map_info = info
	spell = a
	mock = true
	mounted = on_wall
	collision_layer = 0


func _ready() -> void:
	add_to_group(&"hex_target")
	if mock:
		collision_layer = 0


## Whether spell `a`, cast from `from`, having turned `bent` radians on its way (a seeker's bolt),
## is its spell used for what it does (see the class description).
func literal(a: StringName, from: Vector2, bent: float) -> bool:
	if a != spell or a == &"":
		return false
	match a:
		&"hex":
			return from.distance_to(global_position) >= HEX_FAR
		&"seeker":
			return bent >= SEEKER_BEND
	return true


## Whether it has been broken.
func broken() -> bool:
	return crumbling >= 0.0


## Struck by spell `a` (&"" for a plain blow), cast from `from`, having turned `bent` radians: it
## breaks if that is its spell used literally, else the blow glances off.
func struck(a: StringName, from: Vector2, bent: float) -> void:
	if broken():
		return
	if not literal(a, from, bent):
		since_glance = 0.0
		RisoFx.burst(&"hit", global_position + Vector2(0, -40), Vector2.UP, [RisoPrint.BLUE, RisoPrint.NIGHT])
		Wound.shake(3.0, 0.1)
		return
	crumbling = 0.0
	collision_layer = 0
	remove_from_group(&"hex_target")
	RisoFx.burst(&"gain", global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	Wound.shake(8.0, 0.2)
	if map_info == null:
		return
	if mock:
		map_info.trial_seal_broken(self)
	else:
		map_info.mark_opened(self)
		map_info.save_run()


func _process(delta: float) -> void:
	since_glance += delta
	if crumbling >= 0.0:
		crumbling += delta
		if crumbling >= CRUMBLE:
			queue_free()
