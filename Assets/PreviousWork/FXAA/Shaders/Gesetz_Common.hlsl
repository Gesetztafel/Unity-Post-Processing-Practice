#ifndef SSAO_COMMON_INCLUDED
#define SSAO_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonLighting.hlsl"


#define TEXTURE2D_SAMPLER2D(textureName, samplerName) Texture2D textureName; SamplerState samplerName


//ShaderVariables.hlsl
float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 unity_ObjectToWorld;
float4x4 unity_WorldToObject;
float4x4 glstate_matrix_projection;

#define UNITY_MATRIX_M unity_ObjectToWorld
#define UNITY_MATRIX_I_M unity_WorldToObject
#define UNITY_MATRIX_V unity_MatrixV
#define UNITY_MATRIX_VP unity_MatrixVP
#define UNITY_MATRIX_P glstate_matrix_projection

float4x4 unity_CameraProjection;
float4x4 unity_WorldToCamera;

float4 _ProjectionParams;// x: 1 (-1 flipped), y: near,     z: far,       w: 1/far
float4 _ZBufferParams; // x: 1-far/near,     y: far/near, z: x/far,     w: y/far
float4 _ScreenParams; // x: width,  y: height,   z: 1+1/width, w: 1+1/height
float4 unity_OrthoParams;

real4 unity_WorldTransformParams;

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"

//Samplers
SAMPLER(sampler_point_clamp);
SAMPLER(sampler_linear_clamp);

//FullscreenTriangle
struct Attributes
{
    uint vertexID:SV_VertexID;
};

struct Varyings
{
    float4 positionCS: SV_POSITION;
	float2 screenuv: TEXCOORD0;
};


Varyings DefaultVertex(Attributes input){
    Varyings output;
    output.positionCS=GetFullScreenTriangleVertexPosition(input.vertexID);
    output.screenuv=GetFullScreenTriangleTexCoord(input.vertexID);
	
    return output;
}

#endif

