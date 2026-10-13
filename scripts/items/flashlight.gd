class_name Flashlight extends Item

# Using it toggles the light. Every machine has a copy of this item under the
# holder's camera, so the toggle is sent to everyone and they all see the beam.
# The light is a child of this item, so it's hidden whenever the item is put away.

@onready var light: SpotLight3D = $SpotLight3D

func _ready() -> void:
	Log.debug("Flashlight._ready()")
	multiplayer.peer_connected.connect(_on_peer_connected)

# Owner only - someone joined during the match, so tell them if our light is on
func _on_peer_connected(id: int) -> void:
	Log.debug("Flashlight._on_peer_connected()")
	if is_multiplayer_authority():
		_set_light_on.rpc_id(id, light.visible)

func use() -> void:
	Log.debug("Flashlight.use()")
	_set_light_on.rpc(not light.visible)

# Owner -> Everyone
@rpc("call_local", "reliable")
func _set_light_on(on: bool) -> void:
	Log.debug("Flashlight._set_light_on()")
	light.visible = on
