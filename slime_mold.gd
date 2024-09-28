extends ColorRect

var show_agents_only = false
#var GameSettings = preload("res://path_to_your_GameSettings.gd").new()

var trail_map: ImageTexture
var diffused_trail_map: ImageTexture
var display_texture: ImageTexture

var rd = RenderingServer.create_local_rendering_device()
var compute_list

var agents_shader
var diffuse_shader
var agents_pipeline
var diffuse_pipeline

var shader_agents_buffer
var agents_uniform: RDUniform
var species_uniform: RDUniform
var trail_map_image: Image
var trail_map_uniform: RDUniform
var trail_map_texture
var screen_size_uniform: RDUniform
var floats_uniform: RDUniform


func pack_array(data):
	var packed_bytes = pack_array_data(data)
	return rd.storage_buffer_create(packed_bytes.size(), packed_bytes)

func pack_array_data(data):
	var packed_bytes = PackedByteArray()

	for value in data:
		match typeof(value):
			TYPE_FLOAT:
				packed_bytes.append_array(PackedFloat32Array([value]).to_byte_array())
			TYPE_INT:
				packed_bytes.append_array(PackedInt32Array([value]).to_byte_array())
			TYPE_VECTOR2:
				packed_bytes.append_array(PackedVector2Array([value]).to_byte_array())
			TYPE_VECTOR3:
				packed_bytes.append_array(PackedVector3Array([value]).to_byte_array())
			TYPE_VECTOR4:
				packed_bytes.append_array(PackedVector4Array([value]).to_byte_array())
			TYPE_ARRAY:
				packed_bytes.append_array(pack_array_data(value))
			TYPE_DICTIONARY:
				# Only append values
				var values = []
				for key in value.keys():
					values.append(value[key])
				packed_bytes.append_array(pack_array_data(values))

	return packed_bytes

func init_agents():
	var agents = []
	# Initialize agents
	var center = Vector2(GameSettings.slime_settings.width / 2.0, GameSettings.slime_settings.height / 2.0)
	for i in range(GameSettings.slime_settings.num_agents):
		var start_pos = Vector2()
		var random_angle : float = randf() * PI * 2
		var angle : float = 0.0

		match GameSettings.slime_settings.spawn_mode:
			GameSettings.slime_settings.SpawnMode.POINT:
				start_pos = center
				angle = random_angle
			GameSettings.slime_settings.SpawnMode.RANDOM:
				start_pos = Vector2(randi() % GameSettings.slime_settings.width, randi() % GameSettings.slime_settings.height)
				angle = random_angle
			GameSettings.slime_settings.SpawnMode.INWARD_CIRCLE:
				start_pos = center + (Vector2(randf() - 0.5, randf() - 0.5)) * Vector2(randf(), randf()).normalized() * (GameSettings.slime_settings.height / 2.0) 
				angle = (center - start_pos).angle()
			GameSettings.slime_settings.SpawnMode.INWARD_SQUARE:
				start_pos = center + (Vector2(randf() - 0.5, randf() - 0.5)) * (GameSettings.slime_settings.height / 2.0) 
				angle = (center - start_pos).angle()
			GameSettings.slime_settings.SpawnMode.RANDOM_CIRCLE:
				start_pos = center + Vector2(randf(), randf()).normalized() * GameSettings.slime_settings.height * 0.15
				angle = random_angle

		# Randomly assign species
		var num_species = GameSettings.slime_settings.species_settings.size()
		var species_index : int = 0
		var species_mask : Vector4 = Vector4.ONE

		if num_species == 1:
			species_mask = GameSettings.slime_settings.species_settings[0].colour
		elif num_species > 1:
			species_index = randi() % num_species
			if species_index == 0:
				species_mask = Vector4(1, 0, 0, 1)
			elif species_index == 1:
				species_mask = Vector4(0, 1, 0, 1)
			elif species_index == 2:
				species_mask = Vector4(0, 0, 1, 1)

		agents.append({
			"position": start_pos,
			"angle": angle,
			"species_mask": species_mask,
			"species_index": species_index
		})

	return agents

func build_shader_buffer(buffer, uniform_type, binding):
	var uniform := RDUniform.new()
	uniform.uniform_type = uniform_type
	uniform.binding = binding # this needs to match the "binding" in our shader file
	uniform.add_id(buffer)

	return uniform

