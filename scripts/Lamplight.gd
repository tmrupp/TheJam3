class_name Lamplight
extends RefCounted
## Light as the game reads it, apart from how it is printed (RisoLight): whether light falls on a
## point. Light comes from the lantern the wizard carries while its flame is lit (while a lit
## lantern protects them, and not snuffed: MapInfo.flame_lit, so not after a death or at a font) and
## from every lantern not burnt out, each reaching LIT_SHARE of the reach RisoLight prints it with,
## and rock stops it: the flame must see the point. The moon over the cemetery's terraces is no
## light here, nor are the small things that shine. What reads it: the wraiths freeze in it
## (Wraith), the skeletons wake in it (Skeleton), and the necromancer can be wounded only in it
## (Necromancer). A charge of darkness spent by a dash out of the dark (MapInfo.dash_switch) flares:
## for FLARE_TIME the flame reaches FLARE_REACH times as far (carried_reach), easing back over the
## last FLARE_FADE of it.
## Sneaking: while the flame the wizard carries is out, the enemies that notice them from afar
## notice them only SNEAK as far off (notice): a watcher's and a crossbow's sight, a hopper's, a
## bird's and a scholar's, an abomination's sense. (A wraith hunts only a wizard whose flame is out,
## and a skeleton wakes only in light, so they are as ever.)

## How much of a light's printed reach counts as lit: past it the printed light is faint.
const LIT_SHARE: float = 0.85
## How far apart (px) the line from a light to a point is tested for rock.
const STEP: float = 16.0
## How far (px) from the flame the test for rock starts, so a flame swung against a wall still
## lights the room it is in.
const FLAME_ROOM: float = 12.0
## How high over its cell's middle a lantern's light is (px): its glass, a little over the floor.
const LANTERN_RISE: float = 24.0
## The flare of a spent charge: how long it burns (s), how much further the flame reaches at its
## height, and how long it takes to rise and to ease back (s).
const FLARE_TIME: float = 0.6
const FLARE_REACH: float = 1.5
const FLARE_RISE: float = 0.06
const FLARE_FADE: float = 0.25
## How much of its usual reach an enemy notices the wizard within while their flame is out.
const SNEAK: float = 0.6

## The lights as last worked out (each where it is and how far it reaches as lit, x, y, z), and the
## physics frame they were worked out in: they are worked out once a frame, however many ask.
static var _lights: Array[Vector3] = []
static var _frame: int = -1


## Whether light falls on `pos`.
static func at(pos: Vector2) -> bool:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return false
	for light: Vector3 in lights(info):
		var from: Vector2 = Vector2(light.x, light.y)
		if from.distance_to(pos) <= light.z and sees(info, from, pos):
			return true
	return false


## Which way is away from the light falling on `pos` (a unit vector): from each light that reaches it,
## the nearer the light the more; zero where none does.
static func away(pos: Vector2) -> Vector2:
	var info: MapInfo = MapInfo.instance
	if info == null or info.world == null:
		return Vector2.ZERO
	var out: Vector2 = Vector2.ZERO
	for light: Vector3 in lights(info):
		var from: Vector2 = Vector2(light.x, light.y)
		var d: float = from.distance_to(pos)
		if d <= light.z and sees(info, from, pos):
			var off: Vector2 = (pos - from).normalized() if d > 0.5 else Vector2.UP
			out += off * (1.0 - d / maxf(light.z, 1.0) + 0.1)
	return out.normalized()


## The lights of the level being played (see the class note), as (x, y, reach as lit).
static func lights(info: MapInfo) -> Array[Vector3]:
	var frame: int = Engine.get_physics_frames()
	if frame == _frame:
		return _lights
	_frame = frame
	_lights = []
	var player: Player = info.player
	if player != null and is_instance_valid(player) and not player.phasing and info.run != null and info.flame_lit():
		var eye: Vector2 = RisoLight.eye(player)
		_lights.append(Vector3(eye.x, eye.y, carried_reach(info) * LIT_SHARE))
	if info.map_elements != null and is_instance_valid(info.map_elements):
		for node: Node in info.map_elements.get_children():
			var lantern: Checkpoint = node as Checkpoint
			if lantern == null or lantern.is_queued_for_deletion() or info.is_lantern_spent(lantern):
				continue
			var reach: float = RisoLight.RESPAWN_REACH if info.is_respawn_lantern(lantern) else RisoLight.FAINT_REACH
			var at: Vector2 = info.cell_position(info.cell_at(lantern.global_position)) + Vector2(0, -LANTERN_RISE)
			_lights.append(Vector3(at.x, at.y, reach * LIT_SHARE))
	return _lights


## How far off (px) an enemy that notices the wizard within `reach` while their flame burns notices
## them now: SNEAK of it while the flame is out (see the class note).
static func notice(reach: float) -> float:
	var info: MapInfo = MapInfo.instance
	if info == null or info.run == null or info.flame_lit():
		return reach
	return reach * SNEAK


## How far the lantern the wizard carries reaches while lit (px): RisoLight.CARRIED_REACH, further
## while a flare burns (see FLARE_TIME).
static func carried_reach(info: MapInfo) -> float:
	return RisoLight.CARRIED_REACH * flare_scale(info.flare if info != null else 0.0)


## How many times as far the flame reaches with `left` seconds of a flare to burn.
static func flare_scale(left: float) -> float:
	if left <= 0.0:
		return 1.0
	var k: float = minf(1.0, (FLARE_TIME - left) / FLARE_RISE) * minf(1.0, left / FLARE_FADE)
	return 1.0 + (FLARE_REACH - 1.0) * k


## Whether a light at `from` sees `to`: no rock (MapInfo.solid_at) on the line between, past the
## flame's own room, nor at `to` itself.
static func sees(info: MapInfo, from: Vector2, to: Vector2) -> bool:
	var d: float = from.distance_to(to)
	if info.solid_at(to):
		return false
	var s: float = FLAME_ROOM
	while s < d:
		if info.solid_at(from.lerp(to, s / d)):
			return false
		s += STEP
	return true
