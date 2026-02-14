extends SharkPlayer

func setup_class():
	shoot_interval = 0.5
	target_zoom = Vector2(0.6, 0.6)
	
	if gun2: 
		gun2.visible = true
		if light_flank: 
			light_flank.position = Vector2(750, 0)
			light_flank.texture_scale = 1.0

	if light:
		light.texture_scale = 1.0
		light.energy = 1.0
		light.position = Vector2(750, 0)

func move_tank():
	var mouse_pos = get_global_mouse_position()
	if gun1: gun1.look_at(mouse_pos)
	if gun2: gun2.rotation = gun1.rotation + PI
