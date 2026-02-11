extends StaticBody2D

@export var max_health: int = 3
@export var min_exp_drop: int = 1
@export var max_exp_drop: int = 4
@export var min_exp_amount: int = 1
@export var max_exp_amount: int = 5

@onready var health_bar: ProgressBar = $ProgressBar

var current_health: int

var exp_orb_scene = preload("res://scenes/exp_orb.tscn")

func _ready() -> void:
	current_health = max_health
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.visible = false

func take_damage(amount: int) -> void:
	current_health -= amount
	health_bar.value = current_health
	health_bar.visible = true
	
	# Flash effect
	var tween = create_tween()
	modulate = Color(10, 10, 10)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	var num_orbs = randi_range(min_exp_drop, max_exp_drop)
	
	for i in range(num_orbs):
		var exp_orb = exp_orb_scene.instantiate()
		exp_orb.exp_amount = randi_range(min_exp_amount, max_exp_amount)
		
		# Scatter them slightly
		var scatter_offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		exp_orb.global_position = global_position + scatter_offset
		
		get_tree().current_scene.call_deferred("add_child", exp_orb)
	
	queue_free()
