extends Node

signal player_list_changed()
signal connection_failed()
signal connection_success()
signal all_peers_loaded()

# NOTE - Use this to filter out other lobbies under the 480 App ID
#        Change this number for your game during testing!
const UNIQUE_LOBBY_ID: String = "54832791483712409738190"
const DEFAULT_PORT: int = 8080

enum MultiplayerBackend { 
	ENET, 
	STEAM 
}
enum LobbyType {
	PRIVATE = Steam.LOBBY_TYPE_PRIVATE,
	FRIENDS_ONLY = Steam.LOBBY_TYPE_FRIENDS_ONLY,
	PUBLIC = Steam.LOBBY_TYPE_PUBLIC
}

# NOTE - Change this depending on whether or not you want to test locally
#        Also customize run instances under Debug at the top, and add "server"
#        feature to the first run instance.
var backend: MultiplayerBackend = MultiplayerBackend.ENET
var lobby_id: int = 0
var lobby_type: int = LobbyType.PUBLIC
var lobby_name: String = "Lobby Name"
var lobby_members := {}
var lobby_members_ready := []
# Host only - peers that have finished loading the level
var loaded_peers: Array[int] = []

var peer: SteamMultiplayerPeer = null
var enet_peer: ENetMultiplayerPeer = null

func _ready() -> void:
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	
	if backend == MultiplayerBackend.STEAM:
		Steam.join_requested.connect(_on_lobby_join_requested)
		Steam.lobby_joined.connect(_on_lobby_joined)
		Steam.lobby_created.connect(_on_lobby_created)

func join_lobby(this_lobby_id: int) -> void:
	Log.debug("join_lobby()")
	Steam.joinLobby(this_lobby_id)

func create_lobby() -> void:
	Log.debug("create_lobby()")
	if lobby_id == 0:
		Steam.createLobby(lobby_type, SteamInit.LOBBY_MEMBERS_MAX)
		Log.debug("Lobby Created!")

func start_game() -> void:
	assert(multiplayer.is_server())
	Log.debug("start_game()")
	load_world.rpc()

@rpc("call_local", "reliable")
func load_world() -> void:
	Log.debug("load_world()")
	get_tree().change_scene_to_file("uid://cy05oxvdhtff6")
	#SceneManager.change_scene("uid://cy05oxvdhtff6")

#region Level Loading
# Every peer loads the level at its own speed, so each one checks in with the
# host when its level is ready. The host waits for everyone before spawning.
# NOTE - This lives here instead of in the level because a client can finish
#        loading before the host, and the host's level wouldn't exist yet to
#        receive the message. This autoload always exists.
func report_level_loaded() -> void:
	_peer_loaded.rpc_id(1)

# Peer -> Host
@rpc("any_peer", "call_local", "reliable")
func _peer_loaded() -> void:
	loaded_peers.append(multiplayer.get_remote_sender_id())
	_check_all_loaded()

func _check_all_loaded() -> void:
	if loaded_peers.is_empty(): return # Nobody is loading a level right now
	for id in lobby_members:
		if not loaded_peers.has(id): return

	loaded_peers.clear()
	all_peers_loaded.emit()
#endregion

func host_with_lobby():
	Log.debug("host_with_lobby()")
	peer = SteamMultiplayerPeer.new()
	peer.host_with_lobby(lobby_id)
	multiplayer.set_multiplayer_peer(peer)
	
	_player_connected(1)
	connection_success.emit()

func connect_to_lobby():
	Log.debug("connect_to_lobby")
	peer = SteamMultiplayerPeer.new()
	peer.connect_to_lobby(lobby_id)
	multiplayer.set_multiplayer_peer(peer)

#region Steam Signals
func _on_lobby_join_requested(this_lobby_id: int, friend_id: int) -> void:
	Log.debug("_on_lobby_join_requested()")
	var owner_name: String = Steam.getFriendPersonaName(friend_id)
	Log.info("Joining %s's lobby..." % owner_name)
	join_lobby(this_lobby_id)

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	Log.debug("_on_lobby_joined()")
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		var id = Steam.getLobbyOwner(this_lobby_id)
		if id != Steam.getSteamID():
			lobby_id = this_lobby_id
			lobby_name = Steam.getLobbyData(lobby_id, "name")
			connect_to_lobby()
	else:
		# Get the failure reason
		var fail_reason: String
		match response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."
		Log.warning("Failed to join this chat room: %s" % fail_reason)

func _on_lobby_created(connection_response: int, this_lobby_id: int) -> void:
	Log.debug("_on_lobby_created()")
	if connection_response == 1:
		## Set the lobby ID
		lobby_id = this_lobby_id
		Log.info("Created a lobby: %s" % lobby_id)
		
		## Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, true)
		
		## Set some lobby data
		Steam.setLobbyData(lobby_id, "name", lobby_name)
		Steam.setLobbyData(lobby_id, "mode", str(lobby_type))
		Steam.setLobbyData(lobby_id, "unique_lobby_id", UNIQUE_LOBBY_ID)
		
		## Use Steam as a relay server so the host doesn't need to port forward
		Steam.allowP2PPacketRelay(true)
		
		host_with_lobby()
	else:
		Log.error("Error creating lobby")
		connection_failed.emit()
#endregion

#region Peer Signals
# Ran when a host starts a lobby, and when peers connect to lobby
func _player_connected(id):
	Log.debug("_player_connected()")
	match backend:
		MultiplayerBackend.STEAM:
			lobby_members[id] = peer.get_steam_id_for_peer_id(id)
		MultiplayerBackend.ENET:
			lobby_members[id] = id
	Log.info("Player Connected - Peer ID = %s | Steam ID = %s" % [ id, lobby_members[id] ])
	player_list_changed.emit()

# Ran when peers disconnect from the lobby
func _player_disconnected(id):
	Log.debug("_player_disconnected()")
	Log.info("Player Disconnected - Peer ID = %s | Steam ID = %s" % [ id, lobby_members[id] ])
	lobby_members.erase(id)
	lobby_members_ready.erase(id)
	player_list_changed.emit()

	# If someone leaves while loading, don't keep waiting for them
	loaded_peers.erase(id)
	if multiplayer.is_server():
		_check_all_loaded()

# Ran when peer connects to a host (doesn't trigger on host)
func _connected_to_server():
	Log.debug("_connected_to_server()")
	connection_success.emit()

func _connection_failed():
	Log.debug("_connection_failed()")
	connection_failed.emit()

# Ran when peer disconnects from a host
func _server_disconnected():
	Log.debug("_server_disconnected()")
	reset_network()
#endregion

func reset_network():
	Log.debug("reset_network()")
	if backend == MultiplayerBackend.STEAM:
		Steam.leaveLobby(lobby_id)
	multiplayer.multiplayer_peer.close()
	lobby_id = 0
	lobby_name = "Lobby Name"
	lobby_members = {}
	lobby_members_ready = []
	loaded_peers = []
	peer = null
	enet_peer = null

func enet_host():
	Log.debug("enet_host()")
	enet_peer = ENetMultiplayerPeer.new()
	enet_peer.create_server(DEFAULT_PORT)
	multiplayer.set_multiplayer_peer(enet_peer)
	
	_player_connected(1)
	connection_success.emit()

func enet_join():
	Log.debug("enet_join()")
	enet_peer = ENetMultiplayerPeer.new()
	enet_peer.create_client("127.0.0.1", DEFAULT_PORT)
	multiplayer.set_multiplayer_peer(enet_peer)
