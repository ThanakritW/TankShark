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

# Camera System
@onready var cam = get_node_or_null("Camera2D")
var target_zoom = Vector2(0.6, 0.6)

# Class Stats (จะถูกเปลี่ยนในสคริปต์ลูก)
var shoot_interval = 0.5
var bullet_speed_multiplier = 1.0
var damage_multiplier = 1.0

# Health system
@export var max_health = 10
var current_health = 10
var is_dead = false

var shooting = false
var shoot_timer = 0.0

@onready var gun1 = $gun_pivot1
@onready var gun2 = $gun_pivot2
@onready var light = $gun_pivot1/PointLight2D
@onready var light_flank = $gun_pivot2/PointLight2D
@onready var exp_bar = get_tree().root.get_node_or_null("world/HUD/exp_bar")

func _ready():
	current_health = max_health
	if exp_bar:
		exp_bar.max_value = max_experience
		exp_bar.value = experience
	setup_class_stats()

# คลาสลูกจะมาเขียนทับฟังก์ชันนี้
func setup_class_stats():
	# Default Basic settings
	target_zoom = Vector2(0.6, 0.6)
	shoot_interval = 0.5
	gun2.visible = false
	if light:
		light.texture_scale = 1.0
		light.position = Vector2(750, 0)

func _physics_process(delta):
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	move_tank()
	move_shark(delta)

func move_tank():
	var mouse_pos = get_global_mouse_position()
	gun1.look_at(mouse_pos)
	# Logic การเล็งปกติ (Flank จะ Override อันนี้)
	if gun2: gun2.look_at(mouse_pos)

func move_shark(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_sneaking = Input.is_action_pressed("sneak")
	var current_max_speed = sneak_max_speed if is_sneaking else max_speed
	var target_velocity = direction * current_max_speed

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
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

func _input(event):
	if is_dead: return
	
	# เปลี่ยนสคริปต์ (ระบุ Path ให้ตรงกับที่เก็บไฟล์จริง)
	if Input.is_key_pressed(KEY_1): change_class_script("res://scripts/basic_shark.gd")
	if Input.is_key_pressed(KEY_2): change_class_script("res://scripts/twin_shark.gd")
	if Input.is_key_pressed(KEY_3): change_class_script("res://scripts/flank_shark.gd")
	if Input.is_key_pressed(KEY_4): change_class_script("res://scripts/sniper_shark.gd")

	if event.is_action_pressed("shoot"):
		shooting = true
		shoot_timer = 0.0
	elif event.is_action_released("shoot"):
		shooting = false

func change_class_script(path: String):
	if FileAccess.file_exists(path):
		set_script(load(path))
		# สำคัญ: เมื่อเปลี่ยน Script ต้องเรียก _ready หรือ setup ใหม่เอง
		setup_class_stats()

func shoot_tank():
	if not bullet: return
	create_bullet(gun1)
	if gun2 and gun2.visible:
		create_bullet(gun2)

func create_bullet(pivot_node):
	var b = bullet.instantiate()
	var marker = pivot_node.get_node("Marker2D")
	b.global_position = marker.global_position
	b.direction = Vector2.from_angle(pivot_node.global_rotation)
	b.rotation = b.direction.angle()
	b.owner_shooter = self
	if "speed" in b: b.speed *= bullet_speed_multiplier
	get_tree().current_scene.add_child(b)
