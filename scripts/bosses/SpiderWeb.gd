class_name SpiderWeb
extends Node2D
## A web the spider (Spider) has strung across a hole in its keep's floors (SpiderKeep). It is
## sticky: while the wizard is in one, they move at most WEB_SPEED across, rise at most WEB_RISE
## and sink at most WEB_SINK (so a jump stalls in it and a fall through it is slow), and their dash
## does not come back (Player). A hex bolt or a dash through it tears it (tear_along); the bolt
## flies on. A torn web is spun again REGROW seconds later, if the wizard is not in it, while the
## spider lives (it is the spider's: it goes with it). The spider itself passes through its webs.
## Printed by the spider (Spider._draw_web).

## The most the wizard moves across, rises and sinks in a web (px/s).
const WEB_SPEED: float = 110.0
const WEB_RISE: float = 90.0
const WEB_SINK: float = 55.0
## Seconds before a torn web is spun again, and how long the spinning takes.
const REGROW: float = 12.0
const SPIN_TIME: float = 1.2
## How near (px) a bolt's or a dash's way must pass to tear it.
const TEAR_REACH: float = 20.0

## The cells it spans, and the same in world space.
var cells: Rect2i = Rect2i()
var rect: Rect2 = Rect2()
## Whether it is torn, for how long (seconds), and how far it is spun again (1 whole).
var torn: bool = false
var torn_for: float = 0.0
var spun: float = 1.0


func _init(span: Rect2i, area: Rect2) -> void:
	cells = span
	rect = area
	add_to_group(&"web")


func _ready() -> void:
	global_position = rect.get_center()


## Whether it holds what is at `at`: whole (or spun back enough to hold), and `at` inside it.
func holds(at: Vector2) -> bool:
	return not torn and spun >= 0.5 and rect.has_point(at)


## Tear it (a bolt, a dash): its strands snap and hang from the edges.
func tear() -> void:
	if torn:
		return
	torn = true
	torn_for = 0.0
	spun = 0.0
	RisoFx.burst(&"hit", rect.get_center(), Vector2.DOWN, [RisoPrint.BLUE, RisoPrint.NIGHT])


## Mend it a step (the spider spins it again REGROW after it was torn, unless `blocked`, the wizard
## in it).
func regrow(delta: float, blocked: bool) -> void:
	if torn:
		torn_for += delta
		if torn_for >= REGROW and not blocked:
			torn = false
	elif spun < 1.0:
		spun = minf(1.0, spun + delta / SPIN_TIME)


## Whether a way from `from` to `to` passes through it.
func crossed(from: Vector2, to: Vector2) -> bool:
	var grown: Rect2 = rect.grow(TEAR_REACH)
	if grown.has_point(from) or grown.has_point(to):
		return true
	var corners: Array[Vector2] = [grown.position, Vector2(grown.end.x, grown.position.y), grown.end, Vector2(grown.position.x, grown.end.y)]
	for i: int in range(4):
		if Geometry2D.segment_intersects_segment(from, to, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


## Whether a web holds the wizard at `at` (Player asks each physics step).
static func holding(tree: SceneTree, at: Vector2) -> bool:
	for node: Node in tree.get_nodes_in_group(&"web"):
		var web: SpiderWeb = node as SpiderWeb
		if web != null and not web.is_queued_for_deletion() and web.holds(at):
			return true
	return false


## Tear every web a way from `from` to `to` passes through (a hex bolt's step, a dash's sweep).
## Returns how many it tore.
static func tear_along(tree: SceneTree, from: Vector2, to: Vector2) -> int:
	var count: int = 0
	for node: Node in tree.get_nodes_in_group(&"web"):
		var web: SpiderWeb = node as SpiderWeb
		if web != null and not web.torn and not web.is_queued_for_deletion() and web.crossed(from, to):
			web.tear()
			count += 1
	return count
