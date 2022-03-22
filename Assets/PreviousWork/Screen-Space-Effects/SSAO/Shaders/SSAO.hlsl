#ifndef GESETZ_SSAO_INCLUDED
#define GESETZ_SSAO_INCLUDED

//Further Work:
//Better Down_sampling && Up_sampling with depth aware:
//checkerboard Pattern?,Nearest depth sampling? Most Representative?

#include "Gesetz_Common.hlsl"

//Configs 

//Downsample , upsample Config

//Scalable AO
static const float kGeometryCoeff = 0.8;

static const float GOLDEN_ANGLE=2.4f;
//720p 0.002 1080p 0.001
static const float kBias=0.001f;
static const float kEpsilon = 1e-3;

static const int MAX_SAMPLE_COUNT=64;

TEXTURE2D_SAMPLER2D(_CameraGBufferTexture2, sampler_CameraGBufferTexture2);
TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);


TEXTURE2D_SAMPLER2D(_AO_ColorTex,sampler_AO_ColorTex);

TEXTURE2D_SAMPLER2D(_ssaoTexture_upsample,sampler_ssaoTexture_upsample);
//HalfRes
TEXTURE2D_SAMPLER2D(_depth_Texture_x4,sampler_depth_Texture_x4);
TEXTURE2D_SAMPLER2D(_depth_normal_Texture_x4,sampler_depth_normal_Texture_x4);
TEXTURE2D_SAMPLER2D(_ssaoTexture_x4,sampler_ssaoTexture_x4);

int _SampleCount;

float4 _AOParams;//x:ssaoRadius_world 1.0f y:ssaoMaxRadius_screen 0.1f ,z:ssaoContrast 4.0f

#define _RadiusWorld _AOParams.x
#define _maxRadiusScreen _AOParams.y
#define _Contrast _AOParams.z

#define _ScreenWidth _ScreenParams.x
#define _ScreenHeight _ScreenParams.y


float SampleDepth(float2 uv){
    return SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,uv);
}
float GetLinear01Depth(float2 uv)
{
	float depth01=Linear01Depth(SampleDepth(uv),_ZBufferParams);
	return depth01;
}
float GetLinearEyeDepth(float2 uv)
{
	float depth_eye=LinearEyeDepth(SampleDepth(uv),_ZBufferParams);
	return depth_eye;
}
float3 SampleNormal(float2 uv)
{
	return  SAMPLE_TEXTURE2D(_CameraGBufferTexture2, sampler_CameraGBufferTexture2, uv).xyz;
}
float3 GetNormalWS(float2 uv)
{
	float3 normWS = SAMPLE_TEXTURE2D(_CameraGBufferTexture2, sampler_CameraGBufferTexture2, uv).xyz;
    normWS = normWS * 2 - any(normWS); // gets (0,0,0) when norm == 0
    return normWS;
}
float3 GetNormalVS(float2 uv)
{
	float3 norm=GetNormalWS(uv);
	norm=mul((float3x3)unity_WorldToCamera,norm);
    norm=normalize(norm);
	return norm;
}

//Down sampling & Up sampling
//HDRP DownSampleDepth.shader
//Min/Max Depth Nearest Depth
float MinDepth(float4 depths)
{
#if UNITY_REVERSED_Z
            return Max3(depths.x, depths.y, max(depths.z, depths.w));
#else
            return Min3(depths.x, depths.y, min(depths.z, depths.w));
#endif
}
float MaxDepth(float4 depths)
{
#if UNITY_REVERSED_Z
            return Min3(depths.x, depths.y, min(depths.z, depths.w));
#else
            return Max3(depths.x, depths.y, max(depths.z, depths.w));
#endif
}
//CheckBoard Pattern
void Frag_DepthDownSample(Varyings input,out float outputDepth:SV_TARGET)
{
	float2 pixelSize=float2((float)2.0/_ScreenWidth,(float)2.0/_ScreenHeight);
	
	float2 texcoord00 = input.screenuv+float2(-0.25,-0.25)*pixelSize;
	float4 depths;
	depths.x=SampleDepth(texcoord00);
	depths.y=SampleDepth(texcoord00+float2(-0.25,0.25)*pixelSize);
	depths.z=SampleDepth(texcoord00+float2(0.25,-0.25)*pixelSize);
	depths.w=SampleDepth(texcoord00+float2(0.25,0.25)*pixelSize);

	float minDepth=MinDepth(depths);
	float maxDepth=MaxDepth(depths);

//Use Checkerboard
	bool check=(uint)(input.positionCS.x+input.positionCS.y)&1>0;
	outputDepth=check?minDepth:maxDepth;
}

