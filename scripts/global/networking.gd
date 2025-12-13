extends Node

signal player_list_changed()
signal connection_failed()
signal connection_success()

const DEFAULT_PORT: int = 8080

enum LobbyType {
	PRIVATE = Steam.LOBBY_TYPE_PRIVATE,
	FRIENDS_ONLY = Steam.LOBBY_TYPE_FRIENDS_ONLY,
	PUBLIC = Steam.LOBBY_TYPE_PUBLIC
}
var lobby_id: int = 0
var lobby_type: int = LobbyType.PUBLIC
var lobby_name: String = "[WEREWOLF] - Placeholder"
var lobby_members := {}

var peer: SteamMultiplayerPeer = null

func _ready() -> void:
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	
	Steam.join_requested.connect(_on_lobby_join_requested)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_created.connect(_on_lobby_created)

func join_lobby(this_lobby_id: int) -> void:
	Steam.joinLobby(this_lobby_id)

func create_lobby() -> void:
	if lobby_id == 0:
		Steam.createLobby(lobby_type, SteamInit.LOBBY_MEMBERS_MAX)
		print("Lobby Created!")

func create_socket():
	peer = SteamMultiplayerPeer.new()
	peer.create_host(DEFAULT_PORT)
	multiplayer.set_multiplayer_peer(peer)
	print("create_socket")
	
	_player_connected(1)
	connection_success.emit()

func connect_socket(steam_id : int):
	peer = SteamMultiplayerPeer.new()
	peer.create_client(steam_id, DEFAULT_PORT)
	multiplayer.set_multiplayer_peer(peer)
	print("connect_socket")

func _on_lobby_join_requested(this_lobby_id: int, friend_id: int) -> void:
	# Get the lobby owner's name
	var owner_name: String = Steam.getFriendPersonaName(friend_id)
	print("Joining %s's lobby..." % owner_name)
	
	# Attempt to join lobby
	join_lobby(this_lobby_id)

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		var id = Steam.getLobbyOwner(this_lobby_id)
		if id != Steam.getSteamID():
			lobby_id = this_lobby_id
			lobby_name = Steam.getLobbyData(lobby_id, "name")
			connect_socket(id)
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
		print("Failed to join this chat room: %s" % fail_reason)

func _on_lobby_created(connect: int, this_lobby_id: int) -> void:
	if connect == 1:
		## Set the lobby ID
		lobby_id = this_lobby_id
		print("Created a lobby: %s" % lobby_id)
		
		## Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, true)
		
		## Set some lobby data
		Steam.setLobbyData(lobby_id, "name", lobby_name)
		Steam.setLobbyData(lobby_id, "mode", str(lobby_type))
		
		## Allow P2P connections to fallback to being relayed through Steam if needed
		#var set_relay: bool = Steam.allowP2PPacketRelay(true)
		#print("Allowing Steam to be a relay backup: %s" % set_relay)
		
		create_socket()
	else:
		print("Error creating lobby")
		connection_failed.emit()

#region Peer Signals
# Ran when a host starts a lobby, and when peers connect to lobby
func _player_connected(id):
	lobby_members[id] = peer.get_steam64_from_peer_id(id)
	player_list_changed.emit()
	print("Player Connected: %s" % id)

# Ran when peers disconnect from the lobby
func _player_disconnected(id):
	lobby_members.erase(id)
	player_list_changed.emit()
	print("Player Disconnected: %s" % id)

# Ran when peer connects to a host (doesn't trigger on host)
func _connected_to_server():
	connection_success.emit()

func _connection_failed():
	connection_failed.emit()

# Ran when peer disconnects from a host
func _server_disconnected():
	reset_network()
#endregion

func reset_network():
	multiplayer.multiplayer_peer.close()
	Steam.leaveLobby(lobby_id)
	lobby_members = {}
	peer = null
	lobby_id = 0
	#lobby_type = 0
