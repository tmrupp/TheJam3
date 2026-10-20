extends Node
class_name Empower
## Empowered casts (the crags' lodestones, Lodestone; docs/REGIONS_PLAN.md §7): holding the Spell
## button HOLD seconds casts the damage spell empowered, if a lodestone has tempered that spell
## (RunState.tempered) and empowerment has come back. A quick press casts as ever. There is nothing
## to collect or spend: an empowered cast comes back on its own after Rules.empower_recharge, which
## each lodestone touched shortens, for every spell. A spell not tempered (or empowerment not back)
## casts at once on the press, as it always did. The parry guard goes up on the press either way
## (Player).
##
## Empowered, each damage spell breaks cracked rock its own way (the only thing that does, in every
## band; CrackedWall) and strikes a tower's spire (Spire), and hits harder in a fight (EXTRA wound,
## and a shield breaks at once): the hex bores on through cracked rock (HexBolt.BORE cells), the
## seeker homes on a spire it can see and breaks the first cracked rock it meets, the slash cleaves
## the cracked rock in its arc and the two cells in front, the nova shatters the cracked rock in a
## ring a cell out, the push breaks the cracked cell before the wizard, and the lunge drives through
## a cracked wall up to Lunge.RAM cells thick. Every wizard has one (Player).

## How long (seconds) the Spell button is held for an empowered cast.
const HOLD: float = 0.4
## The wound an empowered cast adds to the spell's own.
const EXTRA: int = 1

## Seconds until an empowered cast is back (0: ready).
var wait: float = 0.0
## Seconds the Spell button has been held for a cast not yet made, or -1 while none is pending.
var held: float = -1.0

@onready var player: Player = get_parent() as Player


## The wizard's Empower, or null.
static func of(wizard: Node) -> Empower:
	return wizard.get_node_or_null("Empower") as Empower if wizard != null else null


## Whether a press held `seconds` long casts empowered.
static func long_enough(seconds: float) -> bool:
	return seconds >= HOLD


## The run being played (null outside the game: then nothing is tempered).
static func _run() -> RunState:
	return MapInfo.instance.run if MapInfo.instance != null else null


## Whether a lodestone has tempered `spell` this run.
static func tempered(spell: StringName) -> bool:
	var run: RunState = _run()
	return run != null and run.tempered.has(spell)


## Seconds an empowered cast takes to come back now (by the lodestones touched).
static func recharge() -> float:
	var run: RunState = _run()
	return Rules.empower_recharge(run.lodestones.size() if run != null else 0)


## Whether the spell in the damage slot can be cast empowered now: tempered, and empowerment back.
func ready_now() -> bool:
	return player != null and tempered(Abilities.spell(player)) and wait <= 0.0


## How far back empowerment is, 0..1 (1 ready); -1 when the spell in the slot is not tempered.
func readiness() -> float:
	if player == null or not tempered(Abilities.spell(player)):
		return -1.0
	var whole: float = recharge()
	return 1.0 if wait <= 0.0 or not is_finite(whole) else clampf(1.0 - wait / whole, 0.0, 1.0)


## How far through a hold for an empowered cast the wizard is, 0..1; -1 while none is held.
func charging() -> float:
	return clampf(held / HOLD, 0.0, 1.0) if held >= 0.0 else -1.0


## The Spell button was pressed: with empowerment ready, wait to see how long it is held (true);
## otherwise cast at once, as ever (false).
func press() -> bool:
	if not ready_now() or player.is_drowsy():
		Abilities.cast(player, &"damage")
		return false
	held = 0.0
	return true


## Each physics step while a cast is pending: let go before HOLD, it casts as ever; held to HOLD,
## it casts empowered, and empowerment goes to recharge if the spell went off.
func step(delta: float, down: bool) -> void:
	if held < 0.0:
		return
	held += delta
	if not down:
		held = -1.0
		Abilities.cast(player, &"damage")
	elif long_enough(held):
		held = -1.0
		if Abilities.cast(player, &"damage", true):
			wait = recharge()
			player.visual_event.emit(&"empower", player.global_position)


## A lodestone was touched: what is left of the recharge is cut to the new, shorter one.
func shorten() -> void:
	wait = minf(wait, recharge())


func _physics_process(delta: float) -> void:
	if wait <= 0.0:
		return
	wait = maxf(0.0, wait - delta)
	if wait <= 0.0 and player != null and tempered(Abilities.spell(player)):
		player.visual_event.emit(&"empower_back", player.global_position)
