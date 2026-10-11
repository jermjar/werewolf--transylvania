class_name HealthComponent extends Node

signal health_changed(current: int, max: int)
signal died

@export var max_health: int = 100
var current_health: int = 0

func _ready() -> void:
	current_health = max_health

func damage(amount: int) -> void:
	Log.debug("damage()")
	if is_multiplayer_authority():
		apply_damage(amount)
	else:
		request_damage.rpc_id(get_multiplayer_authority(), amount)

@rpc("any_peer", "reliable")
func request_damage(amount: int) -> void:
	Log.debug("request_damage()")
	if is_multiplayer_authority():
		Log.debug("request_damage() -> is_multiplayer_authority()")
		apply_damage(amount)

func apply_damage(amount: int) -> void:
	Log.debug("apply_damage()")
	# Already dead and waiting to be removed. Without this, extra hits would
	# emit died again and send a second die() to a player that may be gone.
	if current_health <= 0: return
	current_health = clampi(current_health - amount, 0, max_health)
	if current_health <= 0:
		died.emit()
	else:
		sync_health.rpc(current_health)

func heal(amount: int) -> void:
	Log.debug("heal()")
	if is_multiplayer_authority():
		apply_heal(amount)
	else:
		request_heal.rpc_id(get_multiplayer_authority(), amount)

@rpc("any_peer", "reliable")
func request_heal(amount: int) -> void:
	Log.debug("request_heal()")
	if is_multiplayer_authority():
		Log.debug("request_heal() -> is_multiplayer_authority()")
		apply_heal(amount)

func apply_heal(amount: int) -> void:
	Log.debug("apply_heal()")
	current_health = clampi(current_health + amount, 0, max_health)
	sync_health.rpc(current_health)

# I don't fully understand how this works
@rpc("call_local", "reliable")
func sync_health(new_health: int) -> void:
	Log.debug("sync_health()")
	current_health = new_health
	_emit_health_changed()

# Helper function
func _emit_health_changed() -> void:
	Log.debug("_emit_health_changed()")
	health_changed.emit(current_health, max_health)
	Log.debug("ID: %s | HP: %s / %s" % [multiplayer.get_remote_sender_id(), current_health, max_health])
