extends Camera2D

func shake(intensity: float, direction: Vector2 = Vector2.ZERO) -> void:
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "offset", direction * intensity, 0.5).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "offset", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_BACK)
