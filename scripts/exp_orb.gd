extends Area2D

@export var exp_amount: int = 1

func _ready():
	var new_scale = 0.8 + (exp_amount * 0.2)
	scale = Vector2(new_scale, new_scale)

	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if not multiplayer.is_server(): return
	if body.has_method("gain_exp"):
		body.gain_exp(exp_amount)
		_remove_orb.rpc()

@rpc("authority", "call_local", "reliable")
func _remove_orb():
	queue_free()
