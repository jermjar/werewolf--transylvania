class_name Player extends CharacterBody3D

@onready var steam_name_label: Label3D = $SteamName
@onready var camera_controller: CameraController = $CameraController
@onready var camera: Camera3D = $CameraController/Camera3D
@onready var head: MeshInstance3D = $HeadMesh
@onready var body: MeshInstance3D = $BodyMesh

@export var steam_id: int = 0
@export var steam_name: String

# Components
@export var health_component: HealthComponent

var current_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var mouse_sensitivity: float = 0.0015
var capture_mouse: bool
var mouse_input: Vector2

var input_dir: Vector2 = Vector2.ZERO
var movement_velocity: Vector3 = Vector3.ZERO
var speed: float = 5.0
var acceleration: float = 0.2
var deceleration: float = 0.5

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	print("Authority: ", get_multiplayer_authority(), " Peer ID: ", multiplayer.get_unique_id())
	steam_name_label.text = steam_name
	camera.current = is_multiplayer_authority()
	set_process_unhandled_input(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	Input.mouse_mode = current_mouse_mode
	add_to_group("player")
	health_component.died.connect(_on_died)
	
	if is_multiplayer_authority():
		steam_name_label.hide()
		head.hide()
		body.hide()

func _unhandled_input(event: InputEvent) -> void:
	capture_mouse = event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if capture_mouse:
		mouse_input.x += -event.screen_relative.x * mouse_sensitivity
		mouse_input.y += -event.screen_relative.y * mouse_sensitivity
		camera_controller.update_camera_rotation(mouse_input)

func _process(_delta: float) -> void:
	mouse_input = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var current_velocity = Vector2(movement_velocity.x, movement_velocity.z)
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		current_velocity = lerp(current_velocity, Vector2(direction.x, direction.z) * speed, acceleration)
	else:
		current_velocity = current_velocity.move_toward(Vector2.ZERO, deceleration)
	
	movement_velocity = Vector3(current_velocity.x, velocity.y, current_velocity.y)
	velocity = movement_velocity
	
	move_and_slide()

func update_rotation(rotation_input) -> void:
	global_transform.basis = Basis.from_euler(rotation_input)

func _on_died():
	if is_multiplayer_authority():
		die.rpc()

@rpc("call_local", "reliable")
func die():
	if is_multiplayer_authority():
		var level_camera: Camera3D = get_tree().get_first_node_in_group("level_camera")
		level_camera.current = true
	queue_free()
