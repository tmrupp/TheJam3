extends Node2D
class_name ControlHint
## A control card in the tutorial (Tutorial): as the wizard comes near, a card rises over it showing
## the control its stretch asks for (HintArt): a key cap, or the game's pad (RisoPad) with that
## control solid on it, whichever the player last used (RisoPad.pad). Once they have used that control while the
## card is up, it goes for good (learned): every card of that control, for the rest of the run.
## No words: a key cap carries its key's letter, as printed on the keyboard, and no more.
## Two cards ask for the Spell button's guard (Parry), and are learned by what it does, not by a
## press: the parry (PARRY) by a catch, and the pogo off thorns (POGO) by a bounce off them
## (Parry.pogo_at), either made once the card has been seen (a pogo is made a few cells into its
## bed of thorns, past where the card is up).
## The card for burning a lantern into mend (BURN) asks for the interact button at a lit lantern, and
## is learned by burning one (MapInfo.lanterns_burned) once the card has been seen, not by a press.
## The utility spell's card (STRIKES) asks for mend, which heals only a wizard who is hurt, so as it
## first rises it costs a wizard at full health a heart (strike), and fills mend's draughts if they
## are spent, so the Utility button always has something to show there.

## How close the wizard must come for the card to rise, across and up or down (world pixels).
const REACH: Vector2 = Vector2(330, 400)
## How long (seconds) a card must have been up before a press of its control puts it away, so it is
## seen even by a player who is already pressing it.
const SEEN: float = 0.6
## The control whose card costs the wizard a heart as it rises (strike), and the spell it teaches.
const STRIKES: StringName = Abilities.UTILITY_ACTION
const HEALS: StringName = &"mend"
## The cards for the Spell button's guard: a parry, and a pogo off thorns (see the class description).
const PARRY: StringName = Tutorial.CARD_PARRY
const POGO: StringName = Tutorial.CARD_POGO
## The card for burning a lantern into mend, on the interact button (see the class description).
const BURN: StringName = Tutorial.CARD_BURN

## The control it shows: an input action, or &"Move" for walking either way (Left and Right).
var action: StringName = &""
## Whether the wizard is near enough for it to rise now, and how long it has been up.
var near: bool = false
var up_for: float = 0.0
## Whether this card has struck the wizard already (STRIKES; it strikes once).
var struck: bool = false
## When (the guard's clock, Parry.clock) a guard card was first seen (up for SEEN): a catch or a
## bounce after it learns it.
var _seen_at: float = INF
## How many lanterns had been burned (MapInfo.lanterns_burned) when the burn card was first seen,
## or -1 before then.
var _burned_at_seen: int = -1

## The controls used while their card was up, this run (cleared as a run begins in the tutorial).
static var learned: Dictionary = {}


func setup(_info: MapInfo, _v: Vector2i, which: Variant) -> void:
	action = StringName(which)


## Whether its card should be up: the wizard near, its control not yet used.
func showing() -> bool:
	return near and not learned.has(action)


func _process(delta: float) -> void:
	var player: Player = Stage.player()
	if player == null:
		near = false
	else:
		var d: Vector2 = (player.global_position - global_position).abs()
		near = d.x < REACH.x and d.y < REACH.y
	up_for = up_for + delta if showing() else 0.0
	if showing() and action == STRIKES and not struck:
		strike(player)
	if action in [PARRY, POGO] and player != null and not learned.has(action):
		_watch_guard(player)
	if action == BURN and not learned.has(action):
		_watch_burn()


func _input(event: InputEvent) -> void:
	RisoPad.note_device(event)
	if action in [PARRY, POGO, BURN]:
		return
	if up_for >= SEEN and _uses(event):
		learned[action] = true


## A guard card: learned by a catch (PARRY, Parry.parried_at) or a bounce off thorns (POGO,
## Parry.pogo_at) made after it was first seen.
func _watch_guard(player: Player) -> void:
	var guard: Parry = player.get_node_or_null("Parry") as Parry
	if guard == null:
		return
	if _seen_at == INF:
		if showing() and up_for >= SEEN:
			_seen_at = guard.clock
		return
	if (guard.parried_at if action == PARRY else guard.pogo_at) > _seen_at:
		learned[action] = true


## The burn card: learned by a lantern burned (MapInfo.lanterns_burned) after it was first seen.
func _watch_burn() -> void:
	var info: MapInfo = MapInfo.instance
	if info == null:
		return
	if _burned_at_seen < 0:
		if showing() and up_for >= SEEN:
			_burned_at_seen = info.lanterns_burned
		return
	if info.lanterns_burned > _burned_at_seen:
		learned[action] = true


## The utility card rising: a wizard at full health with mend in the slot loses a heart, and mend's
## draughts are filled if none is left, so pressing Utility heals them. Once a card.
func strike(player: Player) -> void:
	struck = true
	if Abilities.spell(player, &"utility") != HEALS:
		return
	var mend: Mend = player.get_node_or_null("Mend") as Mend
	if mend == null:
		return
	if mend.draughts() <= 0:
		mend.refill()
	if player.health.health >= player.health.max_health:
		player.hurt(-1, Vector2.ZERO, null)


## Whether `event` is a press of its control.
func _uses(event: InputEvent) -> bool:
	for a: StringName in actions(action):
		if event.is_action_pressed(a):
			return true
	return false


## The input actions a card's control stands for.
static func actions(control: StringName) -> Array[StringName]:
	if control == &"Move":
		return [&"Left", &"Right"]
	return [bound(control)]


## The input action whose bindings a card's control shows: the Spell button for the guard's cards
## (PARRY, POGO), the interact button for burning a lantern (BURN), else the control itself.
static func bound(control: StringName) -> StringName:
	if control == BURN:
		return &"Discover"
	return &"Spell" if control in [PARRY, POGO] else control
