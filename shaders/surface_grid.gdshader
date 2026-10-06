shader_type spatial;

// Metre-accurate grid drawn in object space, so it stays aligned to the
// surface and unstretched however the node is rotated or scaled.

uniform vec3 base_color : source_color = vec3(0.6, 0.6, 0.6);
uniform vec3 alt_color : source_color = vec3(0.55, 0.55, 0.55);
uniform vec3 line_color : source_color = vec3(0.3, 0.3, 0.3);
uniform vec3 dot_color : source_color = vec3(0.2, 0.2, 0.2);
uniform float cell_size = 1.0;
uniform float line_width = 0.02;
uniform float dot_spacing = 0.0;
uniform float dot_radius = 0.03;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.9;

varying vec3 scaled_pos;
varying vec3 local_normal;

void vertex() {
	vec3 object_scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);
	scaled_pos = VERTEX * object_scale;
	local_normal = NORMAL;
}

float grid_mask(vec2 uv, float size, float width) {
	vec2 cell = uv / size;
	vec2 dist = abs(fract(cell - 0.5) - 0.5) * size;
	vec2 aa = fwidth(uv);
	vec2 lines = 1.0 - smoothstep(vec2(width * 0.5), vec2(width * 0.5) + aa, dist);
	// Fade the lines out once a cell is only a few pixels wide.
	float fade = 1.0 - smoothstep(0.15, 0.5, max(aa.x, aa.y) / size);
	return max(lines.x, lines.y) * fade;
}

void fragment() {
	vec3 n = abs(local_normal);
	vec2 uv = scaled_pos.xy;
	if (n.x > n.y && n.x > n.z) {
		uv = scaled_pos.zy;
	} else if (n.y > n.z) {
		uv = scaled_pos.xz;
	}

	vec2 cell_id = floor(uv / cell_size);
	float checker = mod(cell_id.x + cell_id.y, 2.0);
	vec3 color = mix(base_color, alt_color, checker);
	color = mix(color, line_color, grid_mask(uv, cell_size, line_width));

	if (dot_spacing > 0.0) {
		vec2 to_dot = (fract(uv / dot_spacing) - 0.5) * dot_spacing;
		float aa = max(fwidth(uv.x), fwidth(uv.y));
		float dots = 1.0 - smoothstep(dot_radius, dot_radius + aa, length(to_dot));
		dots *= 1.0 - smoothstep(0.15, 0.5, aa / dot_spacing);
		color = mix(color, dot_color, dots);
	}

	ALBEDO = color;
	ROUGHNESS = surface_roughness;
}
