extends CharacterBody2D
class_name SharkPlayer

# --- Stats ---
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
var target_zoom = Vector2(0.8, 0.8)

# Game state
var current_health = 30
var max_health = 30
var is_dead = false
var shooting = false
var shoot_timer = 0.0
var current_class: String = "basic"
var bomb_cooldown: float = 0.0
const BOMB_COOLDOWN_TIME: float = 20.0
var player_bomb_scene = preload("res://scenes/player_bomb.tscn")
static var bomb_counter: int = 0

# Nodes
var cam: Camera2D
var gun1: Node2D
var gun2: Node2D
var light: PointLight2D
var light_flank: PointLight2D
var self_light: PointLight2D
var exp_bar: Node
var lv_label: Label

func _ready():
	# Set multiplayer authority based on node name (peer ID)
	var peer_id = str(name).to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)

	refresh_nodes()
	current_health = max_health
	if is_multiplayer_authority():
		if cam: cam.make_current()
		if exp_bar and "max_value" in exp_bar:
			exp_bar.max_value = max_experience
			exp_bar.value = experience
	else:
		if cam: cam.enabled = false
	apply_class("basic")
	_setup_self_light()
	_update_light_visibility()

func refresh_nodes():
	cam = get_node_or_null("Camera2D")
	gun1 = get_node_or_null("gun_pivot1")
	gun2 = get_node_or_null("gun_pivot2")
	lv_label = get_node_or_null("lv_label")
	if gun1: light = gun1.get_node_or_null("PointLight2D")
	if gun2: light_flank = gun2.get_node_or_null("PointLight2D")
	if is_multiplayer_authority():
		var hud = get_tree().root.get_node_or_null("world/HUD")
		if hud: exp_bar = hud.get_node_or_null("exp_bar")

func apply_class(class_id: String):
	current_class = class_id
	# Reset defaults
	damage_multiplier = 1.0
	bullet_speed_multiplier = 1.0
	if gun1: gun1.position = Vector2.ZERO
	if gun2:
		gun2.position = Vector2.ZERO
		gun2.visible = false

	if light:
		light.texture_scale = 1.0
		light.energy = 1.0
		var marker = gun1.get_node("Marker2D")
		light.position = marker.position
		var tex_size = light.texture.get_size()
		light.offset = Vector2(0, tex_size.y / 2)

	match class_id:
		"basic":
			shoot_interval = 0.5
			target_zoom = Vector2(0.8, 0.8)
		"twin":
			shoot_interval = 0.2
			target_zoom = Vector2(0.8, 0.8)
			if gun2:
				gun2.visible = true
				gun2.position = Vector2(0, 15)
				if light_flank:
					var marker2 = gun2.get_node("Marker2D")
					light_flank.position = marker2.position
					var tex_size = light_flank.texture.get_size()
					light_flank.offset = Vector2(0, tex_size.y / 2)
			if gun1:
				gun1.position = Vector2(0, -15)
		"flank":
			shoot_interval = 0.5
			target_zoom = Vector2(0.8, 0.8)
			if gun2:
				gun2.visible = true
				if light_flank:
					var marker2 = gun2.get_node("Marker2D")
					light_flank.position = marker2.position
					var tex_size = light_flank.texture.get_size()
					light_flank.offset = Vector2(0, tex_size.y / 2)
		"sniper":
			shoot_interval = 1.2
			bullet_speed_multiplier = 2.0
			damage_multiplier = 3.0
			target_zoom = Vector2(0.55, 0.55)
			if light:
				light.texture_scale = 2.5
				light.energy = 1.5
				var marker = gun1.get_node("Marker2D")
				light.position = marker.position
				var tex_size = light.texture.get_size()
				light.offset = Vector2(0, tex_size.y / 2 * 2.5)

func _setup_self_light():
	self_light = PointLight2D.new()
	self_light.name = "SelfLight"
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 0.9))
	gradient.set_color(1, Color(1, 1, 0.9, 0))
	var tex = GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	self_light.texture = tex
	self_light.texture_scale = 2.0
	self_light.energy = 0.6
	add_child(self_light)

func _update_light_visibility():
	if not is_multiplayer_authority():
		if light: light.visible = false
		if light_flank: light_flank.visible = false
		if self_light: self_light.visible = false
	else:
		if light: light.visible = true
		if light_flank: light_flank.visible = true
		if self_light: self_light.visible = true

func _physics_process(delta):
	if is_multiplayer_authority():
		move_tank()
		move_shark(delta)
		# Sync position/rotation to all other peers
		var gun1_rot = gun1.rotation if gun1 else 0.0
		var gun2_rot = gun2.rotation if gun2 else 0.0
		var gun2_vis = gun2.visible if gun2 else false
		_sync_movement.rpc(position, velocity, gun1_rot, gun2_rot, gun2_vis, $shark.flip_h, $shark.flip_v)

@rpc("any_peer", "unreliable")
func _sync_movement(pos: Vector2, vel: Vector2, gun1_rot: float, gun2_rot: float, gun2_vis: bool, flip_h: bool, flip_v: bool):
	if is_multiplayer_authority(): return
	position = pos
	velocity = vel
	if gun1: gun1.rotation = gun1_rot
	if gun2:
		gun2.rotation = gun2_rot
		gun2.visible = gun2_vis
	$shark.flip_h = flip_h
	$shark.flip_v = flip_v

