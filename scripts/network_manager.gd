extends Node

signal player_connected(peer_id)
signal player_disconnected(peer_id)
signal connection_failed()
signal server_started()

const DEFAULT_PORT = 9999
const MAX_PLAYERS = 4

var players: Dictionary = {}
var map_seed: int = 0
var is_dedicated_server: bool = false

func _ready():
	# Check for --server command line argument
	if "--server" in OS.get_cmdline_args() or "--server" in OS.get_cmdline_user_args():
		is_dedicated_server = true
		print("[Server] Starting dedicated server...")
		call_deferred("_start_dedicated_server")

func _start_dedicated_server():
	host_game()
	print("[Server] Listening on port " + str(DEFAULT_PORT))
	print("[Server] Waiting for players to connect...")
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
	players[id] = {"name": "Player " + str(id)}
	player_connected.emit(id)
	if is_dedicated_server:
		print("[Server] Player " + str(id) + " connected (" + str(players.size()) + " players)")
		# Send map seed to new player so they load the same map
		_send_seed_to_client.rpc_id(id, map_seed)

func _on_peer_disconnected(id: int):
	players.erase(id)
	player_disconnected.emit(id)
	if is_dedicated_server:
		print("[Server] Player " + str(id) + " disconnected (" + str(players.size()) + " players)")

func _on_connected_to_server():
	players[multiplayer.get_unique_id()] = {"name": "Me"}

func _on_connection_failed():
	connection_failed.emit()
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

@rpc("authority", "call_local", "reliable")
func start_game(seed_value: int):
	map_seed = seed_value
	get_tree().change_scene_to_file("res://scenes/world.tscn")

@rpc("authority", "reliable")
func _send_seed_to_client(seed_value: int):
	map_seed = seed_value
