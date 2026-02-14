extends SharkPlayer

func setup_class():
	shoot_interval = 1.2
	bullet_speed_multiplier = 2.0
	damage_multiplier = 3.0
	target_zoom = Vector2(0.4, 0.4)
	
	if gun2: gun2.visible = false
	if gun1: gun1.position = Vector2.ZERO
	
	if light:
		light.texture_scale = 2.5
		light.position = Vector2(1500, 0)
