extends SharkPlayer

func setup_class():
	shoot_interval = 0.5
	target_zoom = Vector2(0.6, 0.6)
	bullet_speed_multiplier = 1.0
	
	if gun2: gun2.visible = false
	if gun1: gun1.position = Vector2.ZERO
	
	if light:
		light.texture_scale = 1.0
		light.position = Vector2(750, 0)
