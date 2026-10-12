extends Node3D

@onready var player_scene = preload("res://scenes/player/player.tscn")
@onready var players: Node3D = $Players
@onready var spawn_points: Node3D = $SpawnPoints
@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var item_spawner: ItemSpawner = $ItemSpawner
@onready var round_manager: RoundManager = $RoundManager
@onready var game_menu: Control = $UI/GameMenu

# Everyone stays paused until the host has spawned all players and calls
# game_loaded(), so nobody can move before the round starts
func _enter_tree() -> void:
	Log.debug("lobby_members: " + str(Networking.lobby_members))
	get_tree().paused = true

func _ready() -> void:
	Log.debug("TestLevel._ready()")
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Leaving the game goes back to the main menu, the same as losing the host
	game_menu.leave_game_button.button_up.connect(_on_server_disconnected)
	
	# Must be set on every peer before the host spawns anyone,
	# which is why it happens before reporting that we're loaded
	player_spawner.spawn_function = _spawn_player

	if multiplayer.is_server():
		Networking.all_peers_loaded.connect(_on_all_peers_loaded, CONNECT_ONE_SHOT)
	Networking.report_level_loaded()

# Host only - runs once every peer has finished loading the level
func _on_all_peers_loaded() -> void:
	Log.debug("TestLevel._on_all_peers_loaded()")
	var spawn_index: int = 0
	for id in Networking.lobby_members:
		# Wraps around if there are more players than spawn points
		var spawn_point: Marker3D = spawn_points.get_child(spawn_index % spawn_points.get_child_count())
		player_spawner.spawn({
			"id": id,
			"position": spawn_point.global_position,
		})
		spawn_index += 1

	item_spawner.spawn_level_items()

	game_loaded.rpc()
	round_manager.start_round()

@rpc("call_local", "reliable")
func game_loaded() -> void:
	Log.debug("TestLevel.game_loaded()")
	SceneManager.finished_loading.emit()

	# Props placed in the level (like the cube) start hidden from the network,
	# because the host would otherwise start syncing them before slower clients
	# finish loading. Godot only introduces a synced node to each client once, so a
	# client that missed it would never see that prop move. Everyone has the level now.
	for synchronizer in find_children("*", "MultiplayerSynchronizer", true, false):
		synchronizer.public_visibility = true

	get_tree().paused = false

# Runs on every peer. When the host calls player_spawner.spawn(data), the
# spawner runs this with the same data on everyone, then adds the returned
# player under Players. Don't add_child() it here, the spawner does that.
func _spawn_player(data: Dictionary) -> Node:
	var player_controller = player_scene.instantiate()
	player_controller.name = str(data.id)
	player_controller.position = data.position
	Log.debug("_spawn_player -> spawned: %s" % data.id)
	return player_controller

# Host only - removing a spawned player on the host removes it for everyone
func _on_player_disconnected(id: int) -> void:
	Log.debug("TestLevel._on_player_disconnected()")
	if not multiplayer.is_server(): return
	if players.has_node(str(id)):
		players.get_node(str(id)).queue_free()

func _on_server_disconnected() -> void:
	Log.debug("TestLevel._on_server_disconnected()")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SceneManager.change_scene("uid://dlgk7ywyn41us")
	Networking.reset_network()
