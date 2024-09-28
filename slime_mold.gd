extends ColorRect

var show_agents_only = false
#var GameSettings = preload("res://path_to_your_GameSettings.gd").new()

var IMAGE_PRECISION = Image.FORMAT_RGBAH
var TEXTURE_BUFFER_PRECISION = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
var AGENT_DISPATCH_SIZE = 512

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
var agent_uniform_set: RID
var diffuse_uniform_set: RID
var agents_uniform: RDUniform
var species_uniform: RDUniform
var trail_map_image: Image
var trail_map_uniform: RDUniform
var trail_map_texture
var screen_size_uniform: RDUniform
var floats_uniform: RDUniform

var agents: Array = []

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

func init_agent(center):
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

	return {
		"species_mask": species_mask,
		"position": start_pos,
		"angle": angle,
		"species_index": species_index,
		"confusion_timer": 0.0
	}

func init_agents():
	if len(agents) == 0 or GameSettings.slime_settings.num_agents != len(agents):
		if len(agents) > 0:
			print("Pulling new data")
			# Pull agent data from the compute buffer and rebuild the agent list
			var agents_data = rd.buffer_get_data(shader_agents_buffer)
			agents = []
			var data_pos = 0
			while data_pos < agents_data.size():
				var species_mask = Vector4(agents_data.decode_float(data_pos), agents_data.decode_float(data_pos + 4), agents_data.decode_float(data_pos + 8), agents_data.decode_float(data_pos + 12))
				var position = Vector2(agents_data.decode_float(data_pos + 16), agents_data.decode_float(data_pos + 20))
				var angle = agents_data.decode_float(data_pos + 24)
				var species_index = agents_data.decode_float(data_pos + 28)
				var confusion_timer = agents_data.decode_float(data_pos + 32)
				agents.append({
					"species_mask": species_mask,
					"position": position,
					"angle": angle,
					"species_index": species_index,
					"confusion_timer": confusion_timer
				})
				# Agent blocks are 48 bytes long because of padding
				data_pos += 48
			# todo: pull agent data back out and rebuild it

		init_agents_wrapper()
		var agents_list = []
		for agent in agents:
			# Note that the order of these values must match the order in the shader
			# Notes in shader explain the packing process / byte alignment
			agents_list.append(agent["species_mask"])
			agents_list.append(agent["position"])
			agents_list.append(agent["angle"])
			agents_list.append(agent["species_index"])
			agents_list.append(agent["confusion_timer"])
			agents_list.append(0.0) # padding
			agents_list.append(0.0) # padding
			agents_list.append(0.0) # padding

			#if len(agents_list) == 6:
			#	print("Length", pack_array_data(agents_list).size())


		shader_agents_buffer = pack_array(agents_list)

func init_agents_wrapper():
	# Initialize agents
	var center = Vector2(GameSettings.slime_settings.width / 2.0, GameSettings.slime_settings.height / 2.0)

	print("Settings: ", GameSettings.slime_settings.num_agents, " vs ", len(agents))

	if GameSettings.slime_settings.num_agents < len(agents):
		agents.resize(GameSettings.slime_settings.num_agents)
	else: # GameSettings.slime_settings.num_agents > len(agents):
		# Add new agents
		while len(agents) < GameSettings.slime_settings.num_agents:
			var agent = init_agent(center)
			agents.append(agent)

func build_shader_buffer(buffer, uniform_type, binding):
	var uniform := RDUniform.new()
	uniform.uniform_type = uniform_type
	uniform.binding = binding # this needs to match the "binding" in our shader file
	uniform.add_id(buffer)

	return uniform

