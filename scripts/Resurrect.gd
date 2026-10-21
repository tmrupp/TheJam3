extends Node
class_name Resurrect
## Resurrect, a utility spell found only in a crypt's reliquary (Crypts: the resurrection rite, an
## exam paper of it at tier I, learned at a lantern as any paper is; its higher tiers are then taught
## at shrines). Press Utility, standing on something, to bind the wizard's soul to where they stand:
## a grave mark rises there (GraveMark), and any mark before it goes. A death while the mark stands
## in the level being played, with a rite left, is undone: the wizard rises again at the mark at full
## health, untouchable for a moment (Player.grace), with their stars, keys, darkness and lantern as
## they were; the rite is spent and the mark goes. Thorns that strike them after send them back to
## the mark too (it is their footing, Player.thorn_back). Tiers (Abilities) hold one rite each (I
## one, II two, III three); rites come back at a lantern, as mend's draughts do
## (MapInfo.light_lantern), and on learning a tier. Leaving the level loses the mark. It moves
## nothing and hurts nothing while the wizard lives: it only keeps a death from happening.

## The grave mark a cast raises.
const MARK: PackedScene = preload("res://prefabs/grave_mark.tscn")

var level: int = 1
## The mark standing now, or null.
var mark: GraveMark = null

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): one rite a tier.
func set_tier(n: int) -> void:
	level = n
	if n <= 0:
		_clear()


## The Utility button, with resurrect in the slot: bind the soul here (see bind).
func cast_spell() -> bool:
	return bind()


func rites_max() -> int:
	return level


## The rites left (kept on the wizard, Player.resurrect_rites; -1 there for a full spell).
func rites() -> int:
	if player == null:
		return 0
	return clampi(player.resurrect_rites if player.resurrect_rites >= 0 else rites_max(), 0, rites_max())


func refill() -> void:
	player.resurrect_rites = rites_max()


## 1 while a rite is left, else 0 (the spell orb shows it).
func readiness() -> float:
	return 1.0 if rites() > 0 else 0.0


## A binding is done at once: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)


## Raise a grave mark where the wizard stands, if they stand on something and a rite is left, in
## place of the one before. Whether it rose.
func bind() -> bool:
	var info: MapInfo = MapInfo.instance
	if player == null or info == null or info.travelling or info.map_elements == null or not is_instance_valid(info.map_elements):
		return false
	if not player.is_on_floor() or rites() <= 0:
		return false
	_clear()
	mark = MARK.instantiate() as GraveMark
	info.map_elements.add_child(mark)
	mark.global_position = player.global_position
	mark.coord = info.coord
	RisoFx.burst(&"gain", mark.global_position + Vector2(0, -30), Vector2.UP, [RisoPrint.GLOW, RisoPrint.BLUE])
	return true


## Whether a mark stands in the level being played.
func marked() -> bool:
	return mark != null and is_instance_valid(mark) and not mark.is_queued_for_deletion() and MapInfo.instance != null and mark.coord == MapInfo.instance.coord


## The wizard has just died: rise again at the mark instead, if one stands here and a rite is left
## (see the class description). Whether they rose.
func rise() -> bool:
	if player == null or not marked() or rites() <= 0:
		return false
	var at: Vector2 = mark.global_position
	RisoFx.burst(&"gain", player.global_position + Vector2(0, -30), Vector2.UP, [RisoPrint.GLOW, RisoPrint.NIGHT])
	player.resurrect_rites = rites() - 1
	player.velocity = Vector2.ZERO
	player.knock = Vector2.ZERO
	player.levitating = false
	player.global_position = at
	player.footing = at
	player.footing_at = MapInfo.instance.coord
	player.health.health = player.health.max_health
	player.grace()
	_clear()
	RisoFx.burst(&"gain", at + Vector2(0, -40), Vector2.UP, [RisoPrint.EYE, RisoPrint.GLOW])
	return true


func _clear() -> void:
	if mark != null and is_instance_valid(mark):
		mark.queue_free()
	mark = null


## The rites kept for saving, or -1 for a full spell.
static func stored(p: Player) -> int:
	return p.resurrect_rites


static func restore(p: Player, n: int) -> void:
	p.resurrect_rites = maxi(n, -1)
