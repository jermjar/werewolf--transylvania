class_name RoundManager extends Node

# Runs the day/night cycle and picks the werewolf.
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
	NIGHT
}

const NO_WEREWOLF: int = 0

# The RoundManager of the current match, or null when no match is loaded
static var instance: RoundManager

# Phase lengths in seconds. Only the host's values matter, it sends them with each phase.
@export var first_day_length: float = 30.0
@export var day_length: float = 60.0
@export var night_length: float = 60.0

@onready var phase_timer: Timer = $PhaseTimer

var phase: Phase = Phase.WAITING
var werewolf_id: int = NO_WEREWOLF

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
	# Every peer runs the timer so the HUD can show the time left,
	# but only the host acts when it runs out
	if multiplayer.is_server():
		phase_timer.timeout.connect(_on_phase_timer_timeout)

func get_time_left() -> float:
	return phase_timer.time_left

# Host only
func start_round() -> void:
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

# Host only - dead players are removed from the game, so everyone
# in the "player" group is alive
func _choose_werewolf() -> void:
	var alive_players: Array[Node] = get_tree().get_nodes_in_group("player")
	if alive_players.is_empty(): return

	var werewolf: Node = alive_players.pick_random()
	_set_werewolf.rpc(werewolf.name.to_int())

# Host -> Everyone
# Each peer counts down on its own timer. The host's timer decides when the
# phase actually ends, and the next _start_phase() resyncs everyone.
@rpc("call_local", "reliable")
func _start_phase(new_phase: Phase, duration: float) -> void:
	phase = new_phase
	phase_timer.start(duration)
	print("_start_phase() -> %s for %ss" % [Phase.keys()[phase], duration])
	phase_changed.emit(phase)

# Host -> Everyone
# Everyone is told who the werewolf is because every screen will need to draw
# them as a werewolf at night. Name tags being hidden is what keeps it a secret.
@rpc("call_local", "reliable")
func _set_werewolf(id: int) -> void:
	werewolf_id = id
	print("_set_werewolf() -> %s" % id)
	werewolf_chosen.emit(id)
