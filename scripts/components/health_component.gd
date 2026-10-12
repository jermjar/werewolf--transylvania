class_name HealthComponent extends Node

# Health for anything that can be hurt. Weapons find it with HealthComponent.find_on().
#
# Only the owner's machine (the multiplayer authority) ever changes the health:
# - damage() and heal() can be called on any machine. If that machine isn't
#   the owner (e.g. we punched someone else), it asks the owner to do it.
# - The owner works out the new health and sends it to everyone with
#   sync_health(), including itself ("call_local"), so every machine shows
#   the same number.

signal health_changed(current: int, max: int)
signal died

@export var max_health: int = 100
var current_health: int = 0

func _ready() -> void:
	Log.debug("HealthComponent._ready()")
	current_health = max_health

# The HealthComponent of a node (like whatever a weapon hit), or null if it can't be hurt
static func find_on(node: Node) -> HealthComponent:
	Log.debug("HealthComponent.find_on()")
	if node == null: return null
	return node.get_node_or_null("HealthComponent") as HealthComponent

func damage(amount: int) -> void:
	Log.debug("damage()")
	_change_health(-amount)

func heal(amount: int) -> void:
	Log.debug("heal()")
	_change_health(amount)

func _change_health(amount: int) -> void:
	Log.debug("HealthComponent._change_health()")
	if is_multiplayer_authority():
		_apply_change(amount)
	else:
		_request_change.rpc_id(get_multiplayer_authority(), amount)

# Any machine -> Owner
@rpc("any_peer", "reliable")
func _request_change(amount: int) -> void:
	Log.debug("_request_change()")
	if is_multiplayer_authority():
		Log.debug("_request_change() -> is_multiplayer_authority()")
		_apply_change(amount)

# Owner only
func _apply_change(amount: int) -> void:
	Log.debug("_apply_change()")
	# Already dead and waiting to be removed. Without this, extra hits would
	# emit died again and send a second die() to a player that may be gone.
	if current_health <= 0: return
	current_health = clampi(current_health + amount, 0, max_health)
	if current_health <= 0:
		died.emit()
	else:
		sync_health.rpc(current_health)

# Changes max health but keeps the same percentage, e.g. 50/100 becomes 100/200.
# Called on every machine. Only the owner converts the current health and shares it.
func set_max_health(new_max_health: int) -> void:
	Log.debug("HealthComponent.set_max_health()")
	var percentage: float = float(current_health) / max_health
	max_health = new_max_health
	if is_multiplayer_authority() and current_health > 0:
		# Never let rounding drop someone to 0 just by changing form
		sync_health.rpc(maxi(1, roundi(percentage * new_max_health)))

# Owner -> Everyone
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
