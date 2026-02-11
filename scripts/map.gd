extends Node2D

@export var wall_scene : PackedScene = preload("res://scenes/wall.tscn")
@export var num_walls : int = 125
@export var map_size : Vector2 = Vector2(6400, 6400)
@export var player_safe_radius : float = 400.0

const HOUSE_HALF_WIDTH = 700.0  # 640 + walls + buffer
const HOUSE_HALF_HEIGHT = 380.0 # 320 + walls + buffer

func _ready() -> void:
	spawn_random_walls()

func spawn_random_walls():
	var player_pos = _get_player_pos()
	var houses = _find_houses()
	
	var walls_spawned = 0
	var max_attempts = num_walls * 20
	var attempts = 0
	
	while walls_spawned < num_walls and attempts < max_attempts:
		attempts += 1
		
		# Generate random position
		var pos = Vector2(
			randf_range(100, map_size.x - 100),
			randf_range(100, map_size.y - 100)
		)
		
		# Random wall scale (used for collision size estimation)
		var long_side = randf_range(3.0, 6.0)   # Make this number big for length
		var short_side = randf_range(0.5, 1.0)  # Make this number small for thickness
		var wall_scale = Vector2(long_side, short_side)
		var wall_size_radius = 50.0 * max(wall_scale.x, wall_scale.y)
		
		if _is_valid_spawn(pos, wall_size_radius, player_pos, houses):
			_spawn_wall(pos, wall_scale)
			walls_spawned += 1

func _get_player_pos() -> Vector2:
	var player = get_node_or_null("../player")
	if player:
		return player.global_position
	return Vector2(540, 272)

func _find_houses() -> Array:
	var houses = []
	var check_nodes = get_children()
	# Check siblings in case houses are in the world scene, not map scene
	if get_parent():
		check_nodes.append_array(get_parent().get_children())
		
	for node in check_nodes:
		if node == self: continue
		# Identify houses by name or content
		if "House" in node.name or node.has_node("Floor"):
			houses.append(node)
	return houses

func _is_valid_spawn(pos: Vector2, wall_radius_buffer: float, player_pos: Vector2, houses: Array) -> bool:
	# 1. Player Distance Check
	if pos.distance_to(player_pos) < (player_safe_radius + wall_radius_buffer):
		return false
	
	# 2. House Collision Check
	for house in houses:
		var h_scale = max(house.scale.x, house.scale.y)
		
		# Quick Radius Check (Optimization)
		var quick_radius = 1000.0 * h_scale
		if pos.distance_to(house.global_position) > (quick_radius + wall_radius_buffer):
			continue # Far away, definitely safe
			
		# Detailed Box Check
		# Transform world position 'pos' into house's local space
		var local_pos = house.to_local(pos)
		
		var buffer = wall_radius_buffer / h_scale 
		
		# House Body Bounds
		var house_rect = Rect2(
			-HOUSE_HALF_WIDTH - buffer, 
			-HOUSE_HALF_HEIGHT - buffer, 
			(HOUSE_HALF_WIDTH * 2) + (buffer * 2), 
			(HOUSE_HALF_HEIGHT * 2) + (buffer * 2)
		)
		
		if house_rect.has_point(local_pos):
			return false
			
	return true

func _spawn_wall(pos: Vector2, wall_scale: Vector2):
	var wall = wall_scene.instantiate()
	wall.position = pos
	wall.rotation = randf_range(0, PI)
	wall.scale = wall_scale
	add_child(wall)

