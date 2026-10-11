extends Control

# Lets dead players watch living players through their eyes.
#
# Entirely local, nothing here is sent over the network. It only changes which
# camera this machine looks through. It starts when our own player is removed
# from Players, and moves on when the player we're watching is removed too.

@export var players: Node3D
@export var level_camera: Camera3D

@onready var spectating_label: Label = %SpectatingLabel

var is_spectating: bool = false
var target: Player # The player being watched, or null if nobody is left

# Our player is named after our peer ID
var my_player_name: String

func _ready() -> void:
	spectating_label.hide()
	my_player_name = str(multiplayer.get_unique_id())
	players.child_exiting_tree.connect(_on_player_exiting)

func _unhandled_input(event: InputEvent) -> void:
	if not is_spectating: return

	if event.is_action_pressed("spectate_next"):
		_cycle_target(1)
	elif event.is_action_pressed("spectate_previous"):
		_cycle_target(-1)

func _on_player_exiting(player: Node) -> void:
	# Ignore players being removed because the game is ending, not because they died:
	# either the level is being unloaded, or we lost the connection to the host
	# (Godot then removes every player the host spawned)
	if not is_inside_tree(): return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return

	if player.name == my_player_name:
		is_spectating = true
		_watch_anyone(player)
	elif player == target:
		_watch_anyone(player)

# Watch the first living player, or the level camera if nobody is left
func _watch_anyone(leaving: Node) -> void:
	var watchable: Array[Player] = _get_watchable_players(leaving)
	_watch(null if watchable.is_empty() else watchable[0])

func _cycle_target(direction: int) -> void:
	var watchable: Array[Player] = _get_watchable_players()
	if watchable.is_empty(): return

	var index: int = watchable.find(target)
	_watch(watchable[posmod(index + direction, watchable.size())])

# Everyone still alive, except us and the player that's currently leaving
func _get_watchable_players(leaving: Node = null) -> Array[Player]:
	var watchable: Array[Player] = []
	for player in players.get_children():
		if player != leaving and player.name != my_player_name:
			watchable.append(player)
	return watchable

# Pass null to fall back to the level camera when nobody is left to watch
func _watch(new_target: Player) -> void:
	if is_instance_valid(target):
		target.set_spectated(false)

	target = new_target
	if target:
		target.set_spectated(true)
		# Same name that's shown above their head
		spectating_label.text = "Spectating: %s    (LMB / RMB to switch)" % target.steam_name_label.text
	else:
		level_camera.current = true
		spectating_label.text = "Nobody left to spectate"
	spectating_label.show()
