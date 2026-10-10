extends WorldEnvironment

# Very simple day/night lighting: fades the sun and overall exposure
# whenever the RoundManager changes phase.

const DAY_EXPOSURE: float = 1.0
const NIGHT_EXPOSURE: float = 0.15
const DAY_SUN_ENERGY: float = 1.0
const NIGHT_SUN_ENERGY: float = 0.1
const FADE_TIME: float = 3.0

@onready var sun: DirectionalLight3D = $DirectionalLight3D

func _ready() -> void:
	# NOTE - The Environment resource is shared and stays loaded between matches,
	#        so reset it here or a match could start dark if the last one ended at night
	environment.tonemap_exposure = DAY_EXPOSURE
	sun.light_energy = DAY_SUN_ENERGY

	if RoundManager.instance:
		RoundManager.instance.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: RoundManager.Phase) -> void:
	var is_night: bool = phase == RoundManager.Phase.NIGHT

	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(environment, "tonemap_exposure", NIGHT_EXPOSURE if is_night else DAY_EXPOSURE, FADE_TIME)
	tween.tween_property(sun, "light_energy", NIGHT_SUN_ENERGY if is_night else DAY_SUN_ENERGY, FADE_TIME)
