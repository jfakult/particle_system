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

func _init(_move_speed: float = 150.0, _turn_speed: float = 1.0, _sensor_angle_spacing: float = 1.0,
           _sensor_offset_dst: float = 1.0, _sensor_size: int = 1, _colour: Vector4 = Vector4(0, 1, 1, 1)):
    move_speed = _move_speed
    turn_speed = _turn_speed
    sensor_angle_spacing = _sensor_angle_spacing
    sensor_offset_dst = _sensor_offset_dst
    sensor_size = _sensor_size
    colour = _colour