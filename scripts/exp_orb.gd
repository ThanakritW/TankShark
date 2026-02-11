extends Area2D

@export var exp_amount: int = 1

func _ready():
	# Scale size based on exp amount
	var new_scale = 0.8 + (exp_amount * 0.2)
	scale = Vector2(new_scale, new_scale)
	
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body):
	if body.has_method("gain_exp"):
		body.gain_exp(exp_amount)
		queue_free()
