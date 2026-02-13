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

# Camera Syetem
@onready var cam = get_node_or_null("Camera2D")
var target_zoom = Vector2(0.6,0.6)

# Class System
enum TankClass { BASIC, TWIN, FLANK, SNIPER }
var current_class = TankClass.BASIC
@onready var gun1 = $gun_pivot1
@onready var gun2 = $gun_pivot2
@onready var light = $gun_pivot1/PointLight2D
var bullet_speed_multiplier = 1.0
var damage_multiplier = 1.0

# Health system
@export var max_health = 10
var current_health = 10
var is_dead = false

var shooting = false
@export var shoot_interval = 0.2
var shoot_timer = 0.0

@onready var exp_bar = get_tree().root.get_node("world/HUD/exp_bar")

func _ready():
	print("LIGHT NODE IS: ", light)
	current_health = max_health
	if exp_bar:
		exp_bar.max_value = max_experience
		exp_bar.value = experience
	update_gun_visuals()

func _physics_process(delta):
	move_tank()
	move_shark(delta)
	
	if Input.is_key_pressed(KEY_1): change_class(TankClass.BASIC)
	if Input.is_key_pressed(KEY_2): change_class(TankClass.TWIN)
	if Input.is_key_pressed(KEY_3): change_class(TankClass.FLANK)
	if Input.is_key_pressed(KEY_4): change_class(TankClass.SNIPER)

func move_tank():
	var mouse_pos = get_global_mouse_position()
	gun1.look_at(mouse_pos)
	
	if current_class == TankClass.FLANK:
		gun2.rotation = gun1.rotation + PI
	else:
		gun2.look_at(mouse_pos)

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
	if cam:
		cam.zoom = cam.zoom.lerp(target_zoom, 5 * delta)
	if shooting:
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot_tank()
			shoot_timer = shoot_interval
	
	if has_node("health"):
		$health.value = current_health

func _input(event):
	if is_dead: return
	
	if event.is_action_pressed("shoot"):
		shooting = true
		#shoot_timer = 0.0
	elif event.is_action_released("shoot"):
		shooting = false

func change_class(new_class):
	current_class = new_class
	update_gun_visuals()

func update_gun_visuals():
	gun1.position = Vector2.ZERO
	gun2.position = Vector2.ZERO
	gun2.visible = false
	bullet_speed_multiplier = 1.0
	damage_multiplier = 1.0
	
	if light:
		light.texture_scale = 1.0
		light.energy = 1.0
		var marker = gun1.get_node("Marker2D")
		light.position = marker.position
		var tex_size = light.texture.get_size()
		light.offset = Vector2(0, tex_size.y/2)

	match current_class:
		TankClass.BASIC:
			target_zoom = Vector2(0.6,0.6)
			shoot_interval = 0.5
		TankClass.TWIN:
			target_zoom = Vector2(0.6,0.6)
			shoot_interval = 0.2
			gun2.visible = true
			gun1.position = Vector2(0, -15)
			gun2.position = Vector2(0, 15)
		TankClass.FLANK:
			target_zoom = Vector2(0.6,0.6)
			shoot_interval = 0.5
			gun2.visible = true
		TankClass.SNIPER:
			shoot_interval = 1.2
			bullet_speed_multiplier = 2.0
			damage_multiplier = 3.0
			target_zoom = Vector2(0.4,0.4)
			if light:
				light.texture_scale = 2.5
				light.energy = 1.5
				var marker = gun1.get_node("Marker2D")
				light.position = marker.position
				var tex_size = light.texture.get_size()
				light.offset = Vector2(0, tex_size.y/2*2.5)
				

func shoot_tank():
	if not bullet: return

	create_bullet(gun1)

	if current_class == TankClass.TWIN or current_class == TankClass.FLANK:
		create_bullet(gun2)

func create_bullet(pivot_node):
	var bullet_instance = bullet.instantiate()
	var marker = pivot_node.get_node("Marker2D")

	bullet_instance.global_position = marker.global_position
	bullet_instance.direction = Vector2.from_angle(pivot_node.global_rotation)
	bullet_instance.rotation = bullet_instance.direction.angle()
	bullet_instance.owner_shooter = self
	
	if "speed" in bullet_instance:
		bullet_instance.speed *= bullet_speed_multiplier

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
	shooting = false
	$shark.flip_v = true

func gain_exp(amount: int):
	experience += amount
	
	if exp_bar:
		exp_bar.value = experience
	
	if experience >= max_experience:
		level_up()

func level_up():
	level += 1
	experience = 0
	max_experience = int(max_experience * 1.1)
	print("Level up! Now level ", level)
	if exp_bar:
		exp_bar.max_value = max_experience
		exp_bar.value = 0
