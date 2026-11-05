extends Node2D
class_name ControlHint
## A control card in the tutorial (Tutorial): as the wizard comes near, a card rises over it showing
## the control its stretch asks for (HintArt): a key cap, or a button on a pad's face, its shoulder
## or its stick, whichever the player last used (pad). Once they have used that control while the
## card is up, it goes for good (learned): every card of that control, for the rest of the run.
## No words: a key cap carries its key's letter, as printed on the keyboard, and no more.
## The utility spell's card (STRIKES) asks for mend, which heals only a wizard who is hurt, so as it
## first rises it costs a wizard at full health a heart (strike), and fills mend's draughts if they
## are spent, so the Utility button always has something to show there.

## How close the wizard must come for the card to rise, across and up or down (world pixels).
const REACH: Vector2 = Vector2(330, 400)
## How long (seconds) a card must have been up before a press of its control puts it away, so it is
## seen even by a player who is already pressing it.
const SEEN: float = 0.6
## How far a pad's stick must lean to count as using the pad.
const STICK_LEAN: float = 0.5
## The control whose card costs the wizard a heart as it rises (strike), and the spell it teaches.
const STRIKES: StringName = Abilities.UTILITY_ACTION
const HEALS: StringName = &"mend"

## The control it shows: an input action, or &"Move" for walking either way (Left and Right).
var action: StringName = &""
## Whether the wizard is near enough for it to rise now, and how long it has been up.
var near: bool = false
var up_for: float = 0.0
## Whether this card has struck the wizard already (STRIKES; it strikes once).
var struck: bool = false

## The controls used while their card was up, this run (cleared as a run begins in the tutorial).
static var learned: Dictionary = {}
## Whether the player last used a pad rather than the keyboard.
static var pad: bool = false


func setup(_info: MapInfo, _v: Vector2i, which: Variant) -> void:
	action = StringName(which)


func _ready() -> void:
	if not Input.get_connected_joypads().is_empty():
		pad = true


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


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > STICK_LEAN:
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	if up_for >= SEEN and _uses(event):
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
	return [control]