float4 Frag_DepthNormalDownsample(Varyings input):SV_Target
{
	float2 pixelSize=float2((float)2.0/_ScreenWidth,(float)2.0/_ScreenHeight);
	float2 texcoord00 = input.screenuv+float2(-0.25,-0.25)*pixelSize;
	
	float4 depths;
	depths.x=SampleDepth(texcoord00);
	depths.y=SampleDepth(texcoord00+float2(-0.25,0.25)*pixelSize);
	depths.z=SampleDepth(texcoord00+float2(0.25,-0.25)*pixelSize);
	depths.w=SampleDepth(texcoord00+float2(0.25,0.25)*pixelSize);
	
	float minDepth=MinDepth(depths);
	float maxDepth=MaxDepth(depths);
//Use Checkerboard
	bool check=(uint)(input.positionCS.x+input.positionCS.y)&1>0;
	float outputDepth=check?minDepth:maxDepth;
	
	float Depths[4];
	Depths[0]=depths.x;Depths[1]=depths.y;Depths[2]=depths.z;Depths[3]=depths.w;
	//Sample normal
	float3 Normals[4];
	Normals[0]=SampleNormal(texcoord00);
	Normals[1]=SampleNormal(texcoord00+float2(-0.25,0.25)*pixelSize);;
	Normals[2]=SampleNormal(texcoord00+float2(0.25,-0.25)*pixelSize);
	Normals[3]=SampleNormal(texcoord00+float2(0.25,0.25)*pixelSize);

	float4 output;
	for(int i=0;i<4;i++)
	{
		if(outputDepth==Depths[i])
		{
			output=float4(Normals[i],outputDepth);
		}
	}
	return output;
}
//most_representative hikiko-blog
// float most_representative(float2 fullResUpperCorner)
// {
// }
// float4 frag_Downsample(Varyings input):SV_Target
// {
// }

//GPU ZEN Robust SSAO
void frag_DownSample(Varyings input,out float outputDepth:SV_TARGET)
{
	float2 pixelSize=float2((float)2.0/_ScreenWidth,(float)2.0/_ScreenHeight);
	float2 texCoord=input.screenuv+float2(-0.25f,-0.25f)*pixelSize;

	outputDepth=GetLinear01Depth(texCoord);
}

//Further Work : Depth MipmapChain

static float2 vogelDiskOffsets16[16] =
{
	float2(0.176777f, 0.0f),
	float2(-0.225718f, 0.206885f),
	float2(0.0343507f, -0.393789f),
	float2(0.284864f, 0.370948f),
	float2(-0.52232f, -0.0918239f),
	float2(0.494281f, -0.315336f),
	float2(-0.164493f, 0.615786f),
	float2(-0.316681f, -0.607012f),
	float2(0.685167f, 0.248588f),
	float2(-0.711557f, 0.295696f),
	float2(0.341422f, -0.73463f),
	float2(0.256072f, 0.808194f),
	float2(-0.766143f, -0.440767f),
	float2(0.896453f, -0.200303f),
	float2(-0.544632f, 0.780785f),
	float2(-0.130341f, -0.975582f)
};

static float2 alchemySpiralOffsets16[16] =
{
	float2(0.19509f, 0.980785f),
	float2(-0.55557f, -0.83147f),
	float2(0.831469f, 0.555571f),
	float2(-0.980785f, -0.195091f),
	float2(0.980785f, -0.19509f),
	float2(-0.83147f, 0.555569f),
	float2(0.555571f, -0.831469f),
	float2(-0.195092f, 0.980785f),
	float2(-0.195089f, -0.980786f),
	float2(0.555569f, 0.83147f),
	float2(-0.831469f, -0.555572f),
	float2(0.980785f, 0.195092f),
	float2(-0.980786f, 0.195088f),
	float2(0.831471f, -0.555568f),
	float2(-0.555572f, 0.831468f),
	float2(0.195093f, -0.980785f)
};

float2 RotatePoint(float2 pt, float angle){
	float sine, cosine;
	sincos(angle, sine, cosine);

	float2 rotatedPoint;
	rotatedPoint.x = cosine*pt.x + -sine*pt.y;
	rotatedPoint.y = sine*pt.x + cosine*pt.y;
	
	return rotatedPoint;
}


float2 VogelDiskOffset(int sampleIndex, float phi){
	float r = sqrt(sampleIndex + 0.5f) / sqrt(_SampleCount);
	float theta = sampleIndex*GOLDEN_ANGLE + phi;

	float sine, cosine;
	sincos(theta, sine, cosine);
	
	return float2(r * cosine, r * sine);
}

