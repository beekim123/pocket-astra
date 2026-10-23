shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform vec4 deep_color : source_color = vec4(0.08, 0.36, 0.40, 1.0);
void vertex() {
 VERTEX.y += sin(VERTEX.x * 1.6 + TIME * 0.6) * 0.018 + cos(VERTEX.z * 2.2 + TIME * 0.8) * 0.012;
}
void fragment() {
 vec2 p = UV * 95.0;
 float wave = sin(p.y * 3.0 + sin(p.x * 0.6 + TIME * 0.5) * 2.0 - TIME * 1.6);
 float sparkle = smoothstep(0.96, 1.0, wave) * smoothstep(0.5, 1.0, sin(p.x * 2.0 + TIME * 0.6));
 ALBEDO = deep_color.rgb + vec3(0.13, 0.22, 0.20) * sparkle;
 METALLIC = 0.35;
 ROUGHNESS = 0.28;
}
