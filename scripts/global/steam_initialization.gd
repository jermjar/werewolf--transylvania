extends Node

const APP_ID: int = 480
const LOBBY_MEMBERS_MAX: int = 8

var steam_enabled: bool = false
var steam_id: int = 0
var steam_username: String
var is_online: bool = false
var is_game_owned: bool = false

func _init() -> void:
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))

func _ready() -> void:
	_initialize_steam()

func _process(_delta: float) -> void:
	if steam_enabled:
		Steam.run_callbacks()

func _initialize_steam() -> void:
	if !Engine.has_singleton("Steam"): get_tree().quit()
	
	var initialize_response: Dictionary = Steam.steamInitEx(APP_ID)
	print ("Did Steam initialize?: %s" % initialize_response)
	
	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, disabling Steam functionality: %s" % initialize_response)
		steam_enabled = false
		get_tree().quit()

	steam_enabled = true
	is_online = Steam.loggedOn()
	is_game_owned = Steam.isSubscribed()
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()
	
	if !is_game_owned:
		print("User does not own this game")
