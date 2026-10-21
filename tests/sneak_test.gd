extends TestKit
## Sneaking (Lamplight.notice): while the wizard's flame is out, the enemies that notice them from
## afar notice them only Lamplight.SNEAK as far off. An abomination (which senses without sight)
## goes for a wizard most of its reach away while their flame burns, and leaves them be once it is
## snuffed, until they come nearer.
## godot --headless --path . --script res://tests/sneak_test.gd


func run() -> void:
	await boot()
	check(info.flame_lit() and Lamplight.notice(1000.0) == 1000.0, "while the flame burns, an enemy notices the wizard as far off as ever")
	info.snuff(player.global_position)
	check(not info.flame_lit() and is_equal_approx(Lamplight.notice(1000.0), 1000.0 * Lamplight.SNEAK), "snuffed, only %.0f%% as far" % (Lamplight.SNEAK * 100.0))
	info.relight()
	check(info.flame_lit(), "lit again")

	info.coord = Vector2i(28, NextWorldDef.band_row(&"institute", 0))
	info.arrival = MapInfo.Exit.BACK
	info._load_level()
	await settle()
	player.set_physics_process(false)
	player.invulnerable.enable()
	var found: Array[Node] = placed("abomination.tscn")
	check(not found.is_empty(), "an abomination in the institute")
	if found.is_empty():
		finish()
		return
	var beast: Abomination = found[0] as Abomination
	# Only the wizard to sense: the scholars about are taken away.
	for n: Node in get_nodes_in_group(&"scholar"):
		n.free()
	var away: Vector2 = beast.global_position + Vector2(Abomination.SENSE * 0.8, 0)
	player.global_position = away
	check(info.flame_lit() and beast._find_quarry() == player, "lit, it senses the wizard %.0f px off" % (Abomination.SENSE * 0.8))
	info.snuff(away)
	player.global_position = away
	check(not info.flame_lit() and beast._find_quarry() == null, "snuffed, it does not")
	player.global_position = beast.global_position + Vector2(Abomination.SENSE * Lamplight.SNEAK * 0.8, 0)
	check(beast._find_quarry() == player, "until they come within %.0f px" % (Abomination.SENSE * Lamplight.SNEAK))
	info.relight()
	RunState.delete_save()
	finish()
