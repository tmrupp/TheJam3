extends Node
class_name Mend
## Mend, a utility spell: press Utility to heal to full health, using up a draught. The draughts
## left show on the sitting card (RisoHud). Tiers (Abilities) hold one draught each (I one, II two,
## III three). Draughts come back at a lantern: lighting one, or interacting with the one already
## lit, fills them (MapInfo.light_lantern), and so does learning a tier at a shrine.
## The draughts are kept on the player (Player.mend_draughts), so swapping the spell away at a
## shrine and back does not fill them.

var level: int = 1

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): one draught a tier.
func set_tier(n: int) -> void:
	level = n


## The Utility button, with mend in the slot: heal to full, if hurt and a draught is left.
func cast_spell() -> bool:
	return cast()


func draughts_max() -> int:
	return level


func draughts() -> int:
	return clampi(player.mend_draughts if player.mend_draughts >= 0 else draughts_max(), 0, draughts_max())


func refill() -> void:
	player.mend_draughts = draughts_max()


## 1 while a draught is left, else 0 (the spell orb shows it).
func readiness() -> float:
	return 1.0 if draughts() > 0 else 0.0


## A heal is done at once: never running (see Abilities.running).
func running() -> Vector2:
	return Vector2(-1.0, 0.0)


## Heal, if hurt and a draught is left. Returns whether it healed.
func cast() -> bool:
	if player == null or draughts() <= 0 or player.health.health >= player.health.max_health:
		return false
	player.mend_draughts = draughts() - 1
	player.health.health = player.health.max_health
	RisoFx.burst(&"gain", player.global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.EYE, RisoPrint.PINK])
	return true


## The draughts kept for saving, or -1 for none kept.
static func stored(p: Player) -> int:
	return p.mend_draughts


static func restore(p: Player, n: int) -> void:
	p.mend_draughts = maxi(n, -1)
