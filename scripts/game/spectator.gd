class_name Spectator extends Control

# Lets dead players, and people who joined during a match, watch living
# players through their eyes.
#
# Entirely local, nothing here is sent over the network. It only changes which
# camera this machine looks through. It starts when our own player is removed
# from Players (or when we joined late, see TestLevel.game_loaded()), and moves
# on when the player we're watching is removed too.

@export var players: Node3D
@export var level_camera: Camera3D

@onready var spectating_label: Label = %SpectatingLabel

var is_spectating: bool = false
var target: Player # The player being watched, or null if nobody is left

var my_peer_id: int

func _ready() -> void:
	Log.debug("Spectator._ready()")
	spectating_label.hide()
	my_peer_id = multiplayer.get_unique_id()
	players.child_exiting_tree.connect(_on_player_exiting)

func _unhandled_input(event: InputEvent) -> void:
	if not is_spectating: return

	if event.is_action_pressed("spectate_next"):
		_cycle_target(1)
	elif event.is_action_pressed("spectate_previous"):
		_cycle_target(-1)

func _on_player_exiting(player: Player) -> void:
	Log.debug("Spectator._on_player_exiting()")
	# Ignore players being removed because the game is ending, not because they died:
	# either the level is being unloaded, or we lost the connection to the host
	# (Godot then removes every player the host spawned)
	if not is_inside_tree(): return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return

	if player.peer_id == my_peer_id:
		start_spectating(player)
	elif player == target:
		_watch_anyone(player)

# Called when our own player died or left, and by the level when we joined a
# match late and have no player
func start_spectating(leaving_player: Node = null) -> void:
	Log.debug("Spectator.start_spectating()")
	is_spectating = true
	_watch_anyone(leaving_player)

# Watch the first living player, or the level camera if nobody is left
func _watch_anyone(leaving: Node) -> void:
	Log.debug("Spectator._watch_anyone()")
	var watchable: Array[Player] = _get_watchable_players(leaving)
	_watch(null if watchable.is_empty() else watchable[0])

func _cycle_target(direction: int) -> void:
	Log.debug("Spectator._cycle_target()")
	var watchable: Array[Player] = _get_watchable_players()
	if watchable.is_empty(): return

	var index: int = watchable.find(target)
	_watch(watchable[posmod(index + direction, watchable.size())])

# Everyone still alive, except us and the player that's currently leaving
func _get_watchable_players(leaving: Node = null) -> Array[Player]:
	Log.debug("Spectator._get_watchable_players()")
	var watchable: Array[Player] = []
	for player in players.get_children():
		if player != leaving and player.peer_id != my_peer_id:
			watchable.append(player)
	return watchable

# Pass null to fall back to the level camera when nobody is left to watch
func _watch(new_target: Player) -> void:
	Log.debug("Spectator._watch()")
	if is_instance_valid(target):
		target.set_spectated(false)

	target = new_target
	if target:
		target.set_spectated(true)
		spectating_label.text = "Spectating: %s    (LMB / RMB to switch)" % Networking.get_display_name(target.peer_id)
	else:
		level_camera.current = true
		spectating_label.text = "Nobody left to spectate"
	spectating_label.show()
