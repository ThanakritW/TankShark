extends SharkPlayer

func setup_class():
	shoot_interval = 0.2
	target_zoom = Vector2(0.6, 0.6)
	
	# 1. จัดการปืน 2 (ล่าง)
	if gun2: 
		gun2.visible = true
		gun2.position = Vector2(0, 15)
		if light_flank: 
			light_flank.position = Vector2(750, 0)
			light_flank.texture_scale = 1.0
			
	# 2. จัดการปืน 1 (บน)
	if gun1: 
		gun1.position = Vector2(0, -15)
		
		if light: 
			light.texture_scale = 1.0
			light.energy = 1.0
			light.position = Vector2(750, 0)
