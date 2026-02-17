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

func _ready():
	if multiplayer.is_server():
		# Non-dedicated host: spawn self
		if not Network.is_dedicated_server:
			_spawn_player_local(1, SPAWN_POINTS[0])
			spawned_peers[1] = true
		Network.player_disconnected.connect(remove_player)
	else:
		# Client just loaded world — tell server we're ready
		_client_ready.rpc_id(1)

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

	# Now spawn the new player on server + broadcast to ALL clients
	var spawn_index = Network.players.keys().find(sender) % SPAWN_POINTS.size()
	spawned_peers[sender] = true
	_spawn_player_local(sender, SPAWN_POINTS[spawn_index])
	_spawn_player_on_client.rpc(sender, SPAWN_POINTS[spawn_index])

@rpc("authority", "reliable")
func _sync_destroyed_objects(barrel_paths: Array, mine_paths: Array):
	# Remove all destroyed barrels and mines that were destroyed before we joined
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
	# Skip if already exists
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
	# Tell all clients to remove this player
	_remove_player_on_client.rpc(peer_id)

@rpc("authority", "reliable")
func _remove_player_on_client(peer_id: int):
	var player_node = players_node.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()

# --- Sync for map objects (not managed by MultiplayerSpawner, so RPCs on them don't work) ---

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
