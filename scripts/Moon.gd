extends Area2D
class_name Moon
## A moon: touching it spends it at once (it shows as a sliver), whether or not your dash is
## used, and gives your dash (and a spent levitate) back, even mid-dash. It keeps giving them back
## for as long as you stay inside it; once you leave it waxes back over a few seconds. Never used
## up, so a level's moons are always where they were.

const WANE: float = 2.5

@onready var player: Player = Stage.player()

## Seconds until it is full again (0 when ready).
var waning: float = 0.0
## It has given something back and the wizard has not left it yet.
var in_use: bool = false


func is_full() -> bool:
	return waning <= 0.0 and not in_use


func setup(_info: MapInfo, _v: Vector2i) -> void:
	pass


## Touching a full moon spends it; while it is in use (the wizard still inside), it gives back
## whatever is spent.
func touch(other: Node) -> void:
	if other != player or waning > 0.0 or (in_use and not overlaps_body(player)):
		return
	if not in_use:
		in_use = true
		RisoFx.burst(&"gain", global_position, Vector2.ZERO, [RisoPrint.ACCENT, RisoPrint.BLUE])
	var lev: Levitate = player.get_node_or_null("Levitate") as Levitate
	if player.dash.acted:
		player.dash.refresh()
	if lev != null and not lev.charged and not lev.floating():
		lev.charged = true


## A blink jumped through it (Blink.gd): if full, it is spent at once and gives back what is
## spent, as a touch would, and starts waxing straight away (the wizard is already past it).
func pass_through() -> void:
	if waning > 0.0 or in_use:
		return
	touch(player)
	in_use = false
	waning = WANE


func _physics_process(delta: float) -> void:
	if waning > 0.0:
		waning = maxf(0.0, waning - delta)
	var inside: bool = overlaps_body(player)
	if in_use and not inside:
		# Left it: now it wanes.
		in_use = false
		waning = WANE
	elif waning <= 0.0 and inside:
		# Inside a full (or in-use) moon: anything spent since comes straight back, mid-dash too.
		touch(player)


func _ready() -> void:
	body_entered.connect(touch)
