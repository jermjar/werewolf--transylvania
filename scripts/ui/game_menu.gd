extends Control

@onready var return_button: Button = %ReturnButton
@onready var options_button: Button = %OptionsButton
@onready var leave_game_button: Button = %LeaveGameButton

func _ready() -> void:
	self.hide()
	return_button.button_up.connect(_on_return_button_pressed)

func _on_return_button_pressed() -> void:
	self.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
