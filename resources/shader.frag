#version 300 es

precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    float y = 0.2126 * pixColor[0] + 0.7152 * pixColor[1] + 0.0722 * pixColor[2];
    float y_ = atan(y);
    fragColor = pixColor * y_ / y;
}
