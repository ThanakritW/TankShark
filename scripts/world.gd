extends Node2D

const SPAWN_POINTS = [
	Vector2(530, 308),
	Vector2(3200, 3200),
	Vector2(800, 5000),
	Vector2(5500, 800),
]

@onready var players_node = $Players

var spawned_peers: Dictionary = {}
var destroyed_barrels: Array = []
var destroyed_mines: Array = []

# --- Battle Royale ---
var game_over: bool = false

# --- Shrinking Zone ---
const MAP_CENTER = Vector2(3200, 3200)
const ZONE_START_RADIUS = 5000.0
const ZONE_MIN_RADIUS = 100.0
const ZONE_SHRINK_AMOUNT = 150.0
const ZONE_SHRINK_INTERVAL = 3.0
const ZONE_DAMAGE = 2
const ZONE_DAMAGE_INTERVAL = 1.0

var zone_radius: float = ZONE_START_RADIUS
var zone_shrink_timer: float = ZONE_SHRINK_INTERVAL
var zone_damage_timer: float = ZONE_DAMAGE_INTERVAL

func _ready():
	if multiplayer.is_server():
		if not Network.is_dedicated_server:
			_spawn_player_local(1, SPAWN_POINTS[0])
			spawned_peers[1] = true
		Network.player_disconnected.connect(remove_player)
	else:
		# Client just loaded world — tell server we're ready
		_client_ready.rpc_id(1)

func _process(delta):
	# Shrinking zone logic (server-authoritative)
	if multiplayer.is_server() and not game_over:
		# Shrink the zone
		zone_shrink_timer -= delta
		if zone_shrink_timer <= 0:
			zone_shrink_timer = ZONE_SHRINK_INTERVAL
			zone_radius = max(zone_radius - ZONE_SHRINK_AMOUNT, ZONE_MIN_RADIUS)
			_sync_zone_radius.rpc(zone_radius)

		# Damage players outside the zone
		zone_damage_timer -= delta
		if zone_damage_timer <= 0:
			zone_damage_timer = ZONE_DAMAGE_INTERVAL
			_apply_zone_damage()

	# Redraw zone circle every frame
	queue_redraw()

func _draw():
	# Fill area OUTSIDE the safe zone with transparent red using a thick arc
	var fill_thickness = 10000.0
	var fill_radius = zone_radius + fill_thickness / 2.0
	draw_arc(MAP_CENTER, fill_radius, 0, TAU, 128, Color(1, 0, 0, 0.25), fill_thickness)

	# Draw the safe zone border
	var border_width = 8.0
	draw_arc(MAP_CENTER, zone_radius + 20, 0, TAU, 128, Color(1, 0, 0, 0.15), 40.0)
	draw_arc(MAP_CENTER, zone_radius + 5, 0, TAU, 128, Color(1, 0, 0, 0.3), 10.0)
	draw_arc(MAP_CENTER, zone_radius, 0, TAU, 128, Color(1, 0, 0, 0.8), border_width)

func _apply_zone_damage():
	for player_node in players_node.get_children():
		if player_node is CharacterBody2D and player_node.has_method("take_damage"):
			if player_node.is_dead:
				continue
			var dist = player_node.global_position.distance_to(MAP_CENTER)
			if dist > zone_radius:
				player_node.take_damage(ZONE_DAMAGE)

func _check_winner():
	if game_over: return
	var alive_players = []
	for player_node in players_node.get_children():
		if player_node is CharacterBody2D and not player_node.is_dead:
			alive_players.append(player_node)

	if alive_players.size() <= 1 and spawned_peers.size() >= 2:
		game_over = true
		if alive_players.size() == 1:
			var winner = alive_players[0]
			var winner_id = str(winner.name).to_int()
			_sync_game_end.rpc(winner_id)
		else:
			# Everyone dead — no winner
			_sync_game_end.rpc(-1)

		# Reset server after delay
		get_tree().create_timer(8.0).timeout.connect(func():
			Network.reset_for_new_game()
		)

@rpc("authority", "call_local", "reliable")
func _sync_zone_radius(radius: float):
	zone_radius = radius

@rpc("authority", "call_local", "reliable")
func _sync_game_end(winner_peer_id: int):
	game_over = true
	var game_over_layer = get_node_or_null("GameOverLayer")
	if not game_over_layer: return
	game_over_layer.visible = true
	var label = game_over_layer.get_node_or_null("Overlay/VBox/GameOverLabel")
	var return_btn = game_over_layer.get_node_or_null("Overlay/VBox/ReturnBtn")
	var my_id = multiplayer.get_unique_id()
	if winner_peer_id == my_id:
		if label: label.text = "VICTORY!"
	elif winner_peer_id == -1:
		if label: label.text = "DRAW!"
	else:
		if label: label.text = "GAME OVER"
	if return_btn:
		if not return_btn.is_connected("pressed", _on_return_pressed):
			return_btn.pressed.connect(_on_return_pressed)

func _on_return_pressed():
	multiplayer.multiplayer_peer = null
	Network.players.clear()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

