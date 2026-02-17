extends Control

@onready var address_input: LineEdit = $VBoxContainer/ConnectionRow/AddressInput
@onready var port_input: SpinBox = $VBoxContainer/ConnectionRow/PortInput
@onready var host_btn: Button = $VBoxContainer/ButtonRow/HostBtn
@onready var join_btn: Button = $VBoxContainer/ButtonRow/JoinBtn
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var player_list: VBoxContainer = $VBoxContainer/PlayerList
@onready var start_btn: Button = $VBoxContainer/StartBtn

func _ready():
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	Network.player_connected.connect(_on_player_connected)
	Network.player_disconnected.connect(_on_player_disconnected)
	Network.connection_failed.connect(_on_connection_failed)
	Network.server_started.connect(_on_server_started)
	start_btn.visible = false

func _on_host_pressed():
	var port = int(port_input.value)
	Network.host_game(port)
	status_label.text = "Hosting on port " + str(port) + "..."
	host_btn.disabled = true
	join_btn.disabled = true
	_update_player_list()

func _on_join_pressed():
	var address = address_input.text
	if address.is_empty():
		address = "127.0.0.1"
	var port = int(port_input.value)
	Network.join_game(address, port)
	status_label.text = "Connecting..."
	host_btn.disabled = true
	join_btn.disabled = true
	_wait_for_connection()

func _wait_for_connection():
	await get_tree().create_timer(2.0).timeout
	if multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() != 1:
		# Connected to dedicated server — show waiting status
		status_label.text = "Waiting for players..."
	elif not multiplayer.has_multiplayer_peer():
		# Connection was rejected (room full)
		status_label.text = "Room full! Game in progress."
		host_btn.disabled = false
		join_btn.disabled = false

func _on_start_pressed():
	Network.start_game.rpc(Network.map_seed)

func _on_server_started():
	status_label.text = "Hosting! Waiting for players..."
	start_btn.visible = true

func _on_player_connected(_id: int):
	status_label.text = str(Network.players.size()) + "/" + str(Network.REQUIRED_PLAYERS) + " players connected"
	_update_player_list()

func _on_player_disconnected(_id: int):
	status_label.text = str(Network.players.size()) + "/" + str(Network.REQUIRED_PLAYERS) + " players connected"
	_update_player_list()

func _on_connection_failed():
	status_label.text = "Connection failed!"
	host_btn.disabled = false
	join_btn.disabled = false

func _update_player_list():
	for child in player_list.get_children():
		child.queue_free()
	for peer_id in Network.players:
		var label = Label.new()
		label.text = Network.players[peer_id]["name"] + " (ID: " + str(peer_id) + ")"
		player_list.add_child(label)
