class_name RoundManager extends Node

# Runs the day/night cycle, picks the werewolf, and decides who wins.
#
# The host makes every decision and announces it with an RPC. Everyone else
# just follows along. The host owns this node and that never changes, so the
# RPCs below use the default "authority" mode, meaning only the host can call them.
#
# Other scripts reach this node through RoundManager.instance and react to
# its signals (name tags, lighting, HUD).

signal phase_changed(phase: Phase)
signal werewolf_chosen(werewolf_id: int)

enum Phase {
	WAITING, # Before the round starts
	DAY,
	NIGHT,
	ENDED # Someone won. The next round starts when the phase timer runs out.
}

enum Winner {
	VILLAGERS,
	WEREWOLF
}

const NO_WEREWOLF: int = 0

# The RoundManager of the current match, or null when no match is loaded
static var instance: RoundManager

# Lengths in seconds. Only the host's values matter, it sends them to everyone.
@export var first_day_length: float = 30.0
@export var day_length: float = 60.0
@export var night_length: float = 60.0
@export var round_length: float = 270.0 # Villagers win if the werewolf survives this long
@export var restart_delay: float = 8.0 # How long the result is shown before the next round

# Dead players are removed from here, so its children are everyone still alive
@export var players: Node3D

@onready var phase_timer: Timer = $PhaseTimer
@onready var round_timer: Timer = $RoundTimer

var phase: Phase = Phase.WAITING
var werewolf_id: int = NO_WEREWOLF
var winner: Winner

# Set in _enter_tree() instead of _ready() so it's available to every other
# node's _ready() in the level, no matter what order they're in
func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	# Only clear it if it's still us, in case the next match's RoundManager
	# was already added before this one finished leaving
	if instance == self:
		instance = null

func _ready() -> void:
	# Every peer runs the timers so the HUD can show the time left,
	# but only the host acts when they run out
	if multiplayer.is_server():
		phase_timer.timeout.connect(_on_phase_timer_timeout)
		round_timer.timeout.connect(_on_round_timer_timeout)
		players.child_exiting_tree.connect(_on_player_removed)

func get_time_left() -> float:
	return phase_timer.time_left

func get_round_time_left() -> float:
	return round_timer.time_left

# Host only
func start_round() -> void:
	_start_round_timer.rpc(round_length)
	_start_phase.rpc(Phase.DAY, first_day_length)

# Host only - the current phase is over, decide what comes next
func _on_phase_timer_timeout() -> void:
	match phase:
		Phase.DAY:
			if werewolf_id == NO_WEREWOLF:
				_choose_werewolf()
			_start_phase.rpc(Phase.NIGHT, night_length)
		Phase.NIGHT:
			_start_phase.rpc(Phase.DAY, day_length)
		Phase.ENDED:
			Networking.start_game() # Reloads the level for everyone, starting a new round

# Host only - dead players are removed from the game, so everyone
# in the "player" group is alive
func _choose_werewolf() -> void:
	var alive_players: Array[Node] = get_tree().get_nodes_in_group("player")
	if alive_players.is_empty(): return

	var werewolf: Node = alive_players.pick_random()
	_set_werewolf.rpc(werewolf.name.to_int())
	# In case the werewolf is already the only one left
	_check_for_winner()

#region Winning
# Host only
func _on_round_timer_timeout() -> void:
	_end_round.rpc(Winner.VILLAGERS)

# Host only - a player died or left the game
func _on_player_removed(player: Node) -> void:
	# The whole level is being unloaded, not a player leaving
	if not is_inside_tree(): return
	_check_for_winner(player)

# Host only
func _check_for_winner(leaving_player: Node = null) -> void:
	if phase == Phase.ENDED or werewolf_id == NO_WEREWOLF: return

	var alive_players: Array[Node] = players.get_children()
	alive_players.erase(leaving_player) # It's still a child while it's being removed
	var werewolf_alive: bool = alive_players.any(func(player: Node) -> bool: return player.name.to_int() == werewolf_id)

	if not werewolf_alive:
		_end_round.rpc(Winner.VILLAGERS)
	elif alive_players.size() == 1:
		_end_round.rpc(Winner.WEREWOLF)
#endregion

# Host -> Everyone
# Each peer counts down on its own timer. The host's timer decides when the
# phase actually ends, and the next _start_phase() resyncs everyone.
@rpc("call_local", "reliable")
func _start_phase(new_phase: Phase, duration: float) -> void:
	phase = new_phase
	phase_timer.start(duration)
	Log.info("_start_phase() -> %s for %ss" % [Phase.keys()[phase], duration])
	phase_changed.emit(phase)

# Host -> Everyone
@rpc("call_local", "reliable")
func _start_round_timer(duration: float) -> void:
	round_timer.start(duration)

# Host -> Everyone
# Everyone is told who the werewolf is because every screen will need to draw
# them as a werewolf at night. Name tags being hidden is what keeps it a secret.
@rpc("call_local", "reliable")
func _set_werewolf(id: int) -> void:
	werewolf_id = id
	Log.info("_set_werewolf() -> %s" % id)
	werewolf_chosen.emit(id)

# Host -> Everyone
@rpc("call_local", "reliable")
func _end_round(round_winner: Winner) -> void:
	winner = round_winner
	round_timer.stop()
	Log.info("_end_round() -> %s win" % Winner.keys()[winner])
	# The phase timer now counts down to the next round
	_start_phase(Phase.ENDED, restart_delay)