func _process(delta):
	if is_multiplayer_authority():
		if cam: cam.zoom = cam.zoom.lerp(target_zoom, 5 * delta)
		if shooting:
			shoot_timer -= delta
			if shoot_timer <= 0:
				shoot_tank()
				shoot_timer = shoot_interval
		if bomb_cooldown > 0:
			bomb_cooldown -= delta
	if has_node("health"): $health.value = current_health

func _input(event):
	if not is_multiplayer_authority(): return
	if is_dead: return
	if Input.is_key_pressed(KEY_1): _request_class_swap("basic")
	if Input.is_key_pressed(KEY_2): _request_class_swap("twin")
	if Input.is_key_pressed(KEY_3): _request_class_swap("flank")
	if Input.is_key_pressed(KEY_4): _request_class_swap("sniper")

	if event.is_action_pressed("shoot"): shooting = true
	elif event.is_action_released("shoot"): shooting = false

	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if bomb_cooldown <= 0:
			var aim_dir = Vector2.from_angle(gun1.global_rotation) if gun1 else Vector2.RIGHT
			_request_throw_bomb.rpc_id(1, global_position, aim_dir)
			bomb_cooldown = BOMB_COOLDOWN_TIME

# --- Class Swap RPCs ---
func _request_class_swap(class_id: String):
	if current_class == class_id: return
	_request_class_swap_server.rpc_id(1, class_id)

@rpc("any_peer", "reliable")
func _request_class_swap_server(class_id: String):
	var sender = multiplayer.get_remote_sender_id()
	if sender != get_multiplayer_authority(): return
	if class_id not in ["basic", "twin", "flank", "sniper"]: return
	_apply_class_all.rpc(class_id)

@rpc("any_peer", "call_local", "reliable")
func _apply_class_all(class_id: String):
	apply_class(class_id)
	_update_light_visibility()

# --- Movement ---
func move_tank():
	var mouse_pos = get_global_mouse_position()
	if gun1: gun1.look_at(mouse_pos)
	if current_class == "flank":
		if gun2: gun2.rotation = gun1.rotation + PI
	else:
		if gun2 and gun2.visible: gun2.look_at(mouse_pos)

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

# --- Shooting RPCs ---
func shoot_tank():
	if not bullet: return
	if not is_multiplayer_authority(): return
	_request_shoot.rpc_id(1)

@rpc("any_peer", "reliable")
func _request_shoot():
	var sender = multiplayer.get_remote_sender_id()
	if sender != get_multiplayer_authority(): return
	_do_shoot.rpc()

@rpc("any_peer", "call_local", "reliable")
func _do_shoot():
	_create_bullet_local(gun1)
	if gun2 and gun2.visible:
		_create_bullet_local(gun2)

func _create_bullet_local(pivot):
	if not pivot: return
	var b = bullet.instantiate()
	b.global_position = pivot.get_node("Marker2D").global_position
	b.rotation = pivot.global_rotation
	b.direction = Vector2.from_angle(pivot.global_rotation)
	b.owner_shooter = self
	if "speed" in b: b.speed *= bullet_speed_multiplier
	if "damage" in b: b.damage = int(b.damage * damage_multiplier)
	get_tree().current_scene.add_child(b)

# --- Damage / Health / XP (server-authoritative, synced via RPC) ---
func take_damage(amount):
	if not multiplayer.is_server(): return
	current_health -= amount
	_sync_health.rpc(current_health)
	if current_health <= 0:
		_sync_die.rpc()

func heal(amount):
	current_health = min(current_health + amount, max_health)
	if multiplayer.is_server():
		_sync_health.rpc(current_health)

@rpc("any_peer", "call_local", "reliable")
func _sync_health(hp: int):
	current_health = hp

@rpc("any_peer", "call_local", "reliable")
func _sync_die():
	is_dead = true
	shooting = false
	$shark.flip_v = true
	# Server checks if there's a winner after this death
	if multiplayer.is_server():
		var world = get_tree().current_scene
		if world and world.has_method("_check_winner"):
			world.call_deferred("_check_winner")

func gain_exp(amt):
	if not multiplayer.is_server(): return
	experience += amt
	if experience >= max_experience:
		_do_level_up()
	_sync_exp.rpc(experience, level, max_experience)

func _do_level_up():
	level += 1
	experience = 0
	max_experience = int(max_experience * 1.1)

@rpc("any_peer", "call_local", "reliable")
func _sync_exp(exp_val: int, lvl: int, max_exp: int):
	experience = exp_val
	level = lvl
	max_experience = max_exp
	_update_lv_label()
	if is_multiplayer_authority() and exp_bar:
		exp_bar.max_value = max_experience
		exp_bar.value = experience

func _update_lv_label():
	if lv_label:
		lv_label.text = "lv " + str(level)

# --- Player Bomb Throw ---
@rpc("any_peer", "reliable")
func _request_throw_bomb(pos: Vector2, dir: Vector2):
	if not multiplayer.is_server(): return
	var sender = multiplayer.get_remote_sender_id()
	if sender != get_multiplayer_authority(): return
	if is_dead: return
	bomb_counter += 1
	var bomb_name = "pbomb_" + str(sender) + "_" + str(bomb_counter)
	var world = get_tree().current_scene
	if world and world.has_method("sync_throw_player_bomb"):
		world.sync_throw_player_bomb(bomb_name, pos, dir, sender)
