extends StaticBody2D
class_name GlyphSeal
## A glyph seal (docs/REGIONS_PLAN.md §9, the timetable): a slab of marble across a doorway bearing a
## damage spell's glyph (GlyphSealArt), laid just inside each doorway of the library
## (Institute.furnish, asking for the spell Timetable.seal_of deals). It opens only to that spell
## striking it (SpellStrike.strike, HexBolt: each tells it which spell it is), and to nothing
## else: no other spell, no plain blow, which glance off it. Broken, it crumbles, and the level record
## keeps it open for good (MapInfo.mark_opened).

## How long it takes to crumble once broken (seconds).
const CRUMBLE: float = 0.5

var map_info: MapInfo
## The spell it asks for (Institute.MASTERIES).
var spell: StringName = &""
## Seconds since a blow glanced off it, and since it was broken (-1 until it is) (the art).
var since_glance: float = 99.0
var crumbling: float = -1.0


func setup(info: MapInfo, _v: Vector2i, extra: Variant) -> void:
	map_info = info
	spell = StringName(extra) if extra != null else &""


func _ready() -> void:
	add_to_group(&"hex_target")


## Whether it has been broken.
func broken() -> bool:
	return crumbling >= 0.0


## Struck by spell `a` (&"" for a plain blow): it breaks if that is its spell, else the blow glances
## off.
func struck(a: StringName) -> void:
	if broken():
		return
	if a != spell or a == &"":
		since_glance = 0.0
		RisoFx.burst(&"hit", global_position + Vector2(0, -40), Vector2.UP, [RisoPrint.BLUE, RisoPrint.NIGHT])
		Wound.shake(3.0, 0.1)
		return
	crumbling = 0.0
	collision_layer = 0
	remove_from_group(&"hex_target")
	RisoFx.burst(&"gain", global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	Wound.shake(8.0, 0.2)
	if map_info != null:
		map_info.mark_opened(self)
		map_info.save_run()


func _process(delta: float) -> void:
	since_glance += delta
	if crumbling >= 0.0:
		crumbling += delta
		if crumbling >= CRUMBLE:
			queue_free()
