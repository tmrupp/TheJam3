extends Area2D
class_name Lodestone
## A lodestone (CragsArchetype.place_lodestone; which levels hold one, and of which spell,
## Rules.lodestone_at): a standing stone of dark iron ore, high on a crags cliff, dealt one damage
## spell, whose mark it bears. Touching it tempers that spell for the rest of the run: held, the Spell
## button casts it empowered (Empower). Every stone touched, of any spell, once each, shortens the
## recharge of an empowered cast (Rules.empower_recharge). The stone stays where it stands; touched,
## its mark goes dull (MapInfo.touch_lodestone). Nothing here draws from the world RNG.

var map_info: MapInfo
## The damage spell it tempers.
var spell: StringName = &""
## When it was touched (seconds since the game started, for the art's flare), and its clock.
var touched_at: float = -9.0
var t: float = 0.0


## Seconds since the game started (the clock touched_at is on).
static func now() -> float:
	return float(Time.get_ticks_msec()) * 0.001


func setup(info: MapInfo, _v: Vector2i, extra: Variant) -> void:
	map_info = info
	spell = StringName(extra) if extra != null else &""


func _ready() -> void:
	body_entered.connect(_touch)


func _process(delta: float) -> void:
	t += delta


## Whether this level's stone has been touched this run.
func touched() -> bool:
	return map_info != null and map_info.run.lodestones.has(map_info.coord)


## Whether the wizard carries the spell it tempers (it then calls to them more brightly).
func matches() -> bool:
	var wizard: Player = map_info.wizard() if map_info != null else null
	return wizard != null and Abilities.spell(wizard) == spell


func _touch(body: Node) -> void:
	if not body is Player or map_info == null or spell == &"":
		return
	if map_info.touch_lodestone(spell):
		touched_at = now()
		RisoFx.burst(&"gain", global_position + Vector2(0, -60), Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
		Wound.shake(8.0, 0.25)
