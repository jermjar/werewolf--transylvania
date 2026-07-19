extends Node

@onready var interaction_controller: Node = %InteractionController
@onready var interaction_hand: Marker3D = %InteractionHand
@onready var interaction_raycast: RayCast3D = %InteractionRayCast3D
@onready var player_camera: Camera3D = $"../CameraController/Camera3D"

var current_object: Object
var last_potential_object: Object
var interaction_component: Node

func _process(_delta: float) -> void:
	# If we are interacting with something
	if current_object:
		if Input.is_action_pressed("interact"):
			if interaction_component:
				interaction_component.interact()
		else:
			if interaction_component:
				interaction_component.post_interact()
				current_object = null
	
	# If we are looking to interact with something
	else:
		var potential_object: Object = interaction_raycast.get_collider()
		
		if potential_object and potential_object is Node:
			interaction_component = potential_object.get_node_or_null("InteractionComponent")
			if interaction_component:
				if not interaction_component.can_interact: return
				
				last_potential_object = current_object
				if Input.is_action_pressed("interact"):
					current_object = potential_object
					interaction_component.pre_interact(interaction_hand)
