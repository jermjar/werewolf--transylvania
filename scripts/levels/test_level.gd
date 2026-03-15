extends Node3D

@onready var player_scene = preload("res://scenes/player/player.tscn")
@onready var players: Node3D = $Players

# Not sure if this is needed, but I'm putting it here so I don't forget it exists
func _enter_tree() -> void:
	print("lobby_members: " + str(Networking.lobby_members))

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# I don't understand the purpose for this yet
	if not multiplayer.is_server(): 
		print("if not multiplayer.is_server()")
		return
	
	# for some reason an example used an await above this
	#await get_tree().create_timer(1.0).timeout
	for id in Networking.lobby_members:
		add_player(id, Networking.lobby_members[id])
	
	#await get_tree().process_frame
	game_loaded.rpc()

@rpc("call_local", "reliable")
func game_loaded() -> void:
	SceneManager.finished_loading.emit()

func add_player(id: int, steam_id: int) -> void:
	var _name = Steam.getFriendPersonaName(steam_id)
	var player_controller = player_scene.instantiate()
	player_controller.steam_id = steam_id
	player_controller.steam_name = _name
	player_controller.name = str(id)
	player_controller.set_multiplayer_authority(name.to_int())
	players.add_child(player_controller)
	print("add_player -> spawned: %s, %s" % [id, _name])

func _on_player_disconnected(id: int) -> void:
	rpc("delete_player", id)

@rpc("call_local", "reliable")
func delete_player(id: int):
	players.get_node(str(id)).queue_free()

func _on_server_disconnected() -> void:
	SceneManager.change_scene("uid://bvuq245igqp4l")
	Networking.reset_network()
