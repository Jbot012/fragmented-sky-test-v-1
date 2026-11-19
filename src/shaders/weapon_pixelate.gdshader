shader_type canvas_item;

// Light screen-space pixelation for the 3D weapon viewports.
// Lower values are chunkier; keep this small for a subtle pixel-art effect.
uniform float block_size : hint_range(1.0, 12.0) = 3.0;

// In fragment(), COLOR already includes the default texture sample, so capture
// the vertex color (CanvasItem modulate) separately to avoid darkening the art.
varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	vec2 viewport_pixels = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 blocks = max(viewport_pixels / block_size, vec2(1.0));
	vec2 block_uv = (floor(UV * blocks) + vec2(0.5)) / blocks;
	COLOR = texture(TEXTURE, block_uv) * vertex_color;
}
