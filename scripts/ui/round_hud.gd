extends Control

const WEREWOLF_MESSAGE_TIME: float = 5.0

@onready var phase_label: Label = %PhaseLabel
@onready var round_time_label: Label = %RoundTimeLabel
@onready var werewolf_label: Label = %WerewolfLabel
@onready var werewolf_form_label: Label = %WerewolfFormLabel
@onready var result_label: Label = %ResultLabel

# Saved once, because asking for it every frame errors after the connection closes
var my_peer_id: int

func _ready() -> void:
	Log.debug("RoundHUD._ready()")
	my_peer_id = multiplayer.get_unique_id()
	werewolf_label.hide()
	RoundManager.instance.werewolf_chosen.connect(_on_werewolf_chosen)
	RoundManager.instance.phase_changed.connect(_on_phase_changed)

func _process(_delta: float) -> void:
	var round_manager: RoundManager = RoundManager.instance
	if round_manager.phase == RoundManager.Phase.WAITING:
		phase_label.text = ""
		return

	var is_ended: bool = round_manager.phase == RoundManager.Phase.ENDED
	var phase_name: String = "NEXT ROUND" if is_ended else RoundManager.Phase.keys()[round_manager.phase]
	phase_label.text = "%s  %s" % [phase_name, _format_time(round_manager.get_time_left())]
	round_time_label.text = "" if is_ended else "Round ends in %s" % _format_time(round_manager.get_round_time_left())

	# Reminds the werewolf that they're transformed
	werewolf_form_label.visible = round_manager.is_werewolf(my_peer_id) and round_manager.is_night()

func _format_time(seconds: float) -> String:
	var whole_seconds: int = ceili(seconds)
	return "%d:%02d" % [floori(whole_seconds / 60.0), whole_seconds % 60]

# Only the chosen player sees the message
func _on_werewolf_chosen(werewolf_id: int) -> void:
	Log.debug("RoundHUD._on_werewolf_chosen()")
	if werewolf_id != my_peer_id: return

	werewolf_label.show()
	get_tree().create_timer(WEREWOLF_MESSAGE_TIME).timeout.connect(werewolf_label.hide)

# Shows who won, and reveals who the werewolf was
func _on_phase_changed(phase: RoundManager.Phase) -> void:
	Log.debug("RoundHUD._on_phase_changed()")
	if phase != RoundManager.Phase.ENDED: return

	var round_manager: RoundManager = RoundManager.instance
	match round_manager.winner:
		RoundManager.Winner.VILLAGERS: result_label.text = "VILLAGERS WIN"
		RoundManager.Winner.WEREWOLF: result_label.text = "WEREWOLF WINS"
		RoundManager.Winner.NOBODY: result_label.text = "NOBODY WINS"
	# There's no werewolf to reveal if the round ended before one was chosen
	if round_manager.werewolf_id != RoundManager.NO_WEREWOLF:
		result_label.text += "\nThe werewolf was %s" % Networking.get_display_name(round_manager.werewolf_id)
	result_label.show()
