class_name BossDeath
extends RefCounted
## A boss's death, the part the bosses that fall apart over a while share (the beast, the
## necromancer, the golem): once only, out of the hex bolts' reach at once, the screen shaken and a
## burst of ink where it falls (begin); `length` seconds on (step), slain (fall): MapInfo.boss_slain
## told where its relic waits, and the boss gone. Each boss keeps what is its own (the beast's slam
## and sweep stopping, the necromancer's skeletons falling back, the golem's loose stones) and
## reads how far its dying has gone (share) for its art.

## The boss.
var boss: Node2D
## How long (seconds) it takes to die once its last wound is dealt.
var length: float = 1.0
## Seconds into its dying (-1 while it is not dying), and whether it is slain.
var t: float = -1.0
var slain: bool = false


func _init(of: Node2D, how_long: float) -> void:
	boss = of
	length = how_long


## Dying or slain: out of the fight.
func dying() -> bool:
	return t >= 0.0 or slain


## How far its dying has gone, 0 to 1 (0 while it is not dying).
func share() -> float:
	return clampf(t / length, 0.0, 1.0) if t >= 0.0 else 0.0


## Its last wound: it begins to die, unless it is already dying (false then). It leaves the hex
## bolts' targets, the screen shakes `shake` hard for `sustain` seconds, and a burst of `inks` goes
## up at `at`.
func begin(shake: float, sustain: float, at: Vector2, inks: Array[int]) -> bool:
	if dying():
		return false
	t = 0.0
	boss.remove_from_group(&"hex_target")
	Wound.shake(shake, sustain)
	RisoFx.burst(&"gain", at, Vector2.ZERO, inks)
	return true


## A physics step of `delta` seconds: true on the step its dying runs out (the boss falls then).
func step(delta: float) -> bool:
	if slain or t < 0.0:
		return false
	t += delta
	return t >= length


## It is slain: MapInfo `info` (if any) is told that boss `boss_name`'s relic waits at `relic_at`,
## and it is freed.
func fall(info: MapInfo, boss_name: StringName, relic_at: Vector2) -> void:
	slain = true
	if info != null:
		info.boss_slain(boss_name, relic_at)
	boss.queue_free()
