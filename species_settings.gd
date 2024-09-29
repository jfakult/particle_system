# SpeciesSettings.gd
class_name SpeciesSettings extends Resource 

@export

# Movement Settings
var move_speed: float
var turn_speed: float
var random_steer_strength: float

# Sensor Settings
var sensor_angle_spacing: float
var sensor_offset_dst: float
var sensor_size: int

# Other Settings
var confusion_chance: float
var confusion_timeout: float

# Display Settings
var colour: Vector4

# Things that work somewhat well:
'''
move_speed : turn_speed ~= 100 : 1.5
'''
func _init(_move_speed: float = 100.0, _turn_speed: float = 2.0, _random_steer_strength: float = 5.0,
           _sensor_angle_spacing: float = PI / 6, _sensor_offset_dst: float = 5.0, _sensor_size: int = 2,
           _confusion_chance: float = 0.1, _confusion_timeout: float = 0.1, _colour: Vector4 = Vector4(0.6, 0.5, 1, 1)):
    move_speed = _move_speed
    turn_speed = _turn_speed
    random_steer_strength = _random_steer_strength
    sensor_angle_spacing = _sensor_angle_spacing
    sensor_offset_dst = _sensor_offset_dst
    sensor_size = _sensor_size
    confusion_chance = _confusion_chance
    confusion_timeout = _confusion_timeout
    colour = _colour