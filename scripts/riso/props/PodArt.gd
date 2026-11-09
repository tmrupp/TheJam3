extends RisoProp
## A seed pod (SeedPod): one of the bramble's bulbs in bloom, printed by the bramble's own art
## (Bramble.ink_bulb) from its root in the wall: a cup of bark, the gold bulb swelling out of it as
## it readies a seed, its hits left as dark dots, flashing pink when a parried seed wounds it and
## pale blue when a blow glances off, shrouded in leaves that part as it readies a seed and fold
## shut again after it spits (Bramble.leaves_parted).


## The SeedPod it dresses.
var pod: SeedPod:
	get:
		return host.get_node_or_null("SeedPod") as SeedPod if host != null else null


func _draw_art() -> void:
	var p: SeedPod = pod
	if p == null:
		return
	var wound: Wound = host.get_node_or_null("Wound") as Wound
	var now: int = Time.get_ticks_msec()
	var flash: float = clampf(1.0 - float(now - p.struck_at) / 1000.0 / Bramble.FLASH_TIME, 0.0, 1.0)
	var glance: float = clampf(1.0 - float(now - p.warded_at) / 1000.0 / Bramble.FLASH_TIME, 0.0, 1.0)
	# Its root at the wall's face, out of the rock along its way (the art sits on the pod's middle).
	var xf: Transform2D = Transform2D(p.way.angle(), -p.way * SeedPod.OUT)
	var since: float = float(now - p.spat_at) / 1000.0
	Bramble.ink_bulb(ink, xf, 1.0, p.charge, t * 3.0 + phase, flash, false, glance, wound.hp if wound != null else 0, Bramble.leaves_parted(p.charge, since))
