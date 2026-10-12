class_name Fists extends Item

# What every player can always fall back to. Punches whoever is in front of
# the camera, within the RayCast3D's reach.
#
# The attacker's machine decides if a punch hits, since only it knows exactly
# where the player was aiming. HealthComponent.damage() then sends the damage
# to whoever owns the victim's health.

const PUNCH_DISTANCE: float = 0.4
const PUNCH_OUT_TIME: float = 0.08
const PUNCH_BACK_TIME: float = 0.15

@export var damage: int = 10
@export var cooldown: float = 1.0

@onready var fist_mesh: MeshInstance3D = $FistMesh
@onready var raycast: RayCast3D = $RayCast3D
@onready var cooldown_timer: Timer = $CooldownTimer

var fist_rest_position: Vector3

func _ready() -> void:
	fist_rest_position = fist_mesh.position

func use() -> void:
	if not cooldown_timer.is_stopped(): return
	cooldown_timer.start(cooldown)

	_play_punch_animation.rpc()

	# The ray is disabled in the scene so it doesn't check every frame. Instead
	# it's updated only when punching. It starts inside our own body, which
	# rays ignore, so it can't hit ourselves.
	raycast.force_raycast_update()
	var hit_player: Player = raycast.get_collider() as Player
	if hit_player:
		Log.debug("Fists.use() -> hit %s for %s" % [hit_player.name, damage])
		hit_player.health_component.damage(damage)

# Owner -> Everyone
# Purely visual, so "unreliable" is fine: if a packet is lost, someone
# just misses seeing one punch.
@rpc("call_local", "unreliable")
func _play_punch_animation() -> void:
	var punched_position: Vector3 = fist_rest_position + Vector3(0, 0, -PUNCH_DISTANCE)
	var tween: Tween = create_tween()
	tween.tween_property(fist_mesh, "position", punched_position, PUNCH_OUT_TIME)
	tween.tween_property(fist_mesh, "position", fist_rest_position, PUNCH_BACK_TIME)
