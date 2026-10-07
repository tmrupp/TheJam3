class_name Shield
extends Node2D
## A shield an enemy carries, in sky levels (SkyArchetype.populate): a bubble of light round it
## that takes the hex bolts meant for it, cracking with each, until it breaks after `hp` hits. A
## parried shot (a reflected bolt, HexBolt.reflected) breaks it at once. While it holds, bolts
## neither wound nor stun what it guards. Printed as a faint veil of pink over its host with a
## paper glint; each hit leaves a jagged paper crack glowing pink in a slow pulse; breaking, it
## bursts into shards.

const RADIUS: float = 46.0

## Hits a shield takes before it breaks (a parried shot breaks it at once).
const HP: int = 3

var hp: int = HP
## Hits it can take when whole (the cracks are drawn by how many it has taken).
var full: int = HP
## Seconds since it was last struck (it flashes), and since it broke (-1 while it holds).
var since_hit: float = 99.0
var since_broke: float = -1.0
var ink: InkCanvas
var t: float = 0.0


static func of(host: Node) -> Shield:
	return host.get_node_or_null("Shield") as Shield if host != null else null


func holds() -> bool:
	return hp > 0


## A bolt struck its host (heading `dir`): if it holds it takes the bolt, and true comes back.
func absorb(reflected: bool, dir: Vector2) -> bool:
	if hp <= 0:
		return false
	hp = 0 if reflected else hp - 1
	since_hit = 0.0
	var at: Vector2 = global_position - dir.normalized() * RADIUS * 0.8
	if hp <= 0:
		since_broke = 0.0
		RisoFx.burst(&"gain", global_position, dir, [RisoPrint.PINK, RisoPrint.BLUE])
		Wound.shake(8.0, 0.18)
	else:
		RisoFx.burst(&"hit", at, -dir, [RisoPrint.PINK, RisoPrint.NIGHT])
		Wound.shake(4.0, 0.1)
	return true


func _ready() -> void:
	full = maxi(full, hp)
	z_index = 3
	add_to_group(&"riso_art")
	ink = InkCanvas.new()
	add_child(ink)


func _process(delta: float) -> void:
	t += delta
	since_hit += delta
	if since_broke >= 0.0:
		since_broke += delta
	ink.begin()
	if hp > 0:
		_bubble()
	elif since_broke < 0.45:
		_shards(since_broke / 0.45)
	ink.finish()


func _bubble() -> void:
	var flash: float = clampf(1.0 - since_hit / 0.18, 0.0, 1.0)
	var r: float = RADIUS * (1.0 + 0.025 * sin(t * 3.0) + 0.08 * flash)
	var body: PackedVector2Array = RisoShapes.circle(Vector2.ZERO, r, 40)
	# A faint veil of pink, a little stronger toward its edge, and brighter for a moment when struck.
	ink.ink(RisoPrint.PINK, 0.1 + 0.3 * flash, [body], false)
	var rim: Array[PackedVector2Array] = []
	for i: int in range(28):
		var a0: float = TAU * float(i) / 28.0
		var a1: float = a0 + TAU / 28.0
		rim.append(PackedVector2Array([Vector2(cos(a0), sin(a0)) * r, Vector2(cos(a1), sin(a1)) * r, Vector2(cos(a1), sin(a1)) * (r - 7.0), Vector2(cos(a0), sin(a0)) * (r - 7.0)]))
	ink.ink(RisoPrint.PINK, 0.22, rim, false)
	ink.knock([RisoPrint.PINK], [RisoShapes.crescent(Vector2(-r * 0.42, -r * 0.42), r * 0.2, Vector2(r * 0.06, r * 0.06), 20)])
	# Cracks: for each hit taken, a jagged split of bare paper running in from the rim, glowing pink
	# round it in a slow pulse, so a cracked shield reads at a glance.
	var cracks: Array[PackedVector2Array] = []
	var glows: Array[PackedVector2Array] = []
	for k: int in range(full - hp):
		var a: float = 0.9 + float(k) * 2.2
		var d: Vector2 = Vector2(cos(a), sin(a))
		var n: Vector2 = Vector2(-d.y, d.x)
		var pts: PackedVector2Array = PackedVector2Array([d * (r + 2.0), d * (r - 10.0) + n * 6.0, d * (r - 19.0) - n * 4.0, d * (r - 29.0) + n * 4.0])
		cracks.append_array(RisoDecor.strip(pts, 4.6, 1.6))
		# A branch off the middle.
		cracks.append_array(RisoDecor.strip(PackedVector2Array([d * (r - 10.0) + n * 6.0, d * (r - 17.0) + n * 14.0]), 3.0, 1.0))
		glows.append_array(RisoDecor.strip(pts, 14.0, 7.0))
	if not cracks.is_empty():
		var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
		ink.ink(RisoPrint.PINK, 0.45 + 0.45 * pulse, glows, false)
		ink.knock([RisoPrint.PINK, RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.ACCENT], cracks)


func _shards(u: float) -> void:
	var pieces: Array[PackedVector2Array] = []
	for i: int in range(10):
		var a: float = TAU * float(i) / 10.0 + 0.3
		var d: Vector2 = Vector2(cos(a), sin(a))
		var at: Vector2 = d * (RADIUS + 50.0 * u) + Vector2(0, 70.0 * u * u)
		var s: float = 8.0 * (1.0 - u)
		pieces.append(PackedVector2Array([at + d * s, at + Vector2(-d.y, d.x) * s * 0.6, at - d * s * 0.5]))
	ink.ink(RisoPrint.PINK, 0.8 * (1.0 - u), pieces, false)
