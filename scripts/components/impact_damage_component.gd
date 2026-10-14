class_name ImpactDamageComponent extends Node

# Makes a physics prop hurt whatever it hits after being thrown.
#   damage = (speed - min_speed) * damage_per_speed * mass, up to max_damage
# So only fast props hurt, and heavier props hurt more. Speed is in m/s, mass in kg.
#
# Only the prop's owner checks for hits. The owner runs the prop's physics,
# while everyone else's copy is frozen and just follows the synced position.
# The owner is whoever grabbed it last, which is why a prop never hurts its thrower.
# The damage then reaches the victim the usual way (HealthComponent.damage()).

@export var rigid_body: RigidBody3D
@export var interaction_component: InteractionComponent # Held props don't hurt anyone, only thrown ones
@export var min_speed: float = 6.0 # Slower than this does nothing, so dropping or nudging a prop is harmless
@export var damage_per_speed: float = 7.5 # Per m/s above min_speed, per kg. A 1 kg prop at full throw speed does 100.
@export var max_damage: int = 100

# The speed before this physics frame's collisions, which slow the prop down
var speed: float = 0.0

func _ready() -> void:
	Log.debug("ImpactDamageComponent._ready()")
	# The prop only reports what it touches with these on
	rigid_body.contact_monitor = true
	rigid_body.max_contacts_reported = 4
	# Fast props could otherwise pass straight through a player between two physics frames
	rigid_body.continuous_cd = true
	rigid_body.body_entered.connect(_on_body_entered)

# Runs before the physics step, so this is the speed it hits things at
func _physics_process(_delta: float) -> void:
	speed = rigid_body.linear_velocity.length()

func _on_body_entered(body: Node) -> void:
	Log.debug("ImpactDamageComponent._on_body_entered()")
	if not rigid_body.is_multiplayer_authority(): return
	if interaction_component and interaction_component.is_held: return
	if speed < min_speed: return

	var health: HealthComponent = HealthComponent.find_on(body)
	if health == null: return
	# The thrower owns the prop, so this skips their own player
	if body is Player and body.peer_id == rigid_body.get_multiplayer_authority(): return

	var damage: int = mini(roundi((speed - min_speed) * damage_per_speed * rigid_body.mass), max_damage)
	Log.info("%s hit %s at %.1f m/s for %d damage" % [rigid_body.name, body.name, speed, damage])
	health.damage(damage)
