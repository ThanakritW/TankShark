extends Node2D

const SPAWN_POINTS = [
	Vector2(530, 308),
	Vector2(3200, 3200),
	Vector2(800, 5000),
	Vector2(5500, 800),
]

@onready var players_node = $Players

var spawned_peers: Dictionary = {}

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

	# Now spawn the new player on server + broadcast to ALL clients
	var spawn_index = Network.players.keys().find(sender) % SPAWN_POINTS.size()
	spawned_peers[sender] = true
	_spawn_player_local(sender, SPAWN_POINTS[spawn_index])
	_spawn_player_on_client.rpc(sender, SPAWN_POINTS[spawn_index])

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
	_sync_mine_explode.rpc(str(mine_path))

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
	_sync_barrel_die_rpc.rpc(str(barrel_path), orbs)

@rpc("authority", "call_local", "reliable")
func _sync_barrel_die_rpc(barrel_path_str: String, orbs: Array):
	var barrel = get_node_or_null(barrel_path_str)
	if barrel and barrel.has_method("die_and_spawn_orbs"):
		barrel.die_and_spawn_orbs(orbs)
