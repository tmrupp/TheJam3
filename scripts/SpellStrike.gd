class_name SpellStrike
extends RefCounted
## What the damage spells that strike where the wizard stands share (Slash, Nova, Push): finding
## what is caught in a shape round the wizard, and striking it as a hex bolt does (HexBolt). An
## enemy is wounded (at least as much as any blow wounds it, Wound.least), never stunned (only a
## parry stuns); a
## shield takes the blow whole; a spider is struck only on its round body (Spider.struck_by); a
## worm only once, in the first segment caught (Wound.whole); things that answer a bolt themselves
## (a switch, a bell, a moth swarm: HexBolt.ANSWERS) answer this too. Rock between the wizard and
## a thing shelters it. Thorns are struck too (`thorns_caught`). Spells aimed one way throw the
## wizard back (`recoil`): a slash when it lands (on anything, thorns too), a push and a hex bolt
## whenever cast. Cast empowered (Empower), a blow breaks a shield at once and strikes a spire
## (Spire.empowered_hit), and the spell breaks the cracked rock it reaches (`crack`, by cells).

## How far up and down from its middle a thing may be caught (as HexBolt's SPAN_DOWN and SPAN_UP).
const SPAN_DOWN: float = 20.0
const SPAN_UP: float = 56.0
## How finely (px) the way from the wizard to a thing is felt for rock.
const SIGHT_STEP: float = 16.0
## The recoil off a spell (`recoil`), at power 1 (a slash that lands; a push throws harder, a hex
## bolt softer): how fast (px/s) and for how long (seconds, out of the wizard's control) one aimed to
## the side throws them back on the ground, and how many times as fast and as long in the air (more,
## so blows carry an airborne wizard about: off thorns, over a gap); how fast (px/s, up) one aimed
## down from the air bounces them (a pogo, a jump's worth), at most POGO_MOST times that however
## strong it is;
## how fast (px/s, down) one aimed up from the air knocks them down; and how far from straight down
## or up it may be aimed to count as down or up (the aim's y, at least).
const RECOIL: float = 180.0
const RECOIL_TIME: float = 0.1
const AIR_RECOIL: float = 1.7
const AIR_RECOIL_TIME: float = 1.4
const POGO: float = -600.0
const POGO_MOST: float = 1.2
const DOWN_RECOIL: float = 120.0
const POGO_AIM: float = 0.5
## How far (px) from the wizard thorns are looked over for a spell that might strike them.
const THORN_LOOK: float = 400.0


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


## Strike `e` heading `dir`: wound it by `damage` (Wound.dealt: at least its Wound.least, and at least
## 1 while a parry has it stunned); a shield takes it whole (unless `empowered`: then it breaks at
## once), and what answers a bolt answers (a spire flips its tower only to an `empowered` blow).
## `spell` names the spell that struck (&"" for a plain blow); nothing reads it since the institute's
## glyph seals were taken out.
static func strike(e: Node, dir: Vector2, damage: int, _spell: StringName = &"", empowered: bool = false) -> void:
	# A scholar struck by the wizard turns on them (Scholar.rouse), the blow theirs.
	if e is Scholar:
		(e as Scholar).rouse()
		(e as Scholar).wizard_blow = true
	var shield: Shield = Shield.of(e)
	if shield != null and shield.absorb(empowered, dir):
		return
	var wound: Wound = e.get_node_or_null("Wound") as Wound
	var dealt: int = Wound.dealt(wound, damage) if wound != null else damage
	if wound != null and dealt > 0:
		wound.hit(dealt, dir)
	elif wound != null:
		RisoFx.burst(&"hit", (e as Node2D).global_position, dir, [RisoPrint.ACCENT, RisoPrint.BLUE])
	if wound == null and empowered and e is Spire:
		(e as Spire).empowered_hit(dir)
	elif wound == null and HexBolt.answers(e):
		e.call("hex_hit", damage, dir)


