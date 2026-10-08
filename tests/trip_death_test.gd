extends TestKit
## Dying while stepping through a portal: the trip is cut short, and once the wizard is back (at
## the lantern, or at the start of a new run) they are seen again and can use portals, with no
## trip left hanging.
## godot --headless --path . --script res://tests/trip_death_test.gd


func run() -> void:
	await boot(28)
	for protected: bool in [true, false]:
		print("protected" if protected else "unprotected")
		player.set_physics_process(false)
		info.run.vulnerable = not protected
		var portal: Portal = placed("portal.tscn")[0] as Portal
		player.global_position = portal.global_position
		player.end_invulnerable()
		portal.use_portal()
		var wizard: RisoWizard = player.get_node("RisoWizard") as RisoWizard
		check(player.has_meta(&"portal_trip") and wizard.vanished, "stepping in, the wizard vanishes into the portal")
		player.die()
		# Long enough for the trip to have played out, and for a run's end card.
		await until(func() -> bool: return info.run_ending <= 0.0 and not info.travelling, 8000)
		await settle()
		await frames(30)
		check(not wizard.vanished, "back after dying mid-trip, the wizard is seen again")
		check(not player.has_meta(&"portal_trip"), "and no trip is left hanging, so portals work again")
	finish()
