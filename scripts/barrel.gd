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
	if not multiplayer.is_server(): return
	current_health -= amount
	# Sync via world node (barrels aren't spawner-managed, so direct RPCs don't reach clients)
	var world = get_tree().current_scene
	if world and world.has_method("sync_barrel_damage"):
		world.sync_barrel_damage(get_path(), current_health)
	if current_health <= 0:
		if world and world.has_method("sync_barrel_die"):
			world.sync_barrel_die(get_path(), _get_orb_data())
		else:
			queue_free()

static var orb_counter: int = 0

func _get_orb_data() -> Array:
	var orbs = []
	var num_orbs = randi_range(min_exp_drop, max_exp_drop)
	for i in range(num_orbs):
		var exp_amt = randi_range(min_exp_amount, max_exp_amount)
		var scatter_offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		orb_counter += 1
		orbs.append({"exp": exp_amt, "pos": global_position + scatter_offset, "name": "orb_" + str(orb_counter)})
	return orbs

func apply_damage_visual(hp: int):
	current_health = hp
	health_bar.value = hp
	health_bar.visible = true
	var tween = create_tween()
	modulate = Color(10, 10, 10)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func die_and_spawn_orbs(orbs: Array):
	for orb_data in orbs:
		var exp_orb = exp_orb_scene.instantiate()
		exp_orb.exp_amount = orb_data["exp"]
		exp_orb.global_position = orb_data["pos"]
		exp_orb.name = orb_data["name"]
		get_tree().current_scene.call_deferred("add_child", exp_orb)
	queue_free()
