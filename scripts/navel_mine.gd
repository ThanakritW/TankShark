extends Area2D

@export var damage: int = 2
@export var explode_on_hit: bool = true

var triggered := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.play("idle")

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server(): return
	if triggered: return
	triggered = true
	if body.has_method("take_damage"):
		body.take_damage(damage)
	_trigger_explode()

func _on_area_entered(area: Area2D) -> void:
	if not multiplayer.is_server(): return
	if triggered: return
	# Bullet hit the mine — explode without dealing damage to a player
	triggered = true
	area.queue_free()  # Destroy the bullet
	_trigger_explode()

func _trigger_explode():
	var world = get_tree().current_scene
	if world and world.has_method("explode_mine_at_path"):
		world.explode_mine_at_path(get_path())
	else:
		_do_explode()

func _do_explode():
	triggered = true
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if explode_on_hit:
		if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("explode"):
			animated_sprite.play("explode")
		else:
			queue_free()

func _on_animation_finished() -> void:
	if triggered and explode_on_hit:
		queue_free()
