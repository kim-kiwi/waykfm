// bright-pass.fs
#version 330
in vec2 fragTexCoord;
out vec4 fragColor;

uniform sampler2D texture0;

void main() {
    vec4 color = texture(texture0, fragTexCoord);
    float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor=brightness > 0.0 ? color : vec4(0);
}