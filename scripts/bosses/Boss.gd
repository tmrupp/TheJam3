extends RigidBody2D
class_name Boss
## A boss in play (Bosses): until each is built (the worm is, Worm), a boss is fought by this
## stand-in, a wisp grown SIZE times over with HP hits of health, shown as a row of pips over it
## that go out as it is hit (no bar on the HUD). It is hurt, stunned and parried as a wisp is. Its
## death opens its gate for the rest of the run and leaves its relic where it fell
## (MapInfo.boss_slain); a death of the wizard's own brings it back whole, as the level reloads.

## How much bigger than a wisp it is, and the hits it takes.
const SIZE: float = 2.0
const HP: int = 10
## Where its pips hang over it, how far apart, and how big.
const PIPS_Y: float = -150.0
const PIP_GAP: float = 16.0
const PIP_R: float = 5.5

var map_info: MapInfo
## Which boss it stands in for (Bosses).
var boss: StringName = &""
var ink: InkCanvas


func setup(info: MapInfo, _v: Vector2i, which: Variant) -> void:
	map_info = info
	boss = StringName(which)
	var wound: Wound = get_node_or_null("Wound") as Wound
	if wound != null:
		wound.hp = HP


func _ready() -> void:
	for part: String in ["CollisionShape2D", "HitBox"]:
		var node: Node2D = get_node_or_null(part) as Node2D
		if node != null:
			node.scale = Vector2.ONE * SIZE
	var wound: Wound = get_node_or_null("Wound") as Wound
	if wound != null:
		wound.slain.connect(_on_slain)
	ink = InkCanvas.new()
	ink.z_index = 3
	add_child(ink)
	add_to_group(&"riso_art")


func _process(_delta: float) -> void:
	# The wisp's art, grown SIZE times, and raised so its floor (and its shadow on it) stays put.
	var art: RisoProp = get_node_or_null("RisoArt") as RisoProp
	if art != null:
		art.scale = Vector2.ONE * SIZE
		art.position = Vector2(0, -art._ground() * (SIZE - 1.0))
	var wound: Wound = get_node_or_null("Wound") as Wound
	var left: int = wound.hp if wound != null else 0
	ink.global_transform = Transform2D(0.0, global_position)
	ink.begin()
	var whole: Array[PackedVector2Array] = []
	var gone: Array[PackedVector2Array] = []
	for i: int in range(HP):
		var at: Vector2 = Vector2((float(i) - float(HP - 1) * 0.5) * PIP_GAP, PIPS_Y)
		var pip: PackedVector2Array = PackedVector2Array([at + Vector2(0, -PIP_R), at + Vector2(PIP_R, 0), at + Vector2(0, PIP_R), at + Vector2(-PIP_R, 0)])
		if i < left:
			whole.append(pip)
		else:
			gone.append(pip)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], whole)
	ink.ink(RisoPrint.PINK, 1.0, whole, false)
	ink.ink(RisoPrint.NIGHT, 0.35, gone, false)
	ink.finish()


## Slain outright (the F7 panel's Slay boss), by the same death as any.
func slay() -> void:
	var wound: Wound = get_node_or_null("Wound") as Wound
	if wound != null:
		wound.hit(wound.hp + 1, Vector2.UP)


func _on_slain() -> void:
	if map_info != null:
		map_info.boss_slain(boss, global_position)
