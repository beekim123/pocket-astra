shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount = 1.0;
uniform float time_of_day = 0.0;
void fragment() {
 vec2 uv = SCREEN_UV;
 float edge = smoothstep(0.17, 0.49, abs(uv.y - 0.48));
 vec3 sharp = textureLod(screen_texture, uv, 0.0).rgb;
 vec3 soft = textureLod(screen_texture, uv, edge * 2.4 * blur_amount).rgb;
 vec3 bloom = max(textureLod(screen_texture, uv, 3.0).rgb - vec3(0.67), vec3(0.0)) * 0.22;
 vec3 color = mix(sharp, soft, edge * 0.78) + bloom;
 float vignette = 1.0 - 0.24 * pow(length((uv-0.5)*vec2(1.15,1.0)), 1.65);
 color *= vignette;
 color = mix(color, color * vec3(1.07,1.01,0.94), 0.48);
 COLOR = vec4(color, 1.0);
}
