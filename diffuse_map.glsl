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

    if (pos.x >= (buffer_data.screen_size.x) || pos.x < 0 || pos.y >= (buffer_data.screen_size.y) || pos.y < 0)
    {
        return;
    }

    // Special handling for the boundaries. A bit fancy but basically just handles edges as you would expect
    // Cleaner than having an if in each loop iteration of the blur
    int minX = pos.x - blur_size;
    int maxX = pos.x + blur_size;
    int minY = pos.y - blur_size;
    int maxY = pos.y + blur_size;
    /*if (pos.x >= (buffer_data.screen_size.x - blur_size))
    {
        maxX = (buffer_data.screen_size.x - blur_size) - 1;
    }
    else if (pos.x < blur_size)
    {
        minX = 0;
    }
    if (pos.y >= (buffer_data.screen_size.y - blur_size))
    {
        maxY = (buffer_data.screen_size.y - blur_size);
    }
    else if (pos.y < blur_size)
    {
        minY = 0;
    }*/

    vec4 sum = vec4(0);
	vec4 originalCol = imageLoad(trail_map, pos);
	for (int offsetX = minX; offsetX <= maxX; offsetX++) {
		for (int offsetY = minY; offsetY <= maxY; offsetY++) {
			sum += imageLoad(trail_map, ivec2(offsetX, offsetY));
		}
	}

    // Divide the total by number of blurs, but make sure opacity it maxed in case of reads off the edge of the image
	vec4 blurredCol = sum / pow(blur_size * 2 + 1, 2) + vec4(0, 0, 0, 1);
	float diffuseWeight = clamp(buffer_data.diffuse_rate * buffer_data.delta_time, 0.0, 1.0);
	blurredCol = originalCol * (1 - diffuseWeight) + blurredCol * (diffuseWeight);

	//DiffusedTrailMap[id.xy] = blurredCol * clamp(1 - buffer_data.decay_rate * buffer_data.delta_time, 0.0, 1.0);
	imageStore(trail_map, pos, blurredCol * vec4(buffer_data.decay_rate, buffer_data.decay_rate, buffer_data.decay_rate, 1));
}