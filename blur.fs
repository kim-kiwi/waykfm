#version 330 core

uniform sampler2D texture0;
uniform float weight[10] = float[](0.32465246735834974, 0.27803730045319414, 0.23574607655586352, 0.19789869908361468, 0.16447445657715493, 0.1353352832366127, 0.11025052530448523, 0.08892161745938636, 0.07100535373963698, 0.05613476283413374);

uniform vec2 direction;
uniform float glowIntensity;

in vec2 fragTexCoord;

out vec4 FragColor;

void main() {
    vec3 result = texture(texture0, fragTexCoord).rgb * weight[0];

    for (int i = 1; i < 10; i++) {
        vec2 offset = direction * float(i);
        result += texture(texture0, fragTexCoord + offset).rgb * weight[i];
        result += texture(texture0, fragTexCoord - offset).rgb * weight[i];
    }

    FragColor = vec4(result*0.35*glowIntensity, 1.0);
}