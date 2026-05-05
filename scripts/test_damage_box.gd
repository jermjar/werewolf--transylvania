extends StaticBody3D

@onready var area_3d: Area3D = $Area3D

var damage_number: int = 10

func _ready() -> void:
	area_3d.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server(): return
	
	if body.is_in_group("player"):
		var authority = body.get_multiplayer_authority()
		
		# If the player getting damaged is the host
		if authority == multiplayer.get_unique_id():
			body.health_component.apply_damage(damage_number)
		else:
			body.health_component.request_damage.rpc_id(authority, damage_number)
