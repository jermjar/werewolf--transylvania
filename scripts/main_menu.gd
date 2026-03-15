extends CanvasLayer

# Main Menu references
@onready var main_menu_container: VBoxContainer = $MainMenuButtons
@onready var multiplayer_button: Button = %Multiplayer
@onready var options_button: Button = %Options
@onready var quit_button: Button = %Quit

# Join Lobby Container references
@onready var join_lobby_container: VBoxContainer = $JoinLobbyContainer
@onready var lobby_scroll_container: ScrollContainer = %Lobby_ScrollContainer
@onready var join_lobby_button: Button = %JoinLobby
@onready var create_lobby_button_join: Button = %CreateLobby_Join
@onready var refresh_button: Button = %Refresh
@onready var back_button_join: Button = %Back_Join

# Create Lobby Container references
@onready var create_lobby_container: VBoxContainer = $CreateLobbyContainer
@onready var create_lobby_name_label: Label = %CreateLobbyNameLabel
@onready var lobby_name_input: LineEdit = %LobbyNameInput
@onready var create_lobby_button_create: Button = %CreateLobby_Create
@onready var back_button_create: Button = %Back_Create

# Lobby Container references
@onready var lobby_container: VBoxContainer = $LobbyContainer
@onready var lobby_name_label: Label = %LobbyName
@onready var player_list_container: VBoxContainer = %PlayerList_VBoxContainer
@onready var lobby_chat_container: ScrollContainer = %LobbyChat_ScrollContainer
@onready var chat: RichTextLabel = %Chat
@onready var input: LineEdit = %Input
@onready var send_button: Button = %Send
@onready var leave_lobby_button: Button = %LeaveLobby
@onready var start_game_button: Button = %StartGame

# Scenes for displaying server list / players in a lobby
@onready var lobby_server = load("res://scenes/lobby/lobby_server.tscn")
@onready var lobby_player = load("res://scenes/lobby/lobby_player.tscn")

var join_id: int = 0

func _ready() -> void:
	## Main MenuSignals
	multiplayer_button.button_up.connect(_on_multiplayer_button_up)
	options_button.button_up.connect(_on_options_button_up)
	quit_button.button_up.connect(_on_quit_button_up)
	
	## Join Lobby Signals
	join_lobby_button.button_up.connect(_on_join_lobby_button_up)
	create_lobby_button_join.button_up.connect(_on_create_lobby_button_up.bind(0))
	refresh_button.button_up.connect(_on_refresh_button_up)
	back_button_join.button_up.connect(_on_back_button_up.bind(0))
	
	## Create Lobby Signals
	lobby_name_input.text_changed.connect(_on_lobby_name_text_changed)
	create_lobby_button_create.button_up.connect(_on_create_lobby_button_up.bind(1))
	back_button_create.button_up.connect(_on_back_button_up.bind(1))
	
	## Lobby Signals
	input.text_submitted.connect(_on_send_chat)
	send_button.button_up.connect(_on_send_chat)
	leave_lobby_button.button_up.connect(_on_leave_lobby_button_up)
	start_game_button.button_up.connect(_on_start_game_button_up)
	
	## Steam Signals
	Steam.lobby_match_list.connect(_update_lobbies)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_message.connect(_on_lobby_message)
	
	# Don't think I need this... yet at least
	#Steam.persona_state_change.connect(_on_persona_state_change)
	
	## Networking Signals
	Networking.player_list_changed.connect(_on_player_list_changed)
	Networking.connection_success.connect(_on_connection_success)
	Networking.connection_failed.connect(_on_connection_failed)
	
	_check_command_line()

#func _on_persona_state_change(this_steam_id: int, _flag: int) -> void:
	## Make sure you're in a lobby and this user is valid or Steam might spam your console log
	#if lobby_id > 0:
		#print("A user (%s) had information change, update the lobby list" % this_steam_id)
		#get_lobby_members()

#region JOIN LOBBY BROWSER
func _refresh_lobbies() -> void:
	for this_lobby in lobby_scroll_container.get_child(0).get_children():
		this_lobby.queue_free()
	
	# Set filters
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.addRequestLobbyListStringFilter("unique_lobby_id", Networking.UNIQUE_LOBBY_ID, Steam.LobbyComparison.LOBBY_COMPARISON_EQUAL)
	
	# Triggers _update_lobbies()
	Steam.requestLobbyList()

