extends Node

const DEFAULT_PORT: int = 8080

enum LobbyType {
	PRIVATE = Steam.LOBBY_TYPE_PRIVATE,
	FRIENDS_ONLY = Steam.LOBBY_TYPE_FRIENDS_ONLY,
	PUBLIC = Steam.LOBBY_TYPE_PUBLIC
}

var lobby_id: int = 0
var lobby_type: int = LobbyType.PUBLIC
var lobby_name: String = "[WEREWOLF] - Placeholder"

var peer: SteamMultiplayerPeer = null

func _ready() -> void:
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.connection_failed.connect(_connected_fail)
	multiplayer.server_disconnected.connect(_server_disconnected)
	
	Steam.join_requested.connect(_on_lobby_join_requested)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_created.connect(_on_lobby_created)

func join_lobby(this_lobby_id: int) -> void:
	Steam.joinLobby(this_lobby_id)

func create_lobby() -> void:
	Steam.createLobby(lobby_type, SteamInit.LOBBY_MEMBERS_MAX)

func create_socket():
	peer = SteamMultiplayerPeer.new()
	peer.create_host(DEFAULT_PORT)
	multiplayer.set_multiplayer_peer(peer)

func connect_socket(steam_id : int):
	peer = SteamMultiplayerPeer.new()
	peer.create_client(steam_id, DEFAULT_PORT)
	multiplayer.set_multiplayer_peer(peer)

func _on_lobby_join_requested(this_lobby_id: int, friend_id: int) -> void:
	# Get the lobby owner's name
	var owner_name: String = Steam.getFriendPersonaName(friend_id)
	print("Joining %s's lobby..." % owner_name)
	
	# Attempt to join lobby
	join_lobby(this_lobby_id)

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("Joined successfully?")
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
		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to be a relay backup: %s" % set_relay)
	else:
		print("Error creating lobby")

func _player_connected(id):
	pass

func _player_disconnected(id):
	pass

func _connected_ok():
	pass

func _server_disconnected():
	pass

func _connected_fail():
	pass
	
func reset_network():
	pass
