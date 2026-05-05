class_name HealthComponent extends Node

signal health_changed(current: int, max: int)
signal died

@export var max_health: int = 100
var current_health: int = 0

func _ready() -> void:
	current_health = max_health

# I really don't know a solution to this, I just wish you could call an rpc on yourself
@rpc("any_peer", "reliable")
func request_damage(amount: int) -> void:
	if is_multiplayer_authority():
		apply_damage(amount)

func apply_damage(amount: int) -> void:
	current_health = clampi(current_health - amount, 0, max_health)
	if current_health <= 0:
		died.emit()
	else:
		sync_health.rpc(current_health)

# I don't fully understand how this works or if it even does
@rpc("call_local", "reliable")
func sync_health(new_health: int) -> void:
	current_health = new_health
	_emit_health_changed()

# Helper function
func _emit_health_changed() -> void:
	health_changed.emit(current_health, max_health)
	print("ID: %s | HP: %s / %s" % [multiplayer.get_remote_sender_id(), current_health, max_health])