func _update_lobbies(these_lobbies: Array) -> void:
	for this_lobby in these_lobbies:
		# Pull lobby data from Steam
		var _name: String = Steam.getLobbyData(this_lobby, "name")
		var mode: String = Steam.getLobbyData(this_lobby, "mode")
		var num_of_members: int = Steam.getNumLobbyMembers(this_lobby)
		var lobby_server = lobby_server.instantiate()
		
		lobby_server.get_node("Button").pressed.connect(
			_on_lobby_selected.bind(this_lobby)
		)
		lobby_server.get_node("Button").set_text(_name)
		lobby_server.get_node("Label").set_text("%s/%s" % [num_of_members, SteamInit.LOBBY_MEMBERS_MAX])
		
		lobby_scroll_container.get_child(0).add_child(lobby_server)

func _on_lobby_selected(_this_lobby_id: int) -> void:
	join_id = _this_lobby_id
#endregion

#region MAIN MENU BUTTONS
func _on_multiplayer_button_up() -> void:
	main_menu_container.visible = false
	join_lobby_container.visible = true
	_refresh_lobbies()

func _on_options_button_up() -> void:
	pass

func _on_quit_button_up() -> void:
	get_tree().quit()
#endregion

#region LOBBY BUTTONS
func _on_join_lobby_button_up() -> void:
	Networking.join_lobby(join_id)

# There are two create lobby buttons, so I'm binding an ID to
# them so I don't have to use two separate functions
func _on_create_lobby_button_up(button_id: int) -> void:
	match button_id:
		0:
			join_lobby_container.visible = false
			create_lobby_container.visible = true
		1:
			Networking.create_lobby()
			lobby_name_label.text = Networking.lobby_name
			create_lobby_container.visible = false
			lobby_container.visible = true

func _on_refresh_button_up() -> void:
	_refresh_lobbies()

# There are two back buttons, so I'm binding an ID to them
# so I don't have to use two separate functions
func _on_back_button_up(button_id: int) -> void:
	match button_id:
		0:
			join_lobby_container.visible = false
			main_menu_container.visible = true
		1:
			lobby_name_input.clear()
			create_lobby_container.visible = false
			join_lobby_container.visible = true

# NOTE - This is an RPC so Host can kick others
@rpc("call_local", "reliable")
func _on_leave_lobby_button_up() -> void:
	Networking.reset_network()
	for player in player_list_container.get_children():
		player.queue_free()
	lobby_container.visible = false
	join_lobby_container.visible = true
	chat.clear()
	_refresh_lobbies()

func _on_start_game_button_up() -> void:
	Networking.start_game()

func _on_kick_button_pressed(id: int) -> void:
	_on_leave_lobby_button_up.rpc_id(id)

func _on_ready_button_pressed():
	_on_ready_pressed.rpc()

@rpc("any_peer", "call_local", "reliable")
func _on_ready_pressed() -> void:
	var id = multiplayer.get_remote_sender_id()
	var ready_button = player_list_container.get_node("%s/Ready" % str(id))
	if Networking.lobby_members_ready.has(id):
		Networking.lobby_members_ready.erase(id)
		ready_button.text = "Ready"
	else:
		Networking.lobby_members_ready.append(id)
		ready_button.text = "Unready"
	
	var start_game = multiplayer.is_server() and Networking.lobby_members_ready.size() == Steam.getNumLobbyMembers(Networking.lobby_id)
	start_game_button.disabled = !start_game

#endregion

