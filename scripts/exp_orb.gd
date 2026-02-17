extends Area2D

@export var exp_amount: int = 1

func _ready():
	var new_scale = 0.8 + (exp_amount * 0.2)
	scale = Vector2(new_scale, new_scale)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if not multiplayer.is_server(): return
	if "is_dead" in body and body.is_dead: return
	if body.has_method("gain_exp"):
		body.gain_exp(exp_amount)
		var world = get_tree().current_scene
		if world and world.has_method("sync_remove_orb"):
			world.sync_remove_orb(get_path())
		else:
			queue_free()
