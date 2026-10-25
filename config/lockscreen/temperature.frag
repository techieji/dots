#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float temperatureMix;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 sampleColor = texture(source, qt_TexCoord0);
    vec3 rgb = sampleColor.rgb;

    // A cool, pre-dawn white balance. Preserve relative luminance so the
    // transition changes perceived temperature without becoming a dimmer.
    vec3 cooled = rgb * vec3(0.76, 0.91, 1.14);
    float originalY = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    float cooledY = max(dot(cooled, vec3(0.2126, 0.7152, 0.0722)), 0.0001);
    cooled *= originalY / cooledY;

    fragColor = vec4(mix(rgb, cooled, temperatureMix), sampleColor.a) * qt_Opacity;
}
