//
//  Shaders.metal
//  MetalCamera
//
//  Created by Maximilian Christ on 30/08/14.
//  Copyright (c) 2014 McZonk. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;


typedef struct {
    packed_float2 position;
    packed_float2 texcoord;
} Vertex;

typedef struct {
	float3x3 matrix;
	float3 offset;
} ColorConversion;

typedef struct {
    float4 position [[position]];
    float2 texcoord;
} Varyings;

vertex Varyings lh_vertexShader(
    const device Vertex* verticies [[ buffer(0) ]],
	unsigned int vid [[ vertex_id ]]) {
    Varyings out;
	const device Vertex& v = verticies[vid];
    out.position = float4(float2(v.position), 0.0, 1.0);
	out.texcoord = v.texcoord;
    return out;
}

fragment half4 lh_fragmentShader(
	Varyings in [[ stage_in ]],
    texture2d<float, access::sample> textureBGRA [[ texture(0) ]]) {
	constexpr sampler s(address::clamp_to_edge, filter::linear);
    float alpha = textureBGRA.sample(s, in.texcoord).r; //左侧是灰度图，所以r,g,b中任何一个都可以代表alpha
    float2 grbTexcoord = float2(in.texcoord.x + 0.5, in.texcoord.y); //x + 0.5 对应右半部分的坐标
    float3 rgb = textureBGRA.sample(s, grbTexcoord).rgb;
    return half4(half3(rgb), half(alpha));
}
