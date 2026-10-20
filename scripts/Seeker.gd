extends Node
class_name Seeker
## Seeker, a damage spell: the Spell button (Q, or the pad's X) looses a homing bolt of spell light,
## aimed at first like the hex (the held direction, else facing), that turns toward the nearest
## enemy it can see within HexBolt.SEEK px (HexBolt.seek) and strikes it as a hex bolt does:
## wounded by its damage. It flies slower than the hex (SPEED) but
## further (RANGE), smaller (SIZE), and is ready again COOLDOWN after. Cast empowered (Empower), it
## turns toward a tower's spire it can see rather than an enemy and strikes it, breaks the first
## cracked rock it meets, wounds Empower.EXTRA more and breaks a shield at once. Each cast knocks the wizard
## back a little, as a hex does (Hex.RECOIL). Tiers (Abilities): I one
## seeker, wounding 1; II turns harder (TURN_II); III looses two, fanned out FAN either way;
## IV wounds 2.

const COOLDOWN: float = 2.5
const SPEED: float = 620.0
const RANGE: float = 1400.0
## How hard it turns toward its quarry (radians a second).
const TURN: float = 4.0
const TURN_II: float = 7.0
## Half the angle (radians) two seekers are loosed apart.
const FAN: float = 0.45
## How big it prints, against a hex bolt's.
const SIZE: float = 0.7

var damage: int = 1
var turn: float = TURN
var count: int = 1
## Seconds until it is ready again.
var wait: float = 0.0

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): see the class description.
func set_tier(n: int) -> void:
	damage = 2 if n >= 4 else 1
	turn = TURN_II if n >= 2 else TURN
	count = 2 if n >= 3 else 1


## The Spell button, with the seeker in the slot (`empowered`, see Empower).
func cast_spell(empowered: bool = false) -> bool:
	return not cast(Vector2.ZERO, empowered).is_empty()


func readiness() -> float:
	return 1.0 - clampf(wait / COOLDOWN, 0.0, 1.0)


## A seeker is loosed and done: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)


func _physics_process(delta: float) -> void:
	wait = maxf(0.0, wait - delta)


## Loose the seekers heading `dir` (the aim when zero), `empowered` or not. Returns them, none while
## it is not ready.
func cast(dir: Vector2 = Vector2.ZERO, empowered: bool = false) -> Array[HexBolt]:
	var out: Array[HexBolt] = []
	if wait > 0.0 or player == null:
		return out
	if dir == Vector2.ZERO:
		dir = SpellStrike.aim(player)
	var level: Node = MapInfo.instance.map_elements if MapInfo.instance != null and is_instance_valid(MapInfo.instance.map_elements) else player.get_parent()
	for k: int in range(count):
		var bolt: HexBolt = HexBolt.new()
		bolt.dir = dir.normalized().rotated(0.0 if count == 1 else lerpf(-FAN, FAN, float(k) / float(count - 1)))
		bolt.damage = damage + (Empower.EXTRA if empowered else 0)
		bolt.empowered = empowered
		bolt.bore = 1 if empowered else 0
		bolt.speed = SPEED
		bolt.range_px = RANGE
		bolt.seek = turn
		bolt.size = SIZE
		bolt.spell = &"seeker"
		level.add_child(bolt)
		bolt.global_position = player.global_position + Vector2(0, -44)
		out.append(bolt)
	SpellStrike.recoil(player, dir.normalized(), Hex.RECOIL)
	wait = COOLDOWN
	return out