# --- Player Spawning ---
@rpc("any_peer", "reliable")
func _client_ready():
	var sender = multiplayer.get_remote_sender_id()
	if not Network.players.has(sender): return

	# Tell the new client about ALL existing players first
	for peer_id in spawned_peers:
		var spawn_index = Network.players.keys().find(peer_id) % SPAWN_POINTS.size()
		_spawn_player_on_client.rpc_id(sender, peer_id, SPAWN_POINTS[spawn_index])

	# Sync destroyed barrels and mines to the new client
	_sync_destroyed_objects.rpc_id(sender, destroyed_barrels, destroyed_mines)

	# Sync current zone radius
	_sync_zone_radius.rpc_id(sender, zone_radius)

	# Now spawn the new player on server + broadcast to ALL clients
	var spawn_index = Network.players.keys().find(sender) % SPAWN_POINTS.size()
	spawned_peers[sender] = true
	_spawn_player_local(sender, SPAWN_POINTS[spawn_index])
	_spawn_player_on_client.rpc(sender, SPAWN_POINTS[spawn_index])

@rpc("authority", "reliable")
func _sync_destroyed_objects(barrel_paths: Array, mine_paths: Array):
	for path_str in barrel_paths:
		var barrel = get_node_or_null(path_str)
		if barrel:
			barrel.queue_free()
	for path_str in mine_paths:
		var mine = get_node_or_null(path_str)
		if mine:
			mine.queue_free()

@rpc("authority", "reliable")
func _spawn_player_on_client(peer_id: int, pos: Vector2):
	if players_node.has_node(str(peer_id)):
		return
	_spawn_player_local(peer_id, pos)

func _spawn_player_local(peer_id: int, pos: Vector2):
	var player_scene = preload("res://scenes/player.tscn")
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.position = pos
	players_node.add_child(player)

func remove_player(peer_id: int):
	spawned_peers.erase(peer_id)
	var player_node = players_node.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()
	# Only RPC if we still have connected peers and are inside the tree
	if is_inside_tree() and multiplayer.has_multiplayer_peer():
		var peers = multiplayer.get_peers()
		if peers.size() > 0:
			_remove_player_on_client.rpc(peer_id)
	# Check win condition after disconnect
	if not game_over:
		call_deferred("_check_winner")

@rpc("authority", "reliable")
func _remove_player_on_client(peer_id: int):
	var player_node = players_node.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()

# --- Sync for map objects ---

func explode_mine_at_path(mine_path: NodePath):
	var path_str = str(mine_path)
	destroyed_mines.append(path_str)
	_sync_mine_explode.rpc(path_str)

@rpc("authority", "call_local", "reliable")
func _sync_mine_explode(mine_path_str: String):
	var mine = get_node_or_null(mine_path_str)
	if mine and mine.has_method("_do_explode"):
		mine._do_explode()

func sync_barrel_damage(barrel_path: NodePath, hp: int):
	_sync_barrel_damage_rpc.rpc(str(barrel_path), hp)

@rpc("authority", "call_local", "reliable")
func _sync_barrel_damage_rpc(barrel_path_str: String, hp: int):
	var barrel = get_node_or_null(barrel_path_str)
	if barrel and barrel.has_method("apply_damage_visual"):
		barrel.apply_damage_visual(hp)

func sync_barrel_die(barrel_path: NodePath, orbs: Array):
	var path_str = str(barrel_path)
	destroyed_barrels.append(path_str)
	_sync_barrel_die_rpc.rpc(path_str, orbs)

@rpc("authority", "call_local", "reliable")
func _sync_barrel_die_rpc(barrel_path_str: String, orbs: Array):
	var barrel = get_node_or_null(barrel_path_str)
	if barrel and barrel.has_method("die_and_spawn_orbs"):
		barrel.die_and_spawn_orbs(orbs)

func sync_remove_orb(orb_path: NodePath):
	_sync_remove_orb_rpc.rpc(str(orb_path))

@rpc("authority", "call_local", "reliable")
func _sync_remove_orb_rpc(orb_path_str: String):
	var orb = get_node_or_null(orb_path_str)
	if orb:
		orb.queue_free()

# --- Player Bomb Sync ---
var player_bomb_scene = preload("res://scenes/player_bomb.tscn")

func sync_throw_player_bomb(bomb_name: String, pos: Vector2, dir: Vector2, peer_id: int):
	_sync_throw_bomb_rpc.rpc(bomb_name, pos, dir, peer_id)

@rpc("authority", "call_local", "reliable")
func _sync_throw_bomb_rpc(bomb_name: String, pos: Vector2, dir: Vector2, peer_id: int):
	var bomb = player_bomb_scene.instantiate()
	bomb.name = bomb_name
	bomb.global_position = pos
	bomb.direction = dir.normalized()
	bomb.owner_peer_id = peer_id
	add_child(bomb)

func sync_player_bomb_explode(bomb_path: NodePath):
	_sync_bomb_explode_rpc.rpc(str(bomb_path))

@rpc("authority", "call_local", "reliable")
func _sync_bomb_explode_rpc(bomb_path_str: String):
	var bomb = get_node_or_null(bomb_path_str)
	if bomb and bomb.has_method("_do_explode"):
		bomb._do_explode()

func sync_wall_destroy(wall_path: NodePath):
	_sync_wall_destroy_rpc.rpc(str(wall_path))

@rpc("authority", "call_local", "reliable")
func _sync_wall_destroy_rpc(wall_path_str: String):
	var wall = get_node_or_null(wall_path_str)
	if wall:
		wall.queue_free()
