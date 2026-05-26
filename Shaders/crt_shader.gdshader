shader_type canvas_item;

// SCREEN TEXTURE
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// SCANLINES
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.15;   // darkness of each line
uniform float scanline_count : hint_range(50.0, 600.0) = 200.0;   // amount / how close together
uniform float scanline_thickness : hint_range(0.0, 1.0) = 0.4;    // 0 = hairline, 1 = solid black

// CURVATURE
uniform float curvature : hint_range(0.0, 1.0) = 0.15;

// VIGNETTE
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;

// CHROMATIC ABERRATION
uniform float aberration : hint_range(0.0, 0.01) = 0.002;

// BRIGHTNESS
uniform float brightness : hint_range(0.5, 2.0) = 1.1;

vec2 apply_curvature(vec2 uv) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / vec2(8.0 / curvature);
	uv = uv + uv * offset * offset;
	uv = uv * 0.5 + 0.5;
	return uv;
}

float scanline(vec2 uv) {
	// fract() repeats 0.0->1.0 for every scanline period
	// step() cuts it into a hard dark band vs bright gap
	// scanline_thickness controls what fraction of each period is the dark band
	float line_pos = fract(uv.y * scanline_count);
	return step(scanline_thickness, line_pos); // 0 = dark line, 1 = bright gap
}

float vignette(vec2 uv) {
	uv = uv * (1.0 - uv);
	return pow(uv.x * uv.y * 15.0, vignette_intensity);
}

void fragment() {
	vec2 curved_uv = apply_curvature(SCREEN_UV);
	
	bool outside = curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0;
	
	if (outside) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Chromatic aberration
		float r = texture(screen_texture, curved_uv + vec2(aberration, 0.0)).r;
		float g = texture(screen_texture, curved_uv).g;
		float b = texture(screen_texture, curved_uv - vec2(aberration, 0.0)).b;
		vec4 color = vec4(r, g, b, 1.0);
		
		// Scanlines
		float scan = scanline(curved_uv);
		color.rgb -= scanline_intensity * (1.0 - scan);
		
		// Vignette
		color.rgb *= vignette(curved_uv);
		
		// Brightness
		color.rgb *= brightness;
		
		COLOR = color;
	}
}