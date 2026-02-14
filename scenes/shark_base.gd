extends CharacterBody2D

@export var max_speed = 400
@export var acceleration = 1500
@export var sneak_max_speed = 200
@export var sneak_acceleration = 750
@export var friction = 1200
@export var bullet: PackedScene

# ตัวแปรที่จะถูกเปลี่ยนในคลาสลูก
var shoot_interval = 0.5
var bullet_speed_multiplier = 1.0

var shooting = false
var shoot_timer = 0.0
var is_dead = false

@onready var gun1 = $gun_pivot1
@onready var gun2 = $gun_pivot2
@onready var light = $gun_pivot1/PointLight2D

func _ready():
	setup_class()

# ฟังก์ชันที่คลาสลูกจะมาเขียนทับ (Override)
func setup_class():
	pass

func _physics_process(delta):
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	move_shark(delta)
	move_tank()

func move_tank():
	var mouse_pos = get_global_mouse_position()
	gun1.look_at(mouse_pos)
	if gun2: 
		gun2.look_at(mouse_pos)

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

func _input(event):
	if is_dead: return
	
	# ระบบสลับคลาส (Manager)
	if Input.is_key_pressed(KEY_1): change_to_class("res://basic_shark.gd")
	if Input.is_key_pressed(KEY_2): change_to_class("res://twin_shark.gd")
	if Input.is_key_pressed(KEY_3): change_to_class("res://flank_shark.gd")
	if Input.is_key_pressed(KEY_4): change_to_class("res://sniper_shark.gd")

	if event.is_action_pressed("shoot"):
		shooting = true
		shoot_timer = 0.0
	elif event.is_action_released("shoot"):
		shooting = false

func change_to_class(script_path):
	set_script(load(script_path))
	_ready() # เรียกใช้อีกครั้งเพื่อตั้งค่าคลาสใหม่

func shoot_tank():
	if not bullet: return
	create_bullet(gun1)
	if gun2 and gun2.visible:
		create_bullet(gun2)

func create_bullet(pivot_node):
	var b = bullet.instantiate()
	b.global_position = pivot_node.get_node("Marker2D").global_position
	b.direction = Vector2.from_angle(pivot_node.global_rotation)
	b.rotation = b.direction.angle()
	if "speed" in b: b.speed *= bullet_speed_multiplier
	get_tree().current_scene.add_child(b)