# On ready
func _ready():
	set_physics_process(false)

	# Create render textures
	# https://github.com/godotengine/godot-docs/issues/4834
	var fmt = RDTextureFormat.new()
	fmt.width = GameSettings.slime_settings.width
	fmt.height = GameSettings.slime_settings.height
	# Data formats: https://docs.godotengine.org/en/stable/classes/class_renderingdevice.html
	fmt.format = TEXTURE_BUFFER_PRECISION
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	# Image texture formats: https://docs.godotengine.org/en/stable/classes/class_image.html
	trail_map_image = Image.create(GameSettings.slime_settings.width, GameSettings.slime_settings.height, false, IMAGE_PRECISION)
	trail_map_image.fill(Color(0.0, 0.0, 0.0, 1))
	trail_map_texture = rd.texture_create(fmt, RDTextureView.new(), [trail_map_image.get_data()])

	#var diffused_trail_image : Image = Image.create(GameSettings.slime_settings.width, GameSettings.slime_settings.height, false, IMAGE_PRECISION)
	#diffused_trail_map = ImageTexture.create_from_image(diffused_trail_image)

	#var display_image : Image = Image.create(GameSettings.slime_settings.width, GameSettings.slime_settings.height, false, IMAGE_PRECISION)
	#display_texture = ImageTexture.create_from_image(display_image)

	var shader_file = load("res://slime.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	agents_shader = rd.shader_create_from_spirv(shader_spirv)
	var shader_file2 = load("res://diffuse_map.glsl")
	var shader_spirv2: RDShaderSPIRV = shader_file2.get_spirv()
	diffuse_shader = rd.shader_create_from_spirv(shader_spirv2)
	
	init_agents()

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
	init_agents()
		
	for i in range(GameSettings.slime_settings.steps_per_frame):
		run_simulation(delta)

func rebuild_shader_buffers(delta: float):
	var species_settings_list = []
	for species in GameSettings.slime_settings.species_settings:
		species_settings_list.append(species.colour)
		species_settings_list.append(species.move_speed)
		species_settings_list.append(species.turn_speed)
		species_settings_list.append(species.random_steer_strength)
		species_settings_list.append(species.sensor_angle_spacing)
		species_settings_list.append(species.sensor_offset_dst)
		species_settings_list.append(species.sensor_size)
		species_settings_list.append(species.confusion_chance)
		species_settings_list.append(species.confusion_timeout)

		#if len(species_settings_list) == 9:
		#	print("Length", pack_array_data(species_settings_list).size())

	var species_buffer = pack_array(species_settings_list)
	species_uniform = build_shader_buffer(species_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)

	# Update delta time uniform
	var float_data = [GameSettings.slime_settings.trail_weight, delta, GameSettings.slime_settings.diffuse_rate, GameSettings.slime_settings.decay_rate, GameSettings.slime_settings.num_agents]
	var float_buffer = pack_array(float_data)
	floats_uniform = build_shader_buffer(float_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)

	agents_uniform = build_shader_buffer(shader_agents_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)

	#rd.texture_update(trail_map_texture, 0, trail_map_image.get_data())

	# Create the uniform set
	agent_uniform_set = rd.uniform_set_create([
		agents_uniform,
		species_uniform,
		trail_map_uniform,
		screen_size_uniform,
		floats_uniform
	], agents_shader, 0)


	diffuse_uniform_set = rd.uniform_set_create([
		trail_map_uniform,
		screen_size_uniform,
		floats_uniform
	], diffuse_shader, 0)

func run_agents_compute():
	compute_list = rd.compute_list_begin()

	rd.compute_list_bind_uniform_set(compute_list, agent_uniform_set, 0)
	rd.compute_list_bind_compute_pipeline(compute_list, agents_pipeline)
	rd.compute_list_dispatch(compute_list, ceil(GameSettings.slime_settings.num_agents / AGENT_DISPATCH_SIZE) + 1, 1, 1)

	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

func run_diffuse_compute():
	compute_list = rd.compute_list_begin()

	rd.compute_list_bind_uniform_set(compute_list, diffuse_uniform_set, 0)
	rd.compute_list_bind_compute_pipeline(compute_list, diffuse_pipeline)
	rd.compute_list_dispatch(compute_list, ceil(GameSettings.slime_settings.width / 16.0), ceil(GameSettings.slime_settings.height / 16.0), 1)

	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()

func send_texture_to_colorrect_shader():
	var byte_data = rd.texture_get_data(trail_map_texture, 0)
	# Image texture formats: https://docs.godotengine.org/en/stable/classes/class_image.html
	var image = Image.create_from_data(GameSettings.slime_settings.width, GameSettings.slime_settings.height, false, IMAGE_PRECISION, byte_data)
	var image_texture = ImageTexture.create_from_image(image)
	material.set_shader_parameter("trail_map", image_texture)

# Run a single step of the simulation
func run_simulation(delta: float):
	rebuild_shader_buffers(delta)

	# Dispatch compute shader, device limit is 65535

	run_agents_compute()

	run_diffuse_compute()

	#var agent_byte_data = rd.buffer_get_data(shader_agents_buffer)
	#var first_agent_pos : Vector2 = Vector2(agent_byte_data.decode_float(0), agent_byte_data.decode_float(4))
	#var second_agent_pos : Vector2 = Vector2(agent_byte_data.decode_float(32), agent_byte_data.decode_float(36))
	#print(first_agent_pos, second_agent_pos)

	send_texture_to_colorrect_shader()