## The level cell world position `p` falls in (MapInfo.cell_at), or (-1, -1) outside the game.
static func cell_of(p: Vector2) -> Vector2i:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null or info.tile_map == null:
		return Vector2i(-1, -1)
	return info.cell_at(p)


## An empowered spell breaks the cracked rock at `cells` (CrackedWall.crumble), heading `dir`; how
## many cells of it there were.
static func crack(tree: SceneTree, cells: Array[Vector2i], dir: Vector2) -> int:
	return CrackedWall.crumble_cells(tree, cells, dir)


## The cells round `c` (a cell out, all eight), for a spell breaking rock all round.
static func ring(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			if dx != 0 or dy != 0:
				out.append(c + Vector2i(dx, dy))
	return out


## The cell a step from `c` the way `dir` points most (along a row or a column).
static func step(c: Vector2i, dir: Vector2) -> Vector2i:
	if absf(dir.x) >= absf(dir.y):
		return c + Vector2i(int(signf(dir.x)), 0)
	return c + Vector2i(0, int(signf(dir.y)))


## Throw the wizard back off a spell they cast heading `dir`, at `power` (1 a slash's; see RECOIL).
## Aimed down from the air, they bounce up (POGO), keeping their control and way across, and at
## power 1 or more the air jump is given back, so they can bounce off one thing after another; aimed
## up from the air, they are knocked down a little (DOWN_RECOIL); aimed to the side, they are knocked
## back the other way (RECOIL for RECOIL_TIME, far more in the air), keeping their rise or fall. On
## the ground, aimed down or up, nothing.
static func recoil(player: Player, dir: Vector2, power: float = 1.0) -> void:
	if player == null or player.phasing or power <= 0.0:
		return
	var air: bool = not player.is_on_floor()
	if dir.y >= POGO_AIM:
		if air:
			player.velocity.y = minf(player.velocity.y, POGO * minf(power, POGO_MOST))
			if power >= 1.0:
				player.jumps = maxi(player.jumps, player.MAX_JUMPS - 1)
		return
	if dir.y <= -POGO_AIM:
		if air:
			player.velocity.y = maxf(player.velocity.y, DOWN_RECOIL * power)
		return
	if dir.x == 0.0:
		return
	player.knock = Vector2(-signf(dir.x) * RECOIL * power * (AIR_RECOIL if air else 1.0), player.velocity.y)
	player.knock_back.enable(true)
	player.knock_back.acting = RECOIL_TIME * (AIR_RECOIL_TIME if air else 1.0)


## The thorns that are out caught by `catches` (a point in the world -> whether it is inside the
## spell's shape) somewhere along their body, sheltered by no rock from `from`. Each is shown struck;
## nothing else comes of it to them (see Spikes).
static func thorns_caught(tree: SceneTree, from: Vector2, catches: Callable, dir: Vector2) -> Array[Spikes]:
	var out: Array[Spikes] = []
	for n: Node in tree.get_nodes_in_group(Spikes.GROUP):
		var thorns: Spikes = n as Spikes
		if thorns == null or not thorns.out or thorns.is_queued_for_deletion() or thorns.global_position.distance_to(from) > THORN_LOOK:
			continue
		var ends: Array[Vector2] = thorns.body_ends()
		for k: int in range(5):
			var p: Vector2 = ends[0].lerp(ends[1], float(k) / 4.0)
			if bool(catches.call(p)) and clear(from, p):
				out.append(thorns)
				RisoFx.burst(&"hit", p, dir, [RisoPrint.ACCENT, RisoPrint.BLUE])
				break
	return out


## The way the wizard aims a spell: the held direction, else the way they face.
static func aim(player: Player) -> Vector2:
	var dir: Vector2 = Vector2(Input.get_axis("Left", "Right"), Input.get_axis("Up", "Down"))
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT * signf(player.sprite.scale.x if player.sprite != null else 1.0)
	return dir.normalized()


## Where the wizard casts from: their middle, a little up (as the hex leaves the wand).
static func origin(player: Player) -> Vector2:
	return player.global_position + Vector2(0, -24)
