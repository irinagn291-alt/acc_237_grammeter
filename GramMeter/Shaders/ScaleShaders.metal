#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]] half4 readoutGlow(float2 position, half4 color, float time, float intensity) {
    float pulse = 0.5 + 0.5 * sin(time * 2.2);
    half3 glow = half3(0.0h, 0.675h, 0.757h);
    half mixIn = half(intensity * pulse * 0.22);
    return half4(mix(color.rgb, glow, mixIn), color.a);
}

[[ stitchable ]] float2 needleBlur(float2 position, float time) {
    float wobble = sin(time * 3.1 + position.y * 0.04) * 1.4;
    return float2(position.x + wobble, position.y);
}

[[ stitchable ]] half4 gradientNoise(float2 position, SwiftUI::Layer layer, float time) {
    half4 source = layer.sample(position);
    float n = fract(sin(dot(position + time * 0.15, float2(12.9898, 78.233))) * 43758.5453);
    half grain = half(n * 0.035);
    return source + half4(grain, grain, grain, 0);
}
