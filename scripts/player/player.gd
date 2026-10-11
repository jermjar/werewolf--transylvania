class_name Player extends CharacterBody3D

@onready var health_label: Label = $HUD/HealthLabel
@onready var crosshair: Label = $HUD/Crosshair
@onready var health_label_3d: Label3D = $HealthLabel3D
@onready var steam_name_label: Label3D = $SteamName
@onready var camera_controller: CameraController = $CameraController
@onready var camera: Camera3D = $CameraController/Camera3D
@onready var head: MeshInstance3D = $HeadMesh
@onready var body: MeshInstance3D = $BodyMesh

# Whatever the player is holding. Fists for now, the inventory will change this later.
@onready var equipped_item: Item = $CameraController/Camera3D/Fists

@export var steam_id: int = 0
@export var steam_name: String

# Components
@export var health_component: HealthComponent

# True while a dead player is watching through this player's camera
var is_spectated: bool = false

var current_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var mouse_sensitivity: float = 0.0012
var capture_mouse: bool
var mouse_input: Vector2

var input_dir: Vector2 = Vector2.ZERO
var movement_velocity: Vector3 = Vector3.ZERO
var speed: float = 5.0
var acceleration: float = 0.2
var deceleration: float = 0.5

func _enter_tree():
	set_multiplayer_authority(name.to_int(), true)

func _ready() -> void:
	add_to_group("player")

	# Signals
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	_on_health_changed(health_component.current_health, health_component.max_health)

	if RoundManager.instance:
		RoundManager.instance.phase_changed.connect(_on_phase_changed)

	match Networking.backend:
		Networking.MultiplayerBackend.STEAM:
			steam_name_label.text = steam_name
		Networking.MultiplayerBackend.ENET:
			steam_name_label.text = str(name)
	
	if is_multiplayer_authority():
		steam_name_label.hide()
		health_label_3d.hide()
		head.hide()
		body.hide()
		health_label.show()
		crosshair.show()

		set_process_unhandled_input(is_multiplayer_authority())
		set_process(is_multiplayer_authority())
		set_physics_process(is_multiplayer_authority())
		
		camera.current = is_multiplayer_authority()
		Input.mouse_mode = current_mouse_mode
	else:
		set_process_unhandled_input(false)
		set_process(false)
		set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	capture_mouse = event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if capture_mouse:
		mouse_input.x += -event.screen_relative.x * mouse_sensitivity
		mouse_input.y += -event.screen_relative.y * mouse_sensitivity
		camera_controller.update_camera_rotation(mouse_input)

	if event.is_action_pressed("use_item"):
		equipped_item.use()

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

func _on_health_changed(current_health: int, _max_health: int) -> void:
	if is_multiplayer_authority():
		health_label.text = "HP: %s" % [ health_component.current_health ]
	health_label_3d.text = "HP: %s" % [ health_component.current_health ]

func _on_phase_changed(_phase: RoundManager.Phase) -> void:
	_update_name_tag()

# Name tags are hidden at night so nobody can tell who the werewolf is.
# Our own name tag, and the one of a player being spectated, are always hidden.
func _update_name_tag() -> void:
	var is_night: bool = RoundManager.instance and RoundManager.instance.phase == RoundManager.Phase.NIGHT
	steam_name_label.visible = not is_multiplayer_authority() and not is_spectated and not is_night

# Called by the Spectator when a dead player starts or stops watching through
# this player's eyes. Hides everything that would block or clutter the view.
func set_spectated(spectated: bool) -> void:
	is_spectated = spectated
	head.visible = not spectated
	body.visible = not spectated
	health_label_3d.visible = not spectated
	camera.current = spectated
	_update_name_tag()

func _on_died():
	if is_multiplayer_authority():
		die.rpc()

@rpc("call_local", "reliable")
func die():
	if is_multiplayer_authority():
		var level_camera: Camera3D = get_tree().get_first_node_in_group("level_camera")
		level_camera.current = true
	# Players are spawned by the host's PlayerSpawner, so only the host removes
	# them. The spawner then removes the player for everyone else.
	if multiplayer.is_server():
		queue_free()
