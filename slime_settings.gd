# SlimeSettings.gd
class_name SlimeSettings extends Resource

# Simulation Settings
var steps_per_frame: int
var width: int
var height: int
var num_agents: int

# Enum for spawn modes
enum SpawnMode { RANDOM, POINT, INWARD_CIRCLE, INWARD_SQUARE, RANDOM_CIRCLE }
var spawn_mode: int

# Trail Settings
var trail_weight: float
var decay_rate: float
var diffuse_rate: float

# Other Settings
var confusion_chance: float
var confusion_timeout: float

# Species settings as an array of SpeciesSettings resources
var species_settings: Array[SpeciesSettings]

func _init(_steps_per_frame: int = 1, _width: int = 1280, _height: int = 800, _num_agents: int = 10000,
           _spawn_mode: int = SpawnMode.INWARD_CIRCLE, _trail_weight: float = 10.6, _decay_rate: float = 0.99,
           _diffuse_rate: float = 20.0, _species_settings: Array[SpeciesSettings] = [SpeciesSettings.new()]):
    steps_per_frame = _steps_per_frame
    width = _width
    height = _height
    num_agents = _num_agents
    spawn_mode = _spawn_mode
    trail_weight = _trail_weight
    decay_rate = _decay_rate
    diffuse_rate = _diffuse_rate
    species_settings = _species_settings