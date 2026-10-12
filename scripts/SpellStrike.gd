class_name SpellStrike
extends RefCounted
## What the damage spells that strike where the wizard stands share (Slash, Nova, Push): finding
## what is caught in a shape round the wizard, and striking it as a hex bolt does (HexBolt). An
## enemy is wounded (at least as much as any blow wounds it, Wound.least) and then stunned; a
## shield takes the blow whole; a spider is struck only on its round body (Spider.struck_by); a
## worm only once, in the first segment caught (Wound.whole); things that answer a bolt themselves
## (a switch, a bell, a moth swarm: HexBolt.ANSWERS) answer this too. Rock between the wizard and
## a thing shelters it.

## How far up and down from its middle a thing may be caught (as HexBolt's SPAN_DOWN and SPAN_UP).
const SPAN_DOWN: float = 20.0
const SPAN_UP: float = 56.0
## How finely (px) the way from the wizard to a thing is felt for rock.
const SIGHT_STEP: float = 16.0


## Everything in the hex_target group caught by `catches` (a point in the world -> whether it is
## inside the spell's shape), sheltered by no rock from `from`, each whole thing once (a worm in
## its nearest segment), nearest first. A spider is caught when `catches_spider` says so of it.
static func caught(tree: SceneTree, from: Vector2, catches: Callable, catches_spider: Callable) -> Array[Node]:
	var out: Array[Node] = []
	var wholes: Array[Node] = []
	var found: Array[Node] = []
	for e: Node in tree.get_nodes_in_group(&"hex_target"):
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		found.append(e)
	found.sort_custom(func(a: Node, b: Node) -> bool: return from.distance_squared_to((a as Node2D).global_position) < from.distance_squared_to((b as Node2D).global_position))
	for e: Node in found:
		var at: Vector2 = (e as Node2D).global_position
		var hit: bool = false
		if e is Spider:
			hit = bool(catches_spider.call(e as Spider))
		else:
			for k: int in range(4):
				var p: Vector2 = at + Vector2(0.0, lerpf(SPAN_DOWN, -SPAN_UP, float(k) / 3.0))
				if bool(catches.call(p)) and clear(from, p):
					hit = true
					break
		if not hit:
			continue
		var whole: Node = Wound.whole(e)
		if whole in wholes:
			continue
		wholes.append(whole)
		out.append(e)
	return out


## Whether no rock lies on the way from `from` to `to`, short of the last HexBolt.REACH of it (so a
## thing set just into the rock, a crossbow in its wall, is reached as a hex bolt reaches it).
static func clear(from: Vector2, to: Vector2) -> bool:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return true
	var steps: int = ceili(from.distance_to(to) / SIGHT_STEP)
	for i: int in range(1, steps):
		var p: Vector2 = from.lerp(to, float(i) / float(steps))
		if p.distance_to(to) <= HexBolt.REACH:
			break
		if info.world.is_ground(info.cell_at(p)):
			return false
	return true


## Strike `e` heading `dir`: wound it by `damage` (at least its Wound.least), then stun it for
## `stun` seconds; a shield takes it whole, and what answers a bolt answers.
static func strike(e: Node, dir: Vector2, damage: int, stun: float) -> void:
	var shield: Shield = Shield.of(e)
	if shield != null and shield.absorb(false, dir):
		return
	var wound: Wound = e.get_node_or_null("Wound") as Wound
	var dealt: int = maxi(damage, wound.least) if wound != null else damage
	if wound != null and dealt > 0:
		wound.hit(dealt, dir)
	elif wound != null:
		RisoFx.burst(&"hit", (e as Node2D).global_position, dir, [RisoPrint.ACCENT, RisoPrint.BLUE])
	if wound == null and HexBolt.answers(e):
		e.call("hex_hit", damage, dir)
	var stunner: Stunner = Stunner.of(e)
	if stunner != null and is_instance_valid(e) and not e.is_queued_for_deletion() and stun > 0.0:
		stunner.stun(stun)


## The way the wizard aims a spell: the held direction, else the way they face.
static func aim(player: Player) -> Vector2:
	var dir: Vector2 = Vector2(Input.get_axis("Left", "Right"), Input.get_axis("Up", "Down"))
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT * signf(player.sprite.scale.x if player.sprite != null else 1.0)
	return dir.normalized()


## Where the wizard casts from: their middle, a little up (as the hex leaves the wand).
static func origin(player: Player) -> Vector2:
	return player.global_position + Vector2(0, -24)
