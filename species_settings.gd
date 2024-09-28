# SpeciesSettings.gd
class_name SpeciesSettings extends Resource 

# Movement Settings
var move_speed: float
var turn_speed: float

# Sensor Settings
var sensor_angle_spacing: float
var sensor_offset_dst: float
var sensor_size: int

# Display Settings
var colour: Vector4

# Things that work somewhat well:
'''
move_speed : turn_speed ~= 100 : 1.5
'''
func _init(_move_speed: float = 100.0, _turn_speed: float = 1.5, _sensor_angle_spacing: float = PI / 6,
           _sensor_offset_dst: float = 6.0, _sensor_size: int = 3, _colour: Vector4 = Vector4(0, 1, 1, 1)):
    move_speed = _move_speed
    turn_speed = _turn_speed
    sensor_angle_spacing = _sensor_angle_spacing
    sensor_offset_dst = _sensor_offset_dst
    sensor_size = _sensor_size
    colour = _colour