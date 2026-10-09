extends Node
class_name Hex
## The hex bolt, a spell: Spell (Q, or the pad's X) throws a comet of spell light from the wand,
## aimed like the dash (the held direction, else facing). It has charges that come back one per
## COOLDOWN, and lighting a lantern refills them. Tiers (Abilities): I only stuns what it hits;
## II also wounds (1 damage); III +1 charge; IV +1 damage and pierces its first enemy.

const COOLDOWN: float = 6.0
## How long a hex leaves an enemy stunned.
const STUN: float = 3.0

var charges_max: int = 1
var charges: int = 1
var recharge: float = 0.0
## 0 at tier I: the bolt only stuns.
var damage: int = 0
var pierce: bool = false

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): I only stuns; II also wounds 1; III one more charge; IV 1 more damage and
## the bolt pierces its first enemy.
func set_tier(n: int) -> void:
	charges_max = 1 + (1 if n >= 3 else 0)
	damage = (1 if n >= 2 else 0) + (1 if n >= 4 else 0)
	pierce = n >= 4
	charges = mini(charges, charges_max)


## The Spell button, with the hex in the slot: throw a bolt.
func cast_spell() -> bool:
	cast()
	return true


func refill() -> void:
	charges = charges_max
	recharge = 0.0


## 0..1 toward the next charge, or 1 while a charge is ready (the wand tip shows it).
func readiness() -> float:
	return 1.0 if charges > 0 else clampf(recharge / COOLDOWN, 0.0, 1.0)


## A bolt is thrown and done: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)


func _physics_process(delta: float) -> void:
	if charges < charges_max:
		recharge += delta
		if recharge >= COOLDOWN:
			charges += 1
			recharge = 0.0


## Throw a bolt. Returns it, or null when out of charges.
func cast(dir: Vector2 = Vector2.ZERO) -> Node2D:
	if charges <= 0 or player == null:
		return null
	if dir == Vector2.ZERO:
		dir = Vector2(Input.get_axis("Left", "Right"), Input.get_axis("Up", "Down"))
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT * signf(player.sprite.scale.x if player.sprite != null else 1.0)
	charges -= 1
	var bolt: HexBolt = HexBolt.new()
	bolt.dir = dir.normalized()
	bolt.damage = damage
	bolt.pierce = pierce
	var level: Node = MapInfo.instance.map_elements if MapInfo.instance != null and is_instance_valid(MapInfo.instance.map_elements) else player.get_parent()
	level.add_child(bolt)
	bolt.global_position = player.global_position + Vector2(0, -44)
	player.visual_event.emit(&"hex", bolt.global_position)
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"hex")
	return bolt
