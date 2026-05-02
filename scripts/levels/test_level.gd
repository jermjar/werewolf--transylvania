extends Node3D

@onready var player_scene = preload("res://scenes/player/player.tscn")
@onready var players: Node3D = $Players
@onready var game_menu: Control = $UI/GameMenu

# Not sure if this is needed, but I'm putting it here so I don't forget it exists
func _enter_tree() -> void:
	print("lobby_members: " + str(Networking.lobby_members))
	get_tree().paused = true

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# HACK - I don't like having the code here
	# Connect GameMenu buttons
	game_menu.leave_game_button.button_up.connect(_on_server_disconnected)
	
	# for some reason an example used an await above this
	await get_tree().create_timer(1.0).timeout
	
	if multiplayer.is_server():
		for id in Networking.lobby_members:
			add_player.rpc(id, Networking.lobby_members[id])
		await get_tree().process_frame
		game_loaded.rpc()

# HACK - I don't like having the code here
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if game_menu.visible:
			game_menu.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif !game_menu.visible:
			game_menu.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

@rpc("call_local", "reliable")
func game_loaded() -> void:
	SceneManager.finished_loading.emit()
	get_tree().paused = false

func _on_player_disconnected(id: int) -> void:
	rpc("delete_player", id)

@rpc("call_local", "reliable")
func add_player(id: int, steam_id: int) -> void:
	var _name = Steam.getFriendPersonaName(steam_id)
	var player_controller = player_scene.instantiate()
	player_controller.steam_id = steam_id
	player_controller.steam_name = _name
	player_controller.name = str(id)
	players.add_child(player_controller)
	print("add_player -> spawned: %s, %s" % [id, _name])

@rpc("call_local", "reliable")
func delete_player(id: int):
	players.get_node(str(id)).queue_free()

func _on_server_disconnected() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SceneManager.change_scene("uid://dlgk7ywyn41us")
	Networking.reset_network()
