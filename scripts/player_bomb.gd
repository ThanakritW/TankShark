extends Area2D

var damage: int = 2
var explode_radius: float = 150.0
var fuse_time: float = 4.0
var owner_peer_id: int = -1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if animated_sprite:
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")
		animated_sprite.animation_finished.connect(_on_animation_finished)

	# Only the server runs the fuse timer
	if multiplayer.is_server():
		var timer = Timer.new()
		timer.wait_time = fuse_time
		timer.one_shot = true
		timer.timeout.connect(_on_fuse_timeout)
		add_child(timer)
		timer.start()

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
	# Play explode animation
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
	var space = get_world_2d().direct_space_state
	# Damage barrels in radius
	var barrels = get_tree().get_nodes_in_group("barrels") if get_tree() else []
	# Fallback: find barrels and walls by iterating the scene
	var world = get_tree().current_scene
	if world:
		_aoe_damage_objects(world)

func _aoe_damage_objects(root: Node):
	for child in root.get_children():
		var dist = global_position.distance_to(child.global_position)
		if dist <= explode_radius:
			# Destroy walls (StaticBody2D named wall_*)
			if child.name.begins_with("wall_") and child is StaticBody2D:
				var world = get_tree().current_scene
				if world and world.has_method("sync_wall_destroy"):
					world.sync_wall_destroy(child.get_path())
			# Damage barrels
			elif child.has_method("take_damage") and child is StaticBody2D:
				child.take_damage(damage)
			# Damage players
			elif child is CharacterBody2D and child.has_method("take_damage"):
				child.take_damage(damage)
		# Recurse into map node which contains walls/mines
		if child.name == "map" or child.name == "Players":
			_aoe_damage_objects(child)

func _on_animation_finished() -> void:
	if animated_sprite.animation == "explode":
		queue_free()
