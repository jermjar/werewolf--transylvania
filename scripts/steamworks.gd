extends Node

const APP_ID: int = 480
const PACKET_READ_LIMIT: int = 32

var lobby_data
var lobby_id: int = 0
var lobby_members: Array = []
var lobby_members_max: int = 10
var lobby_vote_kick: bool = false

var steam_enabled: bool = false
var steam_id: int = 0
var steam_username: String = ""

func _ready() -> void:
	initialize_steam()

func initialize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx(APP_ID, true)
	print ("Did Steam initialize?: %s" % initialize_response)
	
	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, disabling Steam functionality: %s" % initialize_response)
		steam_enabled = false
		return
	else:
		steam_enabled = true
		
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.join_requested.connect(_on_lobby_join_requested)
		Steam.lobby_chat_update.connect(_on_lobby_chat_update)
		Steam.lobby_data_update.connect(_on_lobby_data_update)
		Steam.lobby_invite.connect(_on_lobby_invite)
		Steam.lobby_joined.connect(_on_lobby_joined)
		Steam.lobby_match_list.connect(_on_lobby_match_list)
		Steam.lobby_message.connect(_on_lobby_message)
		Steam.persona_state_change.connect(_on_persona_state_change)
		
		check_command_line()

func check_command_line() -> void:
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
				#join_lobby(int(arguments[1]))

func create_lobby() -> void:
	## Make sure a lobby is not already set
	if lobby_id == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, lobby_members_max)

func _on_lobby_created(connect: int, this_lobby_id: int) -> void:
	if connect == 1:
		## Set the lobby ID
		lobby_id = this_lobby_id
		print("Created a lobby: %s" % lobby_id)
		
		## Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, true)
		
		## Set some lobby data
		Steam.setLobbyData(lobby_id, "name", "OMBERX LOBBY")
		Steam.setLobbyData(lobby_id, "mode", "GodotSteam test")
		
		## Allow P2P connections to fallback to being relayed through Steam if needed
		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to be a relay backup: %s" % set_relay)

func _on_lobby_join_requested() -> void:
	pass

func _on_lobby_chat_update() -> void:
	pass

func _on_lobby_data_update() -> void:
	pass

func _on_lobby_invite() -> void:
	pass

func _on_lobby_joined() -> void:
	pass

func _on_lobby_match_list() -> void:
	pass

func _on_lobby_message() -> void:
	pass

func _on_persona_state_change() -> void:
	pass
