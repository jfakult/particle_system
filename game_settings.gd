extends Node

var slime_settings: SlimeSettings = SlimeSettings.new()

var num_agents: int = slime_settings.num_agents
var trail_weight: float = slime_settings.trail_weight
var decay_rate: float = slime_settings.decay_rate
var diffuse_rate: float = slime_settings.diffuse_rate
var move_speed: float = slime_settings.species_settings[0].move_speed
var turn_speed: float = slime_settings.species_settings[0].turn_speed
var random_steer_strength: float = slime_settings.species_settings[0].random_steer_strength
var sensor_angle_spacing: float = slime_settings.species_settings[0].sensor_angle_spacing
var sensor_offset_dst: float = slime_settings.species_settings[0].sensor_offset_dst
var sensor_size: int = slime_settings.species_settings[0].sensor_size
var colour: Vector4 = slime_settings.species_settings[0].colour

func update_settings():
    var species_settings = SpeciesSettings.new(move_speed, turn_speed, random_steer_strength, sensor_angle_spacing, sensor_offset_dst, sensor_size, colour)
    var species_settings_list : Array[SpeciesSettings] = [species_settings]
    slime_settings = SlimeSettings.new(slime_settings.steps_per_frame, slime_settings.width, slime_settings.height, num_agents, slime_settings.spawn_mode, trail_weight, decay_rate, diffuse_rate, species_settings_list)