float2 AlchemySpiralOffset(int sampleIndex, float phi){
	float alpha = float(sampleIndex + 0.5f) / _SampleCount;
	float theta = 7.0f*TWO_PI*alpha + phi;

	float sine, cosine;
	sincos(theta, sine, cosine);
	
	return float2(cosine, sine);
}

float InterleavedGradientNoise(float2 position_screen){
	float3 magic = float3(0.06711056f, 4.0f*0.00583715f, 52.9829189f);
	return frac(magic.z * frac(dot(position_screen, magic.xy)));
}

float AlchemyNoise(int2 position_sreen)
{
	return 30.0f*(position_sreen.x^position_sreen.y)+10.0f*(position_sreen.x*position_sreen.y);
}

//Postprocessing v2
// Check if the camera is perspective.
// (returns 1.0 when orthographic)
float CheckPerspective(float x)
{
    return lerp(x, 1.0, unity_OrthoParams.w);
}
// Reconstruct view-space position from UV and depth.
// p11_22 = (unity_CameraProjection._11, unity_CameraProjection._22)
// p13_31 = (unity_CameraProjection._13, unity_CameraProjection._23)
float3 ReconstructViewPosition(float2 uv,float Linear01depth,float2 p11_22,float2 p13_31)
{
    float depth=Linear01depth*_ProjectionParams.z;
	
    return float3((uv * 2.0 - 1.0 - p13_31) / p11_22 * CheckPerspective(depth), depth);
}
//Scalable AO [McGuire 12]
//SSAO for Indirect Diffuse
float4 frag_AO(Varyings input):SV_Target
{
	//1/4 resolution
	float2 pixelSize=float2(2.0/(float)_ScreenWidth,2.0/(float)_ScreenHeight);
	float aspect=_ScreenWidth/_ScreenHeight;

	float2 texCoord00 =input.screenuv+float2(-0.25f,-0.25f)*pixelSize;

	float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
  float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._31);
	//reconstruct position
	//LinearEyeDepth HalfRef R16f
	float Linear01depth=_depth_Texture_x4.Sample(sampler_depth_Texture_x4,input.screenuv).x;
	float3 position=ReconstructViewPosition(input.screenuv,Linear01depth,p11_22,p13_31);
	float3 normal=GetNormalVS(texCoord00);

	float noise=InterleavedGradientNoise(input.positionCS.xy);
	// float alchemyNoise=AlchemyNoise(input.positionCS.xy);
	
	// Screen-space radius computation
	float2 radius_screen=_RadiusWorld/position.z;
	radius_screen=min(radius_screen,_maxRadiusScreen);
	radius_screen.y*=aspect;

	float ao=0.0f;

	for (int s=0;s<_SampleCount;s++)
	{
		//sample
		float2 sampleOffset=0.0f;
		sampleOffset=VogelDiskOffset(s,TWO_PI*noise);

		float2 sampleTex=input.screenuv+radius_screen*sampleOffset;
		
		float sampledepth=_depth_Texture_x4.Sample(sampler_depth_Texture_x4,sampleTex).x;
		float3 samplePosition=ReconstructViewPosition(sampleTex,sampledepth,p11_22,p13_31);
		
		//v
		float3 v=samplePosition-position;
		//Distance falloff:max(1-||v||/r,0.0)*max((v/||v|| . n-bias,0)) angular falloff
		ao+=max(0.0f,dot(v,normal)+kBias*position.z)/(dot(v,v)+kEpsilon);
	}

	ao=saturate(ao/_SampleCount);
	ao=1.0f-ao;
	ao=PositivePow(ao,_Contrast);

	return float4(ao.xxx,1.0);
}

//HBAO
// TODO

//GTAO
//GameDev/XeGTAO
// DEPTH_MIP_LEVELS 5

Texture2D(_Depth_MIP0);
Texture2D(_Depth_MIP1);
Texture2D(_Depth_MIP2);
Texture2D(_Depth_MIP3);
Texture2D(_Depth_MIP4);

//Quality Level
// sliceCount stepsPerSlice

float4 frag_GTAO(Varyings input):SV_Target{

}


// TODO

//BentNormal
// TODO


static float gaussWeightsSigma1[7] =
{
	0.00598f,0.060626f,0.241843f,0.383103f,0.241843f,0.060626f,0.00598f
};
static float gaussWeightsSigma3[7] =
{
	0.106595f,0.140367f,0.165569f,0.174938f,0.165569f,0.140367f,0.106595f
};