# On ready
func _ready():
	# Create render textures
	# https://github.com/godotengine/godot-docs/issues/4834
	var fmt = RDTextureFormat.new()
	fmt.width = GameSettings.slime_settings.width
	fmt.height = GameSettings.slime_settings.height
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	trail_map_image = Image.create(GameSettings.slime_settings.width, GameSettings.slime_settings.height, false, Image.FORMAT_RGBAF)
	trail_map_image.fill(Color(0.0, 0.0, 0.0, 1))
	trail_map_texture = rd.texture_create(fmt, RDTextureView.new(), [trail_map_image.get_data()])

	var diffused_trail_image : Image = Image.create(GameSettings.slime_settings.width, GameSettings.slime_settings.height, false, Image.FORMAT_RGBAF)
	diffused_trail_map = ImageTexture.create_from_image(diffused_trail_image)

	var display_image : Image = Image.create(GameSettings.slime_settings.width, GameSettings.slime_settings.height, false, Image.FORMAT_RGBAF)
	display_texture = ImageTexture.create_from_image(display_image)

	var shader_file = load("res://slime.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	agents_shader = rd.shader_create_from_spirv(shader_spirv)
	var shader_file2 = load("res://diffuse_map.glsl")
	var shader_spirv2: RDShaderSPIRV = shader_file2.get_spirv()
	diffuse_shader = rd.shader_create_from_spirv(shader_spirv2)
	

	var agents = init_agents()
	var agents_list = []
	for agent in agents:
		# Note that the order of these values must match the order in the shader
		# Notes in shader explain the packing process / byte alignment
		agents_list.append(agent["species_mask"])
		agents_list.append(agent["position"])
		agents_list.append(agent["angle"])
		agents_list.append(agent["species_index"])

	shader_agents_buffer = pack_array(agents_list)

	#print("----", pack_array_data(agents_list).size())
	#var first_agent_pos : Vector2 = Vector2(pack_array_data(agents_list).decode_float(0), pack_array_data(agents_list).decode_float(4))
	#var second_agent_pos : Vector2 = Vector2(pack_array_data(agents_list).decode_float(32), pack_array_data(agents_list).decode_float(36))
	#print(first_agent_pos, second_agent_pos)


	# Trail map
	trail_map_uniform = build_shader_buffer(trail_map_texture, RenderingDevice.UNIFORM_TYPE_IMAGE, 2)
	# update into the shader
	rd.texture_update(trail_map_texture, 0, trail_map_image.get_data())

	# Screen size
	var screen_size_data = [GameSettings.slime_settings.width, GameSettings.slime_settings.height]
	var screen_size_buffer = pack_array(screen_size_data)
	screen_size_uniform = build_shader_buffer(screen_size_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3)

	# Create a buffer for all float values
	var float_data = [GameSettings.slime_settings.trail_weight, 0.0, GameSettings.slime_settings.num_agents]
	var float_buffer = pack_array(float_data)
	floats_uniform = build_shader_buffer(float_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)

	# Create a compute pipeline
	agents_pipeline = rd.compute_pipeline_create(agents_shader)
	diffuse_pipeline = rd.compute_pipeline_create(diffuse_shader)

	#compute_list = rd.compute_list_begin()
	#rd.compute_list_bind_compute_pipeline(compute_list, agents_pipeline)
	#rd.compute_list_bind_compute_pipeline(compute_list, diffuse_pipeline)

	var old_trail_weight = GameSettings.slime_settings.trail_weight
	GameSettings.slime_settings.trail_weight = 255.0
	run_simulation(1 / 60.0)
	GameSettings.slime_settings.trail_weight = old_trail_weight

# Main simulation loop
func _process(delta: float):
	# if less than 1 second, wait
	if Time.get_ticks_msec() < 3000:
		return

	GameSettings.update_settings()
	
	for i in range(GameSettings.slime_settings.steps_per_frame):
		run_simulation(delta)

# Run a single step of the simulation
func run_simulation(delta: float):
	var species_settings_list = []
	for species in GameSettings.slime_settings.species_settings:
		species_settings_list.append(species.move_speed)
		species_settings_list.append(species.turn_speed)
		species_settings_list.append(species.random_steer_strength)
		species_settings_list.append(species.sensor_angle_spacing)
		species_settings_list.append(species.sensor_offset_dst)
		species_settings_list.append(species.sensor_size)
		species_settings_list.append(species.colour)

	var species_buffer = pack_array(species_settings_list)
	species_uniform = build_shader_buffer(species_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)

	# Update delta time uniform
	var float_data = [GameSettings.slime_settings.trail_weight, delta, GameSettings.slime_settings.diffuse_rate, GameSettings.slime_settings.decay_rate, GameSettings.slime_settings.num_agents]
	var float_buffer = pack_array(float_data)
	floats_uniform = build_shader_buffer(float_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)

	agents_uniform = build_shader_buffer(shader_agents_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)

	#rd.texture_update(trail_map_texture, 0, trail_map_image.get_data())

	# Create the uniform set
	var uniform_set = rd.uniform_set_create([
		agents_uniform,
		species_uniform,
		trail_map_uniform,
		screen_size_uniform,
		floats_uniform
	], agents_shader, 0)


	var uniform_set2 = rd.uniform_set_create([
		trail_map_uniform,
		screen_size_uniform,
		floats_uniform
	], diffuse_shader, 0)

	# Dispatch compute shader, device limit is 65535

	compute_list = rd.compute_list_begin()

	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_bind_compute_pipeline(compute_list, agents_pipeline)
	rd.compute_list_dispatch(compute_list, ceil(GameSettings.slime_settings.num_agents / 128.0), 1, 1)

	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

	compute_list = rd.compute_list_begin()

	rd.compute_list_bind_uniform_set(compute_list, uniform_set2, 0)
	rd.compute_list_bind_compute_pipeline(compute_list, diffuse_pipeline)
	rd.compute_list_dispatch(compute_list, ceil(GameSettings.slime_settings.width / 16.0), ceil(GameSettings.slime_settings.height / 16.0), 1)

	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()


	#var agent_byte_data = rd.buffer_get_data(shader_agents_buffer)
	#var first_agent_pos : Vector2 = Vector2(agent_byte_data.decode_float(0), agent_byte_data.decode_float(4))
	#var second_agent_pos : Vector2 = Vector2(agent_byte_data.decode_float(32), agent_byte_data.decode_float(36))
	#print(first_agent_pos, second_agent_pos)


	# Read the texture and send it to the colorRect's shader for display
	var byte_data = rd.texture_get_data(trail_map_texture, 0)
	var image = Image.create_from_data(GameSettings.slime_settings.width, GameSettings.slime_settings.height, false, Image.FORMAT_RGBAF, byte_data)
	var image_texture = ImageTexture.create_from_image(image)
	material.set_shader_parameter("trail_map", image_texture)