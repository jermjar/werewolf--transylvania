extends Node

@onready var interaction_hand: Marker3D = %InteractionHand
@onready var interaction_raycast: RayCast3D = %InteractionRayCast3D
@onready var player_camera: Camera3D = $"../CameraController/Camera3D"

var current_object: Object
var interaction_component: InteractionComponent

func _ready() -> void:
	# Every player on our screen has one of these, but only the one for the
	# player we control should react to our input
	set_physics_process(is_multiplayer_authority())

func _physics_process(_delta: float) -> void:
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

				if Input.is_action_pressed("interact"):
					current_object = potential_object
					interaction_component.pre_interact(interaction_hand)
