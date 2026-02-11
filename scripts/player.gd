extends CharacterBody2D

@export var max_speed = 400
@export var acceleration = 1500
@export var sneak_max_speed = 200
@export var sneak_acceleration = 750
@export var friction = 1200
@export var bullet: PackedScene

# Health system
@export var max_health = 10
var current_health = 10

var shooting = false
@export var shoot_interval = 0.2
var shoot_timer = 0.0

func _ready():
	current_health = max_health

func _physics_process(delta):
	move_tank()
	move_shark(delta)

func move_tank():
	var mouse_pos = get_global_mouse_position()
	$tank.look_at(mouse_pos)
	
	# Keeps the sprite upright when looking left
	$tank.flip_v = $tank.global_position.x > mouse_pos.x

func move_shark(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_sneaking = Input.is_action_pressed("sneak")
	
	var current_max_speed = (sneak_max_speed if is_sneaking else max_speed)
	var current_accel = (sneak_acceleration if is_sneaking else acceleration)
	
	var target_velocity = direction * current_max_speed

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, current_accel * delta)
		$shark.flip_h = direction.x > 0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

func _process(delta):
	if shooting:
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot_tank()
			shoot_timer = shoot_interval
	
	if has_node("health"):
		$health.value = current_health

func _input(event):
	if event.is_action_pressed("shoot"):
		shooting = true
		shoot_timer = 0.0  # Start shooting immediately
	elif event.is_action_released("shoot"):
		shooting = false

func shoot_tank():
	if not bullet: return
	var bullet_instance = bullet.instantiate()

	bullet_instance.global_position = $tank/Marker2D.global_position
	bullet_instance.rotation = $tank.rotation
	bullet_instance.add_collision_exception_with(self)
	get_tree().root.add_child(bullet_instance)
	bullet_instance.linear_velocity = Vector2.from_angle($tank.rotation) * 1000

	if bullet_instance.has_method("set_gravity_scale"):
		bullet_instance.set_gravity_scale(0)

func take_damage(amount: int):
	current_health -= amount
	if current_health <= 0:
		current_health = 0
		die()

func heal(amount: int):
	current_health = min(current_health + amount, max_health)

func die():
	print("Player died!")
	# Add death logic here
