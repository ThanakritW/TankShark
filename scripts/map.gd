extends Node2D

@export var wall_scene : PackedScene = preload("res://scenes/wall.tscn")
@export var num_walls : int = 50
@export var map_size : Vector2 = Vector2(6400, 6400)
@export var player_safe_radius : float = 400.0

func _ready() -> void:
	spawn_random_walls()

func spawn_random_walls():
	var player_pos = Vector2(540, 272) # Default player start pos from world.tscn
	
	for i in range(num_walls):
		var pos = Vector2(
			randf_range(100, map_size.x - 100),
			randf_range(100, map_size.y - 100)
		)
		
		# Don't spawn walls on the player
		if pos.distance_to(player_pos) < player_safe_radius:
			continue
			
		var wall = wall_scene.instantiate()
		wall.position = pos
		# Random rotation and scale for variety
		wall.rotation = randf_range(0, PI)
		wall.scale = Vector2(randf_range(1, 3), randf_range(1, 3))
		add_child(wall)
