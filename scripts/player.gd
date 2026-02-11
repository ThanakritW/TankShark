extends CharacterBody2D

@export var max_speed = 400
@export var acceleration = 1500
@export var sneak_max_speed = 200
@export var sneak_acceleration = 750
@export var friction = 1200

func _physics_process(delta):
	move_tank()
	move_shark(delta)
	
func move_tank():
	$tank.look_at(get_global_mouse_position())
	
	if $tank.global_position.x < get_global_mouse_position().x:
		$tank.flip_v = false
	else:
		$tank.flip_v = true
	
func move_shark(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var is_sneaking = Input.is_action_pressed("sneak")
	
	var current_max_speed = sneak_max_speed if is_sneaking else max_speed
	
	var target_velocity = direction * current_max_speed

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	if direction.x > 0:
		$shark.flip_h = true
	elif direction.x < 0:
		$shark.flip_h = false

	move_and_slide()
