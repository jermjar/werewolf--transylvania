class_name Flashlight extends Item

# Using it toggles the light. Every machine has a copy of this item under the
# holder's camera, so the toggle is sent to everyone and they all see the beam.
# The light is a child of this item, so it's hidden whenever the item is put away.

@onready var light: SpotLight3D = $SpotLight3D

func use() -> void:
	_set_light_on.rpc(not light.visible)

# Owner -> Everyone
@rpc("call_local", "reliable")
func _set_light_on(on: bool) -> void:
	light.visible = on
