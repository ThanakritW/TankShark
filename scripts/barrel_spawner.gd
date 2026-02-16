extends Node2D

@export var barrel_scene: PackedScene = preload("res://scenes/barrel.tscn")
@export var min_barrels: int = 3
@export var max_barrels: int = 6
@export var spawn_radius: float = 150.0

func _ready() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = Network.map_seed + int(global_position.x * 1000 + global_position.y)
	spawn_barrels(rng)

func spawn_barrels(rng: RandomNumberGenerator):
	var count = rng.randi_range(min_barrels, max_barrels)

	for i in range(count):
		var offset = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0, spawn_radius)
		var barrel = barrel_scene.instantiate()
		barrel.position = offset
		add_child(barrel)
