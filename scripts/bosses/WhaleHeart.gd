class_name WhaleHeart
extends Node2D
## The whale's heart (Whale), at the far end of its belly (Belly): the whale's one weak point. It
## takes HP blows; any hex bolt or dash wounds it, even one that only stuns (Wound.least). Burst, it
## slays the whale, and the wizard is spat out into the whale's level by its way on, where the
## whale's relic waits (MapInfo.whale_burst). Leaving the belly with it whole heals it, as the belly
## is made again. Printed by itself: a great heart in sun (a weak point) beating on a dark knot of
## vessels, swelling as it beats and flashing pink when struck. Nothing here draws from any RNG.

## The blows it takes, and how often it beats (seconds).
const HP: int = 12
const BEAT: float = 0.9

var map_info: MapInfo
var wound: Wound
var ink: InkCanvas
var t: float = 0.0
## Its blows left when it was last drawn, and seconds since it was last struck (the flash).
var _last_hp: int = HP
var _struck: float = 99.0


func _init() -> void:
	wound = Wound.new()
	wound.name = "Wound"
	wound.hp = HP
	wound.least = 1
	add_child(wound)
	add_to_group(&"hex_target")


func setup(info: MapInfo, _v: Vector2i, _which: Variant) -> void:
	map_info = info


func _ready() -> void:
	z_index = 2
	ink = InkCanvas.new()
	add_child(ink)
	wound.slain.connect(_on_burst)


## Slain outright (the F7 panel's Slay boss), by the same death as any.
func slay() -> void:
	wound.hit(wound.hp + 1, Vector2.UP)


func _on_burst() -> void:
	if map_info != null:
		map_info.whale_burst()


func _process(delta: float) -> void:
	t += delta
	if wound.hp < _last_hp:
		_struck = 0.0
	_last_hp = wound.hp
	_struck += delta
	if ink == null:
		return
	ink.global_transform = Transform2D(0.0, global_position)
	ink.begin()
	var beat: float = pow(maxf(0.0, sin(t / BEAT * TAU)), 4.0)
	var s: float = 1.0 + 0.12 * beat
	var vessels: Array[PackedVector2Array] = []
	for k: int in range(5):
		var a: float = -PI * 0.5 + (float(k) - 2.0) * 0.45
		var from: Vector2 = Vector2(0.0, -30.0)
		var to: Vector2 = from + Vector2.from_angle(a) * (110.0 + 20.0 * float(k % 2))
		vessels.append_array(RisoDecor.strip(PackedVector2Array([from, from.lerp(to, 0.5) + Vector2(8.0 * float(k - 2), 0.0), to]), 16.0, 8.0))
	ink.ink(RisoPrint.NIGHT, 0.85, vessels, false)
	var heart: PackedVector2Array = PackedVector2Array()
	for i: int in range(48):
		var a: float = TAU * float(i) / 48.0
		# A heart's curve, its point down.
		var x: float = 16.0 * pow(sin(a), 3.0)
		var y: float = -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		heart.append(Vector2(x, y) * 4.2 * s)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], [heart])
	ink.ink(RisoPrint.ACCENT, 1.0, [heart])
	ink.ink(RisoPrint.PINK, 0.25 + 0.2 * beat, [heart], false)
	if _struck < 0.25:
		ink.ink(RisoPrint.PINK, 0.8 * (1.0 - _struck / 0.25), [heart], false)
	# Its blows left, as notches of paper across it.
	var notches: Array[PackedVector2Array] = []
	for i: int in range(wound.hp):
		notches.append(RisoShapes.circle(Vector2((float(i) - float(HP - 1) * 0.5) * 9.0, -96.0), 3.2, 8))
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE], notches)
	ink.ink(RisoPrint.PINK, 1.0, notches, false)
	ink.finish()
