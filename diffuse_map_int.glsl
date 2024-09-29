// shader_type compute;

#[compute]
#version 460

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

/*
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
*/

layout(set=0, binding=2, rgba8ui) uniform image2D trail_map;

layout(set=0, binding=3) restrict buffer ScreenSizeBuffer {
    int x;
    int y;
} screen_size;

layout(set=0, binding=4) restrict buffer FloatDataBuffer {
    float trail_weight;
    float delta_time;
    float diffuse_rate;
    float decay_rate;
    int num_agents;
} float_data;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y);
    if (pos.x > screen_size.x || pos.x < 0 || pos.y > screen_size.y || pos.y < 0)
    {
        return;
    }

    vec4 sum = vec4(0);
	vec4 originalCol = imageLoad(trail_map, pos);
	// 3x3 blur
	for (int offsetX = -1; offsetX <= 1; offsetX ++) {
		for (int offsetY = -1; offsetY <= 1; offsetY ++) {
			int sampleX = min(screen_size.x-1, max(0, pos.x + offsetX));
			int sampleY = min(screen_size.y-1, max(0, pos.y + offsetY));
			sum += imageLoad(trail_map, ivec2(sampleX, sampleY));
		}
	}

	vec4 blurredCol = sum / 9;
	float diffuseWeight = clamp(float_data.diffuse_rate * float_data.delta_time, 0.0, 1.0);
	blurredCol = originalCol * (1 - diffuseWeight) + blurredCol * (diffuseWeight);

	//DiffusedTrailMap[id.xy] = blurredCol * clamp(1 - float_data.decay_rate * float_data.delta_time, 0.0, 1.0);
	imageStore(trail_map, pos, blurredCol * vec4(float_data.decay_rate, float_data.decay_rate, float_data.decay_rate, 1)); //max(0, blurredCol * float_data.decay_rate * float_data.delta_time));
}