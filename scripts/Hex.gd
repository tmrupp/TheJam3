extends Node
class_name Hex
## The hex bolt, a spell: Spell (Q, or the pad's X) throws a comet of spell light from the wand,
## aimed like the dash (the held direction, else facing). It has charges that come back one per
## COOLDOWN, and lighting a lantern refills them. Each throw knocks the wizard back a little
## (RECOIL, SpellStrike.recoil). It wounds what it hits and stuns nothing (only a parry stuns).
## Tiers (Abilities): I wounds 1; II its charge comes back sooner (COOLDOWN_II); III +1 charge; IV +1
## damage and pierces its first enemy. Cast empowered (Empower), its bolt bores on through cracked
## rock (HexBolt.BORE cells), wounds Empower.EXTRA more, breaks a shield at once and strikes spires.

## Seconds for a spent charge to come back (sooner from tier II).
const COOLDOWN: float = 3.5
const COOLDOWN_II: float = 2.5
## How hard a cast throws the wizard back (SpellStrike.recoil's power: a slash that lands is 1): a
## little, whether the bolt strikes anything or not, the price of a blow from afar.
const RECOIL: float = 0.35

var charges_max: int = 1
var charges: int = 1
var recharge: float = 0.0
## What its bolt wounds by, and how long a spent charge takes to come back (seconds).
var damage: int = 1
var cooldown: float = COOLDOWN
var pierce: bool = false

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): I wounds 1; II its charge comes back sooner; III one more charge; IV 1 more
## damage and the bolt pierces its first enemy.
func set_tier(n: int) -> void:
	charges_max = 1 + (1 if n >= 3 else 0)
	damage = 1 + (1 if n >= 4 else 0)
	cooldown = COOLDOWN_II if n >= 2 else COOLDOWN
	pierce = n >= 4
	charges = mini(charges, charges_max)


## The Spell button, with the hex in the slot: throw a bolt (`empowered`, see Empower). Out of
## charges, nothing is thrown, but the press still counts as cast (the guard went up).
func cast_spell(empowered: bool = false) -> bool:
	var bolt: HexBolt = cast(Vector2.ZERO, empowered) as HexBolt
	return bolt != null or not empowered


func refill() -> void:
	charges = charges_max
	recharge = 0.0


## 0..1 toward the next charge, or 1 while a charge is ready (the wand tip shows it).
func readiness() -> float:
	return 1.0 if charges > 0 else clampf(recharge / cooldown, 0.0, 1.0)


## A bolt is thrown and done: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)


func _physics_process(delta: float) -> void:
	if charges < charges_max:
		recharge += delta
		if recharge >= cooldown:
			charges += 1
			recharge = 0.0


## Throw a bolt (`empowered`, see Empower). Returns it, or null when out of charges.
func cast(dir: Vector2 = Vector2.ZERO, empowered: bool = false) -> Node2D:
	if charges <= 0 or player == null:
		return null
	if dir == Vector2.ZERO:
		dir = Vector2(Input.get_axis("Left", "Right"), Input.get_axis("Up", "Down"))
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT * signf(player.sprite.scale.x if player.sprite != null else 1.0)
	charges -= 1
	var bolt: HexBolt = HexBolt.new()
	bolt.dir = dir.normalized()
	bolt.damage = damage + (Empower.EXTRA if empowered else 0)
	bolt.pierce = pierce
	bolt.empowered = empowered
	bolt.bore = HexBolt.BORE if empowered else 0
	var level: Node = MapInfo.instance.map_elements if MapInfo.instance != null and is_instance_valid(MapInfo.instance.map_elements) else player.get_parent()
	level.add_child(bolt)
	bolt.global_position = player.global_position + Vector2(0, -44)
	SpellStrike.recoil(player, bolt.dir, RECOIL)
	return bolt
