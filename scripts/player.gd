extends CharacterBody2D
class_name SharkPlayer  # <--- ใส่ชื่อนี้เพื่อแก้ปัญหา Circular Dependency

# --- 1. ประกาศตัวแปรทุกอย่างที่นี่ก่อน (ห้ามลืม!) ---
@export var max_speed = 400
@export var acceleration = 1500
@export var sneak_max_speed = 200
@export var sneak_acceleration = 750
@export var friction = 1200
@export var experience: int = 0
@export var max_experience: int = 10
var level: int = 1
var bullet = preload("res://scenes/bullet.tscn")
var shoot_interval = 0.5
var bullet_speed_multiplier = 1.0
var damage_multiplier = 1.0
var target_zoom = Vector2(0.6, 0.6)

# ระบบเกม
var current_health = 10
var max_health = 10
var is_dead = false
var shooting = false
var shoot_timer = 0.0

# โหนด (Nodes)
var cam: Camera2D
var gun1: Node2D
var gun2: Node2D
var light: PointLight2D
var light_flank: PointLight2D
var exp_bar: Node

func _ready():
	refresh_nodes()
	current_health = max_health
	if exp_bar and "max_value" in exp_bar:
		exp_bar.max_value = max_experience
		exp_bar.value = experience
	setup_class()

func refresh_nodes():
	cam = get_node_or_null("Camera2D")
	gun1 = get_node_or_null("gun_pivot1")
	gun2 = get_node_or_null("gun_pivot2")
	if gun1: light = gun1.get_node_or_null("PointLight2D")
	if gun2: light_flank = gun2.get_node_or_null("PointLight2D")
	var hud = get_tree().root.get_node_or_null("world/HUD")
	if hud: exp_bar = hud.get_node_or_null("exp_bar")

func setup_class():
	shoot_interval = 0.5
	target_zoom = Vector2(0.6, 0.6)
	bullet_speed_multiplier = 1.0
	if gun2: gun2.visible = false
	if gun1: gun1.position = Vector2.ZERO
	if light:
		light.texture_scale = 1.0
		light.energy = 1.0
		light.position = Vector2(750, 0)

func _physics_process(delta):
	move_tank()
	move_shark(delta)

func _process(delta):
	if cam: cam.zoom = cam.zoom.lerp(target_zoom, 5 * delta)
	if shooting:
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot_tank()
			shoot_timer = shoot_interval
	if has_node("health"): $health.value = current_health

func _input(event):
	if is_dead: return
	# เปลี่ยนคลาส (แก้ Path ให้ตรงกับที่คุณเซฟไฟล์ลูกไว้)
	if Input.is_key_pressed(KEY_1): swap_script("res://scripts/classes/basic.gd")
	if Input.is_key_pressed(KEY_2): swap_script("res://scripts/classes/twin.gd")
	if Input.is_key_pressed(KEY_3): swap_script("res://scripts/classes/flank.gd")
	if Input.is_key_pressed(KEY_4): swap_script("res://scripts/classes/sniper.gd")
	
	if event.is_action_pressed("shoot"): shooting = true
	elif event.is_action_released("shoot"): shooting = false

func swap_script(path):
	if not FileAccess.file_exists(path): return
	var old_bullet = bullet
	var old_xp = experience
	var old_lvl = level
	var old_hp = current_health
	
	set_script(load(path))
	
	bullet = old_bullet
	experience = old_xp
	level = old_lvl
	current_health = old_hp
	
	refresh_nodes()
	setup_class()

func move_tank():
	var mouse_pos = get_global_mouse_position()
	if gun1: gun1.look_at(mouse_pos)
	if gun2: gun2.look_at(mouse_pos)

func move_shark(delta):
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_sneaking = Input.is_action_pressed("sneak")
	var spd = sneak_max_speed if is_sneaking else max_speed
	var acc = sneak_acceleration if is_sneaking else acceleration
	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * spd, acc * delta)
		$shark.flip_h = direction.x > 0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

func shoot_tank():
	if not bullet: return
	create_bullet(gun1)
	if gun2 and gun2.visible: create_bullet(gun2)

func create_bullet(pivot):
	if not pivot: return
	var b = bullet.instantiate()
	b.global_position = pivot.get_node("Marker2D").global_position
	b.rotation = pivot.global_rotation
	b.direction = Vector2.from_angle(pivot.global_rotation)
	b.owner_shooter = self
	if "speed" in b: b.speed *= bullet_speed_multiplier
	get_tree().current_scene.add_child(b)

func take_damage(amount):
	current_health -= amount
	if current_health <= 0: die()
func heal(amount): current_health = min(current_health + amount, max_health)
func die(): is_dead = true; shooting = false; $shark.flip_v = true
func gain_exp(amt): experience += amt; if exp_bar: exp_bar.value = experience; if experience >= max_experience: level_up()
func level_up(): level += 1; experience = 0; max_experience = int(max_experience * 1.1); if exp_bar: exp_bar.max_value = max_experience; exp_bar.value = 0
