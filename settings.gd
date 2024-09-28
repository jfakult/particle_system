extends Panel

var panel_scale = 0.6667

func add_slider_with_label(parent: Control, label_text: String, initial_value: float, min_value: float, max_value: float, step: float, y: float) -> void:
	# Create a horizontal container for the label and slider
	var hbox = HBoxContainer.new()

	# Set the position of the horizontal container
	hbox.position = Vector2(10, y)

	# Create the label
	var label = Label.new()
	label.text = label_text

	var value_label = Label.new()
	# give it an id
	value_label.name = "label_" + label_text
	value_label.text = " (" + nice_num(initial_value) + ")"

	# Create the slider
	var slider = HSlider.new()
	slider.position.x = 100
	slider.custom_minimum_size.x = 200
	slider.value = initial_value
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step

	slider.value_changed.connect(_on_slider_value_changed.bind(label_text, value_label))

	# Add label and slider to the horizontal container
	hbox.add_child(slider)
	hbox.add_child(label)
	hbox.add_child(value_label)

	# Add the horizontal container to the parent node
	parent.add_child(hbox)

func _on_slider_value_changed(value: float, label_text: String, value_label: Label) -> void:
	GameSettings[label_text] = value

	value_label.text = " (" + nice_num(value) + ")"

func nice_num(num: float) -> String:
	return str(snapped(num, 0.01))

func _ready():
	set_physics_process(false)

	# Call the function to add a slider with a label to the current node (e.g., a Control node)
	var sliders = {
		# name :  [ initial_value, min_value, max_value, step ]
		"num_agents": [ GameSettings.num_agents, 10, 250010, 1000 ],
		"trail_weight": [ GameSettings.trail_weight, 0, 200, 0.05 ],
		"decay_rate": [ GameSettings.decay_rate, 0.7, 1.0004, 0.004 ],
		"diffuse_rate": [ GameSettings.diffuse_rate, 0, 100, 1 ],
		"confusion_chance": [ GameSettings.confusion_chance, 0, 10, 0.1 ],
		"confusion_timeout": [ GameSettings.confusion_timeout, 0, 10, 0.1 ],
		"move_speed": [ GameSettings.move_speed, 1, 1000, 10 ],
		"turn_speed": [ GameSettings.turn_speed, 0, 5, 0.1 ],
		"random_steer_strength": [ GameSettings.random_steer_strength, 0, 10, 0.1 ],
		"sensor_angle_spacing": [ GameSettings.sensor_angle_spacing, 0, 2 * PI, PI / 30 ],
		"sensor_offset_dst": [ GameSettings.sensor_offset_dst, 0, 20, 1 ],
		"sensor_size": [ GameSettings.sensor_size, 0, 6, 1 ]
	}

	scale = Vector2.ONE * panel_scale
	size.y = 30 * (len(sliders) + 1)
	position.y = GameSettings.slime_settings.height - (size.y * panel_scale)

	var max_key_length = 0
	for slider_name in sliders:
		if len(slider_name) > max_key_length:
			max_key_length = len(slider_name)


	var y = 20
	for slider_name in sliders:
		var slider_data = sliders[slider_name]
		add_slider_with_label(self, slider_name, slider_data[0], slider_data[1], slider_data[2], slider_data[3], y)

		y += 30
