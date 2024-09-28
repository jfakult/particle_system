// shader_type compute;

#[compute]
#version 460

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

struct AgentData {
    vec4 species_mask; // byte 0-15
    vec2 position;     // byte 16-23 (valid as aligned to 16 bytes)
    float angle;       // byte 24-27 (valid as aligned to 4 bytes) 
    int species_index; // byte 28-31 (valid as aligned to 4 bytes)
};
layout(set = 0, binding = 0, std430) restrict buffer AgentsBuffer {
    AgentData agents[];
} agents_buffer;

struct SpeciesData {
    float move_speed;
    float turn_speed;
    float sensor_angle;
    float sensor_offset;
    int sensor_size;
    vec4 color;
};
layout(set = 0, binding = 1, std430) restrict buffer SpeciesBuffer {
    SpeciesData species[];
} species_buffer;

layout(set=0, binding=2, rgba32f) uniform image2D trail_map;

layout(set=0, binding=3) restrict buffer ScreenSizeBuffer {
    int x;
    int y;
} screen_size;

layout(set=0, binding=4) restrict buffer FloatDataBuffer {
    float trail_weight;
    float delta_time;
    int num_agents;
} float_data;

uint hash(uint state) {
    state ^= 2747636419u;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    return state;
}

float scale_to_range_01(uint state) {
    return state / 4294967295.0;
}

/*
The sensor sits "in front of" the agent, either to the front, the left, or the right.
The sum we calculate loops over the pixels around the sensor's location.
Dot product tests how close the color of that pixel is to the agents color
*/
float sense(AgentData agent, SpeciesData species, float sensor_angle_offset) {
    // Calculate the sensor angle and direction
    float sensor_angle = agent.angle + sensor_angle_offset;
    vec2 sensor_dir = vec2(cos(sensor_angle), sin(sensor_angle));

    // Calculate the sensor position by offsetting the agent's position
    vec2 sensor_pos = agent.position + sensor_dir * species.sensor_offset;
    // Sensor center in integer coordinates
    int sensor_center_x = int(sensor_pos.x);
    int sensor_center_y = int(sensor_pos.y);

    // Initialize the sum to accumulate trail values
    float sum = 0.0;

    vec4 sense_weight = agent.species_mask * 2.0 - 1.0;

    // Iterate over the grid around the sensor position
    for (int offset_x = -species.sensor_size; offset_x <= species.sensor_size; offset_x++) {
        for (int offset_y = -species.sensor_size; offset_y <= species.sensor_size; offset_y++) {
            // Calculate sample positions, clamping them within bounds
            int sample_x = min(screen_size.x - 1, max(0, sensor_center_x + offset_x));
            int sample_y = min(screen_size.y - 1, max(0, sensor_center_y + offset_y));

            // Sum the weighted trail values using the species mask
            sum += dot( sense_weight, imageLoad(trail_map, ivec2(sample_x, sample_y)) );
        }
    }

    return sum;
}

void dot(float x, float y, vec4 col, int size)
{
    for (float x1 = x - size; x1 < x + size; x1++)
    {
        for (float y1 = y - size; y1 < y + size; y1++)
        {
            imageStore(trail_map, ivec2(x1, y1), col);
        }
    }
}

void main() {
    uint id = gl_GlobalInvocationID.x;

    if (id >= float_data.num_agents)
    {
        return;
    }

    AgentData agent = agents_buffer.agents[id];

    // dot(agent.position.x, agent.position.y, vec4(0,1,0,1), 1);

    int species_index = agent.species_index;
    vec4 species_mask = agent.species_mask;
    SpeciesData species = species_buffer.species[0];

    uint random = hash(uint(agent.position.y * screen_size.x + agent.position.x + hash(id + uint(float_data.delta_time * 100000.0))));

    float sensor_angle = species.sensor_angle;
    float forward_weight = sense(agent, species, 0.0);
    float left_weight = sense(agent, species, sensor_angle);
    float right_weight = sense(agent, species, -sensor_angle);

    float random_steer_strength = scale_to_range_01(random);
    float turn_speed = species.turn_speed * 2.0 * 3.1415;

    if (forward_weight > left_weight && forward_weight > right_weight) {
        agent.angle += 0.0;
    }
    else if (left_weight > right_weight) {
        agent.angle += random_steer_strength * turn_speed * float_data.delta_time;
    }
    else if (right_weight > left_weight) {
        agent.angle -= random_steer_strength * turn_speed * float_data.delta_time;
    }
    else { // (forward_weight < left_weight && forward_weight < right_weight)
		agent.angle += (random_steer_strength - 0.5) * 2 * turn_speed * float_data.delta_time;
	}

    vec2 direction = vec2(cos(agent.angle), sin(agent.angle));
    vec2 new_pos = agent.position + direction * species.move_speed * float_data.delta_time;

    // Update the trail map
    ivec2 coord = ivec2(new_pos);
    vec4 old_trail = imageLoad(trail_map, coord);
    vec4 new_trail = min(vec4(1.0), old_trail + species_mask * float_data.trail_weight * float_data.delta_time);
    //new_trail = vec4(1, 1, 1, 1);

    if (new_pos.x < 0.0 || new_pos.x >= screen_size.x || new_pos.y < 0.0 || new_pos.y >= screen_size.y) {
        random = hash(random);
        float random_angle = scale_to_range_01(random) * 2.0 * 3.1415;
        agent.angle = random_angle;
        new_pos = clamp(new_pos, vec2(0.0), vec2(screen_size.x, screen_size.y));
    }

    imageStore(trail_map, coord, new_trail);

    if (new_pos.x < 0) { new_pos.x = 100; }
    else if (new_pos.x > screen_size.x ) { new_pos.x = screen_size.x - 100; }
    if (new_pos.y < 0) { new_pos.y = 100; }
    else if (new_pos.y > screen_size.y ) { new_pos.y = screen_size.y - 100; }

    agent.position = new_pos;

    agents_buffer.agents[id] = agent;
}