#region LOBBY FUNCTIONALITY
## `await get_tree().process_frame` is there because of a race condition for the host.
## Without them, it will add another host before removing the old one fully, making the name
## of the new host "2", which breaks functionality for things like readying up
@rpc("call_local", "reliable")
func _update_lobby_player_list(players) -> void:
	await get_tree().process_frame
	Networking.lobby_members_ready = []
	for player in player_list_container.get_children():
		player.queue_free()
	
	for player in players:
		await get_tree().process_frame
		var steam_id: int = players[player]
		var steam_name: String = Steam.getFriendPersonaName(steam_id)
		var player_scene = lobby_player.instantiate()
		
		player_scene.name = str(player)
		player_scene.get_node("Label").text = steam_name
		player_scene.get_node("Kick").button_up.connect(_on_kick_button_pressed.bind(player))
		player_scene.get_node("Ready").button_up.connect(_on_ready_button_pressed)
		player_list_container.add_child(player_scene, true)
		if SteamInit.steam_id != steam_id:
			player_scene.get_node("Ready").disabled = true
		if SteamInit.steam_id == Steam.getLobbyOwner(Networking.lobby_id):
			player_scene.get_node("Kick").show()
		print("_update_lobby_player_list: ", str(player), " lobby_members: ", Networking.lobby_members)

func _on_send_chat(message: String = "") -> void:
	if message.length() == 0:
		message = input.get_text()
	if message.length() > 0:
		var is_sent: bool = Steam.sendLobbyChatMsg(Networking.lobby_id, message)
		if not is_sent:
			print("Failed to send message")
		input.clear()

func _on_lobby_chat_update(this_lobby_id: int, change_id: int, making_change_id: int, chat_state: int) -> void:
	# Get the user who has made the lobby change
	var changer_name: String = Steam.getFriendPersonaName(change_id)

	# If a player has joined the lobby
	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		print("%s has joined the lobby." % changer_name)

	# Else if a player has left the lobby
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		print("%s has left the lobby." % changer_name)

	# Else if a player has been kicked
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_KICKED:
		print("%s has been kicked from the lobby." % changer_name)

	# Else if a player has been banned
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_BANNED:
		print("%s has been banned from the lobby." % changer_name)

	# Else there was some unknown change
	else:
		print("%s did... something." % changer_name)

func _on_lobby_message(this_lobby_id: int, user: int, message: String, chat_type: int) -> void:
	var sender = Steam.getFriendPersonaName(user)
	if chat_type == 1:
		chat.append_text(str(sender) + ":  " + str(message) + "\n")
	else:
		match chat_type:
			2: print(str(sender)+" is typing...\n")
			3: print(str(sender)+" sent an invite that won't work in this chat!\n")
			4: print(str(sender)+" sent a text emote that is deprecated.\n")
			6: print(str(sender)+" has left the chat.\n")
			7: print(str(sender)+" has entered the chat.\n")
			8: print(str(sender)+" was kicked!\n")
			9: print(str(sender)+" was banned!\n")
			10: print(str(sender)+" disconnected.\n")
			11: print(str(sender)+" sent an old, offline message.\n")
			12: print(str(sender)+" sent a link that was removed by the chat filter.\n")

# Triggers whenever you type in the Create Lobby text field
func _on_lobby_name_text_changed(text):
	if text:
		Networking.lobby_name = text
		create_lobby_name_label.text = text
	else:
		Networking.lobby_name = "Lobby Name"
		create_lobby_name_label.text = "Lobby Name"

#endregion

#region NETWORKING SIGNALS
# Host sends out RPC to everyone (including host) to update the player list
func _on_player_list_changed() -> void:
	if multiplayer.is_server():
		print("_on_player_list_changed")
		_update_lobby_player_list.rpc(Networking.lobby_members)

func _on_connection_success() -> void:
	lobby_name_label.text = Steam.getLobbyData(Networking.lobby_id, "name")
	join_lobby_container.visible = false
	lobby_container.visible = true
	print("Connection Success!")

func _on_connection_failed() -> void:
	Networking.reset_network()
	create_lobby_container.visible = false
	lobby_container.visible = false
	main_menu_container.visible = false
	join_lobby_container.visible = true
	print("Connection Failed!")
	
#endregion

## Handles joining off of Steam invite/friends list allegedly
func _check_command_line() -> void:
	var arguments: Array = OS.get_cmdline_args()
	
	## Arguments to process
	if arguments.size() > 0:
		## Steam connection argument exists
		if arguments[0] == "+connect_lobby":
			## Lobby invite exists so try to connect to it
			if int(arguments[1]) > 0:
				## At this point, you'll probably want to change scenes
				## Something like a loading into lobby screen
				print("Command line lobby ID: %s" % arguments[1])
				Networking.join_lobby(int(arguments[1]))