float4 frag_blur(Varyings input):SV_Target{
#if defined(BLUR_HORIZONTAL)
    float2 pixelOffset = float2(2.0f/(float)_ScreenWidth, 0.0);
#else
    float2 pixelOffset = float2(0.0,2.0f/(float)_ScreenHeight);
#endif

	float sum=0.0f;
	float weightSum=0.0f;

	float depth=_depth_Texture_x4.Sample(sampler_depth_Texture_x4,input.screenuv).x;

	UNITY_LOOP
	for(int i=-3;i<=3;i++)
	{
		float2 sampleTexcoord=input.screenuv+i*pixelOffset;
		float sampleDepth=_depth_Texture_x4.Sample(sampler_depth_Texture_x4,sampleTexcoord).x;

		float depthsDiff=0.1f+abs(depth-sampleDepth);
		depthsDiff*=depthsDiff;
		float weight=1.0f/(depthsDiff+kEpsilon);
		weight*=gaussWeightsSigma3[3+i];

		float ao=_ssaoTexture_x4.Sample(sampler_ssaoTexture_x4,sampleTexcoord).x;
		sum+=weight*ao;
		weightSum+=weight;
	}

	return sum/weightSum;
}


//Upsampling

float4 frag_Upsample(Varyings input):SV_Target{
	//full-resolution
	float2 pixelSize=float2((float)1.0/_ScreenWidth,(float)1.0/_ScreenHeight);

	float2 texCoord00 = input.screenuv;
	float2 texCoord10 = input.screenuv + float2(pixelSize.x, 0.0f);
	float2 texCoord01 = input.screenuv + float2(0.0f, pixelSize.y);
	float2 texCoord11 = input.screenuv + float2(pixelSize.x, pixelSize.y);


	float depth=GetLinear01Depth(input.screenuv);

	float4 depths_x4 = _depth_Texture_x4.GatherRed(sampler_depth_Texture_x4, texCoord00).wzxy;
	float4 depthsDiffs = abs(depth.xxxx - depths_x4);
	
	float4 ssaos_x4 = _ssaoTexture_x4.GatherRed(sampler_ssaoTexture_x4, texCoord00).wzxy;

	float2 imageCoord = input.screenuv / pixelSize;
	
	float2 fractional = frac(imageCoord);
	float a = (1.0f - fractional.x) * (1.0f - fractional.y);
	float b = fractional.x * (1.0f - fractional.y);
	float c = (1.0f - fractional.x) * fractional.y;
	float d = fractional.x * fractional.y;

	float4 ssao = 0.0f;
	float weightsSum = 0.0f;

	float weight00 = a / (depthsDiffs.x + kEpsilon);
	ssao += weight00 * ssaos_x4.x;
	weightsSum += weight00;

	float weight10 = b / (depthsDiffs.y + kEpsilon);
	ssao += weight10 * ssaos_x4.y;
	weightsSum += weight10;

	float weight01 = c / (depthsDiffs.z + kEpsilon);
	ssao += weight01 * ssaos_x4.z;
	weightsSum += weight01;

	float weight11 = d / (depthsDiffs.w + kEpsilon);
	ssao += weight11 * ssaos_x4.w;
	weightsSum += weight11;

	ssao /= weightsSum;

	return ssao;
}

//Specular Occlusion
//for Indirect Specular
//[Lagarde14]
float computeSpecularAO(float NoV, float ao, float roughness) {
    return clamp(pow(NoV + ao, exp2(-16.0 * roughness - 1.0)) - 1.0 + ao, 0.0, 1.0);
}

//[Jimenez 16]

//TODO
float3 AOMultiBounce(float visibility,float3 albedo)
{
	float3 a =  2.0404f * albedo - 0.3324f;
    float3 b = -4.7951f * albedo + 0.6417f;
    float3 c =  2.7552f * albedo + 0.6903f;

	float x=visibility;
	return max(x,((x*a+b)*x+c)*x);
}

float4 frag_composition(Varyings i):SV_Target
{
    float2 uv=i.screenuv;
	float ao=_ssaoTexture_upsample.Sample(sampler_ssaoTexture_upsample,uv).r;
	float3 color=_AO_ColorTex.Sample(sampler_AO_ColorTex,uv).rgb;

	return float4(color*ao.xxx,1.0);
}
float4 frag_debug(Varyings i):SV_Target
{
  float2 uv=i.screenuv;
	float ao=_ssaoTexture_upsample.Sample(sampler_ssaoTexture_upsample,uv).r;
	
	return float4(ao.xxx, 1.0);
}

#endif