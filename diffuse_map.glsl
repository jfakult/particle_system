// shader_type compute;

#[compute]
#version 460

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set=0, binding=2, rgba16f) uniform image2D trail_map;

layout(set=0, binding=3) restrict buffer OtherDataBuffer {
    ivec2 screen_size;
    ivec2 shape_size;
    float trail_weight;
    float delta_time;
    float diffuse_rate;
    float decay_rate;
    
    // Next chunk of 16
    int num_agents;
    float padding1;
    float padding2;
    float padding3;
} buffer_data;


int blur_size = 1;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y);
    if (pos.x >= (buffer_data.screen_size.x - blur_size) || 
        (pos.x < blur_size) ||
        (pos.y >= (buffer_data.screen_size.y - blur_size)) ||
        (pos.y < blur_size))
    {
        //imageStore(trail_map, pos, vec4(1,1,1,1));
        return;
    }

    vec4 sum = vec4(0);
	vec4 originalCol = imageLoad(trail_map, pos);
	for (int offsetX = -blur_size; offsetX <= blur_size; offsetX ++) {
		for (int offsetY = -blur_size; offsetY <= blur_size; offsetY ++) {
			sum += imageLoad(trail_map, ivec2(pos.x + offsetX, pos.y + offsetY));
		}
	}

    // Divide the total by number of blurs, but make sure opacity it maxed in case of reads off the edge of the image
	vec4 blurredCol = sum / pow(blur_size * 2 + 1, 2); // + vec4(0, 0, 0, 1);
	float diffuseWeight = clamp(buffer_data.diffuse_rate * buffer_data.delta_time, 0.0, 1.0);
	blurredCol = originalCol * (1 - diffuseWeight) + blurredCol * (diffuseWeight);

	//DiffusedTrailMap[id.xy] = blurredCol * clamp(1 - buffer_data.decay_rate * buffer_data.delta_time, 0.0, 1.0);
	imageStore(trail_map, pos, blurredCol * vec4(buffer_data.decay_rate, buffer_data.decay_rate, buffer_data.decay_rate, 1));
}