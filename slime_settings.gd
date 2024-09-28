# SlimeSettings.gd
class_name SlimeSettings extends Node2D

# Simulation Settings
var steps_per_frame: int
var width: int
var height: int
var num_agents: int

# Enum for spawn modes
enum SpawnMode { RANDOM, POINT, INWARD_CIRCLE, RANDOM_CIRCLE }
var spawn_mode: int

# Trail Settings
var trail_weight: float
var decay_rate: float
var diffuse_rate: float

# Species settings as an array of SpeciesSettings resources
var species_settings: Array[SpeciesSettings]

func _init(_steps_per_frame: int = 1, _width: int = 1280, _height: int = 720, _num_agents: int = 100,
           _spawn_mode: int = SpawnMode.RANDOM, _trail_weight: float = 5.0, _decay_rate: float = 1.0,
           _diffuse_rate: float = 1.0, _species_settings: Array[SpeciesSettings] = [SpeciesSettings.new()]):
    steps_per_frame = _steps_per_frame
    width = _width
    height = _height
    num_agents = _num_agents
    spawn_mode = _spawn_mode
    trail_weight = _trail_weight
    decay_rate = _decay_rate
    diffuse_rate = _diffuse_rate
    species_settings = _species_settings