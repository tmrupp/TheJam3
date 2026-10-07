extends Node
class_name Mend
## Mend, a spell: press Spell to heal a heart, using up a draught. Tiers (Abilities) hold one
## draught each (I one, II two, III three). Draughts never come back on their own: learning a tier
## at a shrine fills them, and so does burning a lit lantern (interact with the lantern you lit):
## the lantern is spent and protects you no longer (MapInfo.burn_lantern). With lanterns scarce,
## that is the choice: a life kept in the lantern, or hearts now.
## The draughts are kept on the player (Player.mend_draughts), so swapping the spell away at a
## shrine and back does not fill them.

const HEAL: int = 1

var level: int = 1

@onready var player: Player = get_parent() as Player


## Its tier (Abilities): one draught a tier.
func set_tier(n: int) -> void:
	level = n


## The Spell button, with mend in the slot: heal a heart, if hurt and a draught is left.
func cast_spell() -> bool:
	cast()
	return true


func draughts_max() -> int:
	return level


func draughts() -> int:
	return clampi(player.mend_draughts if player.mend_draughts >= 0 else draughts_max(), 0, draughts_max())


func refill() -> void:
	player.mend_draughts = draughts_max()


## 1 while a draught is left, else 0 (the spell orb shows it).
func readiness() -> float:
	return 1.0 if draughts() > 0 else 0.0


## Heal, if hurt and a draught is left. Returns whether it healed.
func cast() -> bool:
	if player == null or draughts() <= 0 or player.health.health >= player.health.max_health:
		return false
	player.mend_draughts = draughts() - 1
	player.health.health = mini(player.health.health + HEAL, player.health.max_health)
	player.visual_event.emit(&"mend", player.global_position)
	RisoFx.burst(&"gain", player.global_position + Vector2(0, -40), Vector2.ZERO, [RisoPrint.EYE, RisoPrint.PINK])
	if RisoPrint.instance != null:
		RisoPrint.instance.flare(&"mend")
	return true


## The draughts kept for saving, or -1 for none kept.
static func stored(p: Player) -> int:
	return p.mend_draughts


static func restore(p: Player, n: int) -> void:
	p.mend_draughts = maxi(n, -1)
