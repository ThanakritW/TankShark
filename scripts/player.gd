extends CharacterBody2D

@export var max_speed = 400
@export var acceleration = 1500
@export var sneak_max_speed = 200
@export var sneak_acceleration = 750
@export var friction = 1200
@export var bullet: PackedScene
@export var experience: int = 0
@export var max_experience: int = 10
var level: int = 1

# Health system
@export var max_health = 10
var current_health = 10
var is_dead = false

var shooting = false
@export var shoot_interval = 0.2
var shoot_timer = 0.0

@onready var exp_bar = get_tree().root.get_node("world/HUD/exp_bar")

func _ready():
	current_health = max_health
	if exp_bar:
		exp_bar.max_value = max_experience
		exp_bar.value = experience

func _physics_process(delta):
	move_tank()
	move_shark(delta)

func move_tank():
	var mouse_pos = get_global_mouse_position()
	$gun_pivot.look_at(mouse_pos)

func move_shark(delta):
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
		
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
	if not bullet:
		return

	var bullet_instance = bullet.instantiate()

	bullet_instance.global_position = $gun_pivot/Marker2D.global_position
	bullet_instance.direction = Vector2.from_angle($gun_pivot.global_rotation)
	bullet_instance.rotation = bullet_instance.direction.angle()
	bullet_instance.owner_shooter = self

	get_tree().current_scene.add_child(bullet_instance)


func take_damage(amount: int):
	current_health -= amount
	if current_health <= 0:
		current_health = 0
		die()

func heal(amount: int):
	current_health = min(current_health + amount, max_health)

func die():
	print("Player died!")
	is_dead = true
	$shark.flip_v = true
	# Add death logic here

func gain_exp(amount: int):
	experience += amount
	
	# Update HUD
	if exp_bar:
		exp_bar.value = experience
	
	# Level up if max experience reached
	if experience >= max_experience:
		level_up()

func level_up():
	level += 1
	experience = 0
	max_experience = int(max_experience * 1.1)  # Increase exp needed by 10%
	print("Level up! Now level ", level)
	if exp_bar:
		exp_bar.max_value = max_experience
		exp_bar.value = 0
