extends Control

@onready var return_button: Button = %ReturnButton
@onready var options_button: Button = %OptionsButton
@onready var leave_game_button: Button = %LeaveGameButton

func _ready() -> void:
	Log.debug("GameMenu._ready()")
	self.hide()
	return_button.button_up.connect(_on_return_button_pressed)

# Esc opens and closes the menu. The mouse is freed while it's open.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_on_return_button_pressed()
		else:
			show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_return_button_pressed() -> void:
	Log.debug("GameMenu._on_return_button_pressed()")
	self.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
