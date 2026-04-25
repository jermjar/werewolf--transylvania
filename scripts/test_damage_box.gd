extends StaticBody3D

@onready var area_3d: Area3D = $Area3D

func _ready() -> void:
	area_3d.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.health_component.damage(10)
