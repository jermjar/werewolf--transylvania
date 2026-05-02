class_name HealthComponent extends Node

signal health_changed(current: int, max: int)
signal died

@export var max_health: int = 100
var current_health: int = 0

## TODO - Add multiplayer functionality to this, and add a way to take damage
func _ready() -> void:
	current_health = max_health
	_emit_health_changed()

func damage(amount: int) -> void:
	current_health = clampi(current_health - amount, 0, max_health)
	_emit_health_changed()
	if current_health == 0:
		died.emit()
		print("died.emit()")

func heal(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)
	_emit_health_changed()

# Helper function
func _emit_health_changed() -> void:
	health_changed.emit(current_health, max_health)
	print("HP: %s / %s" % [current_health, max_health])
