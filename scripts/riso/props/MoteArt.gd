extends RisoProp
## A star: printed once (a halo, and the star on a canvas of its own), then animated by moving the
## two canvases (see _tick), so a level's hundreds of stars never re-lay their ink.


## A star: printed once (a halo, and the star on a canvas of its own), then animated by moving the
## two canvases, bobbing, with the star rocking to and fro on its points. A deep level has
## hundreds, so they never re-lay their ink.
var _star_ink: InkCanvas = null


func _draw_art() -> void:
	if _star_ink == null:
		ink.ink(RisoPrint.ACCENT, 0.25, [RisoShapes.circle(Vector2.ZERO, 22.0, 24)])
		_star_ink = InkCanvas.new()
		add_child(_star_ink)
		_star_ink.begin()
		_star_ink.ink(RisoPrint.ACCENT, 1.0, [RisoShapes.sparkle(Vector2.ZERO, 18.0)])
		_star_ink.finish()
	_mote_pose()


func _mote_pose() -> void:
	var y: float = sin(t * 3.0 + phase) * 4.0
	ink.position = Vector2(0, y)
	_star_ink.position = Vector2(0, y)
	_star_ink.rotation = sin(t * 1.7 + phase) * 0.45

## After the first print only the canvases move.
func _tick() -> void:
	_mote_pose()
