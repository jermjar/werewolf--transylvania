extends Control

const WEREWOLF_MESSAGE_TIME: float = 5.0

@onready var phase_label: Label = %PhaseLabel
@onready var werewolf_label: Label = %WerewolfLabel

func _ready() -> void:
	werewolf_label.hide()
	RoundManager.instance.werewolf_chosen.connect(_on_werewolf_chosen)

func _process(_delta: float) -> void:
	var round_manager: RoundManager = RoundManager.instance
	if round_manager.phase == RoundManager.Phase.WAITING:
		phase_label.text = ""
		return

	var seconds_left: int = ceili(round_manager.get_time_left())
	var minutes: int = floori(seconds_left / 60.0)
	var phase_name: String = RoundManager.Phase.keys()[round_manager.phase]
	phase_label.text = "%s  %d:%02d" % [phase_name, minutes, seconds_left % 60]

# Only the chosen player sees the message
func _on_werewolf_chosen(werewolf_id: int) -> void:
	if werewolf_id != multiplayer.get_unique_id(): return

	werewolf_label.show()
	get_tree().create_timer(WEREWOLF_MESSAGE_TIME).timeout.connect(werewolf_label.hide)
