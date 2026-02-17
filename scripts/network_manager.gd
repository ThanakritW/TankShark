extends Node

signal player_connected(peer_id)
signal player_disconnected(peer_id)
signal connection_failed()
signal server_started()
signal game_started()

const DEFAULT_PORT = 9999
const MAX_PLAYERS = 3
const REQUIRED_PLAYERS = 3

var players: Dictionary = {}
var map_seed: int = 0
var is_dedicated_server: bool = false
var game_in_progress: bool = false

func _ready():
	# Check for --server command line argument
	if "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args():
		is_dedicated_server = true
		print("[Server] Starting dedicated server...")
		call_deferred("_start_dedicated_server")

func _start_dedicated_server():
	host_game()
	print("[Server] Listening on port " + str(DEFAULT_PORT))
	print("[Server] Waiting for " + str(REQUIRED_PLAYERS) + " players to connect...")
	# Skip lobby, go straight to game world
	map_seed = randi()
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func host_game(port: int = DEFAULT_PORT):
	var peer = WebSocketMultiplayerPeer.new()
	var err = peer.create_server(port)
	if err != OK:
		push_error("Failed to create server: " + str(err))
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not is_dedicated_server:
		players[1] = {"name": "Host"}
	map_seed = randi()
	server_started.emit()

func join_game(address: String, port: int = DEFAULT_PORT):
	var peer = WebSocketMultiplayerPeer.new()
	var err = peer.create_client("ws://" + address + ":" + str(port))
	if err != OK:
		push_error("Failed to connect: " + str(err))
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int):
	if game_in_progress:
		# Room is full / game already started — kick the new player
		if is_dedicated_server:
			print("[Server] Rejecting player " + str(id) + " — game in progress")
		_notify_room_full.rpc_id(id)
		# Disconnect them after a short delay so the RPC arrives
		get_tree().create_timer(0.5).timeout.connect(func(): multiplayer.multiplayer_peer.disconnect_peer(id))
		return

	players[id] = {"name": "Player " + str(id)}
	player_connected.emit(id)
	if is_dedicated_server:
		print("[Server] Player " + str(id) + " connected (" + str(players.size()) + "/" + str(REQUIRED_PLAYERS) + ")")
		_send_seed_to_client.rpc_id(id, map_seed)
		# Send waiting status to all clients
		_sync_waiting_status.rpc(players.size(), REQUIRED_PLAYERS)
		# Check if we have enough players to start
		if players.size() >= REQUIRED_PLAYERS:
			_begin_game()

func _begin_game():
	game_in_progress = true
	if is_dedicated_server:
		print("[Server] " + str(REQUIRED_PLAYERS) + " players connected! Starting game...")
	_notify_game_start.rpc()
	game_started.emit()

var _resetting: bool = false

func _on_peer_disconnected(id: int):
	players.erase(id)
	player_disconnected.emit(id)
	if is_dedicated_server:
		print("[Server] Player " + str(id) + " disconnected (" + str(players.size()) + " players)")
		# Reset game state when all players leave
		if players.size() == 0 and not _resetting:
			print("[Server] All players left, resetting game state...")
			_resetting = true
			game_in_progress = false
			map_seed = randi()
			# Wait a frame so all disconnect signals finish before reloading
			get_tree().create_timer(0.1).timeout.connect(func():
				_resetting = false
				get_tree().reload_current_scene()
			)

func _on_connected_to_server():
	players[multiplayer.get_unique_id()] = {"name": "Me"}

func _on_connection_failed():
	connection_failed.emit()
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func reset_for_new_game():
	game_in_progress = false
	if is_dedicated_server:
		print("[Server] Game ended, resetting for new game...")
		map_seed = randi()
		# Disconnect all remaining players so they go back to lobby
		var peer_ids = players.keys()
		players.clear()
		for peer_id in peer_ids:
			if multiplayer.has_multiplayer_peer():
				multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		get_tree().call_deferred("reload_current_scene")

@rpc("authority", "call_local", "reliable")
func start_game(seed_value: int):
	map_seed = seed_value
	get_tree().change_scene_to_file("res://scenes/world.tscn")

@rpc("authority", "reliable")
func _send_seed_to_client(seed_value: int):
	map_seed = seed_value

@rpc("authority", "reliable")
func _sync_waiting_status(current_count: int, required: int):
	# Clients receive this to update their waiting UI
	pass  # Handled by lobby.gd listening to this

@rpc("authority", "reliable")
func _notify_game_start():
	# Clients receive this to know the game is starting
	get_tree().change_scene_to_file("res://scenes/world.tscn")

@rpc("authority", "reliable")
func _notify_room_full():
	# Client receives this when trying to join a full/active game
	multiplayer.multiplayer_peer = null
	players.clear()
