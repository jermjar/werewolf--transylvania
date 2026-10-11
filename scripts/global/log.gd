extends Node

# Basic logger. Use Log.debug(), Log.info(), Log.warning() and Log.error()
# instead of print() so the output can be filtered by level.
# NOTE - Named "Log" because Godot already has a built-in class called "Logger"

enum Level {
	DEBUG,   # Function traces and noisy details
	INFO,    # Meaningful events (player connected, phase changed, ...)
	WARNING, # Something failed, but the game can continue
	ERROR    # Something is broken
}

var level: Level = Level.INFO

func debug(message: String) -> void:
	_log(Level.DEBUG, message)

func info(message: String) -> void:
	_log(Level.INFO, message)

func warning(message: String) -> void:
	_log(Level.WARNING, message)

func error(message: String) -> void:
	_log(Level.ERROR, message)

func _log(message_level: Level, message: String) -> void:
	if message_level < level: return

	var text: String = _get_peer_tag() + message
	match message_level:
		# These also show up in the editor's Debugger tab. Godot already
		# starts them with "WARNING: " / "ERROR: ", so no label is added here.
		Level.WARNING: push_warning(text)
		Level.ERROR: push_error(text)
		_: print("%s: %s" % [Level.keys()[message_level], text])

# Shows which game instance printed the message, so output from several
# instances running at once can be told apart
func _get_peer_tag() -> String:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer: return ""
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return ""

	if multiplayer.is_server():
		return "[Host] "
	return "[%s] " % multiplayer.get_unique_id()
