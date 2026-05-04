extends StaticBody3D

@onready var area_3d: Area3D = $Area3D

var damage_number: int = 10

func _ready() -> void:
	area_3d.body_entered.connect(_on_body_entered)

# Maybe don't check the group and use has_method()
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.health_component.apply_damage(damage_number)
