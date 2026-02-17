extends Area2D

var damage: int = 10
var explode_radius: float = 250.0
var fuse_time: float = 4.0
var owner_peer_id: int = -1
var speed: float = 600.0
var direction: Vector2 = Vector2.RIGHT
var stuck: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		animated_sprite.animation_finished.connect(_on_animation_finished)

	# Detect collision with bodies (walls, barrels, players)
	body_entered.connect(_on_body_entered)

	# Only the server runs the fuse timer
	if multiplayer.is_server():
		var timer = Timer.new()
		timer.wait_time = fuse_time
		timer.one_shot = true
		timer.timeout.connect(_on_fuse_timeout)
		add_child(timer)
		timer.start()

func _physics_process(delta):
	if stuck:
		return
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if stuck:
		return
	# Don't stick to the player who threw it
	if body is CharacterBody2D and str(body.name).to_int() == owner_peer_id:
		return
	stuck = true

func _on_fuse_timeout():
	if not multiplayer.is_server(): return
	_detonate()

func _detonate():
	var world = get_tree().current_scene
	if world and world.has_method("sync_player_bomb_explode"):
		world.sync_player_bomb_explode(get_path())
	else:
		_do_explode()

func _do_explode():
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("explode"):
		animated_sprite.play("explode")
	else:
		_apply_aoe()
		queue_free()
		return

	# AOE damage is applied by the server only
	if multiplayer.is_server():
		_apply_aoe()

func _apply_aoe():
	var world = get_tree().current_scene
	if world:
		_aoe_damage_objects(world)

func _aoe_damage_objects(root: Node):
	for child in root.get_children():
		# Skip non-Node2D nodes (CanvasLayer, Control, etc. don't have global_position)
		if not (child is Node2D):
			continue
		var dist = global_position.distance_to(child.global_position)
		if dist <= explode_radius:
			# Destroy walls (StaticBody2D named wall_*)
			if child.name.begins_with("wall_") and child is StaticBody2D:
				var w = get_tree().current_scene
				if w and w.has_method("sync_wall_destroy"):
					w.sync_wall_destroy(child.get_path())
			# Damage barrels
			elif child.has_method("take_damage") and child is StaticBody2D:
				child.take_damage(damage)
			# Damage players
			elif child is CharacterBody2D and child.has_method("take_damage"):
				child.take_damage(damage)
		# Recurse into Node2D containers (map, Players, BarrelSpawners, etc.)
		if child.get_child_count() > 0:
			_aoe_damage_objects(child)

func _on_animation_finished() -> void:
	if animated_sprite.animation == "explode":
		queue_free()
