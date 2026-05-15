extends StaticBody3D

@onready var area_3d: Area3D = $Area3D

var damage_number: int = 10
var heal_amount: int = 20

@export_enum("DAMAGE", "HEAL") var box_type: String

func _ready() -> void:
	area_3d.body_entered.connect(_on_body_entered)

# Making damage server authoritative
func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server() or not body.is_in_group("player"): return
	
	if box_type == "DAMAGE":
		body.health_component.damage(damage_number)
	elif box_type == "HEAL":
		body.health_component.heal(heal_amount)
