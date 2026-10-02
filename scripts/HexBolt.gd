extends Node2D
## A hex bolt in flight. Each physics step it sweeps a ray against solid things (rock, doors,
## cracked walls; one-way ledges are passed through) and checks enemies near its path. It wounds
## what it meets (Wound.hit; enemies are stunned too, and at hex I only stunned) and breaks cracked
## walls (hex_hit) at any tier, and ends at rock or after RANGE. Printed as a comet of spell light
## (accent ink, like the wand tip) with a tapering tail.

const SPEED: float = 1100.0
const RANGE: float = 8.0 * 128.0
const REACH: float = 44.0
## Each target is struck anywhere along a vertical span through it, from its body centre up to
## about the top of its printed art, not just at its centre: a wisp's body sits low on the floor
## while the bolt flies at hat height, so a level shot used to pass over it.
const SPAN_DOWN: float = 20.0
const SPAN_UP: float = 56.0
const SOLID_MASK: int = 4

var dir: Vector2 = Vector2.RIGHT
var damage: int = 1
var pierce: bool = false
var travelled: float = 0.0
var struck: Array[Node] = []
var trail: Array[Vector2] = []
var ink: InkCanvas
var t: float = 0.0


func _ready() -> void:
	z_index = 3
	add_to_group(&"riso_art")
	ink = InkCanvas.new()
	ink.top_level = true
	add_child(ink)


func _physics_process(delta: float) -> void:
	t += delta
	var from: Vector2 = global_position
	var to: Vector2 = from + dir * SPEED * delta
	# Enemies along the step, nearest first.
	var targets: Array[Node] = []
	for e: Node in get_tree().get_nodes_in_group(&"hex_target"):
		if e in struck or not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var at: Vector2 = (e as Node2D).global_position
		var near: PackedVector2Array = Geometry2D.get_closest_points_between_segments(from, to, at + Vector2(0, SPAN_DOWN), at - Vector2(0, SPAN_UP))
		if near[0].distance_to(near[1]) <= REACH:
			targets.append(e)
	targets.sort_custom(func(a: Node, b: Node) -> bool: return from.distance_squared_to((a as Node2D).global_position) < from.distance_squared_to((b as Node2D).global_position))
	var wall: Dictionary = _solid(from, to)
	var wall_d: float = from.distance_to(wall["position"]) if not wall.is_empty() else INF
	for e: Node in targets:
		if from.distance_to((e as Node2D).global_position) > wall_d + REACH:
			break
		struck.append(e)
		# Wound first (a stunned enemy takes double, so stunning first would double every hit),
		# then stun whatever is left.
		var wound: Node = e.get_node_or_null("Wound")
		if wound != null and damage > 0:
			wound.call("hit", damage, dir)
		elif damage <= 0:
			RisoFx.burst(&"hit", (e as Node2D).global_position, dir, [RisoPrint.ACCENT, RisoPrint.BLUE])
		var stunner: Node = e.get_node_or_null("Stunner")
		if stunner != null and is_instance_valid(e) and not e.is_queued_for_deletion():
			stunner.call("stun", Hex.STUN)
		if not pierce or struck.size() > 1:
			_end((e as Node2D).global_position)
			return
	if not wall.is_empty():
		var hit: Object = wall["collider"]
		if hit != null and hit.has_method("hex_hit"):
			hit.call("hex_hit", maxi(damage, 1), dir)
		_end(wall["position"])
		return
	global_position = to
	travelled += to.distance_to(from)
	trail.append(from)
	if trail.size() > 7:
		trail.pop_front()
	if travelled >= RANGE:
		_end(to)


## The first rock, door or cracked wall on the step (ledges and moving platforms are skipped).
func _solid(from: Vector2, to: Vector2) -> Dictionary:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, SOLID_MASK)
	var skip: Array[RID] = []
	for i: int in range(6):
		query.exclude = skip
		var res: Dictionary = space.intersect_ray(query)
		if res.is_empty():
			return {}
		var c: Object = res["collider"]
		if c is TileMap or c is TileMapLayer or (c != null and c.has_method("hex_hit")) or (c is Node and (c as Node).scene_file_path.get_file() == "door.tscn"):
			return res
		skip.append(res["rid"])
	return {}


func _end(at: Vector2) -> void:
	RisoFx.burst(&"hit", at, -dir, [RisoPrint.ACCENT, RisoPrint.PINK])
	Wound.shake(3.0, 0.08)
	queue_free()


func _process(_delta: float) -> void:
	ink.begin()
	var head: Vector2 = global_position
	var pts: Array[Vector2] = []
	pts.append_array(trail)
	pts.append(head)
	var tail: Array[PackedVector2Array] = []
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if a.distance_to(b) < 1.0:
			continue
		var n: Vector2 = (b - a).normalized().orthogonal()
		var wa: float = 2.0 + 10.0 * float(i) / float(pts.size())
		var wb: float = 2.0 + 10.0 * float(i + 1) / float(pts.size())
		tail.append(PackedVector2Array([a - n * wa, b - n * wb, b + n * wb, a + n * wa]))
	ink.ink(RisoPrint.ACCENT, 0.5, tail)
	var pulse: float = 1.0 + 0.15 * sin(t * 40.0)
	ink.ink(RisoPrint.ACCENT, 0.3, [RisoShapes.circle(head, 26.0 * pulse, 20)])
	var core: PackedVector2Array = Transform2D(t * 9.0, head) * RisoShapes.sparkle(Vector2.ZERO, 16.0 * pulse)
	ink.knock([RisoPrint.NIGHT, RisoPrint.BLUE, RisoPrint.PINK, RisoPrint.ACCENT], [core])
	ink.ink(RisoPrint.ACCENT, 1.0, [core], false)
	ink.finish()
