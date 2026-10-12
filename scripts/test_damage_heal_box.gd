extends StaticBody3D

@onready var area_3d: Area3D = $Area3D

var damage_number: int = 10
var heal_amount: int = 20

@export_enum("DAMAGE", "HEAL") var box_type: String

func _ready() -> void:
	Log.debug("TestDamageHealBox._ready()")
	area_3d.body_entered.connect(_on_body_entered)

# Making damage server authoritative
func _on_body_entered(body: Node3D) -> void:
	Log.debug("TestDamageHealBox._on_body_entered()")
	if not multiplayer.is_server(): return
	var health: HealthComponent = HealthComponent.find_on(body)
	if health == null: return

	if box_type == "DAMAGE":
		health.damage(damage_number)
	elif box_type == "HEAL":
		health.heal(heal_amount)
