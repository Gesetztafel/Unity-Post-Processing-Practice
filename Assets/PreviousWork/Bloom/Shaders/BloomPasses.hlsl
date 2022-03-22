#ifndef GESETZ_BLOOM_INCLUDED
#define GESETZ_BLOOM_INCLUDED

TEXTURE2D(_BloomColor);

TEXTURE2D(_MainTex);
float4 _MainTex_TexelSize;

TEXTURE2D(_BloomSource);
float4 _BloomSource_TexelSize;

TEXTURE2D(_BloomSource2);


float4 GetSourceTexelSize () {
	//return _BloomSource_TexelSize;
	return _MainTex_TexelSize;
}

float4 GetSourceBicubic (float2 screenUV) {
	// return SampleTexture2DBicubic(
	// 	TEXTURE2D_ARGS(_BloomSource, sampler_linear_clamp), screenUV,
	// 	_BloomSource_TexelSize.zwxy, 1.0, 0.0
	// );
	return SampleTexture2DBicubic(
		TEXTURE2D_ARGS(_MainTex, sampler_linear_clamp), screenUV,
		_MainTex_TexelSize.zwxy, 1.0, 0.0
	);
}

float4 GetSource2(float2 screenUV) {
	return SAMPLE_TEXTURE2D_LOD(_BloomSource2, sampler_linear_clamp, screenUV, 0);
}

float4 GetSource(float2 screenUV) {
	//return SAMPLE_TEXTURE2D_LOD(_BloomSource, sampler_linear_clamp, screenUV, 0);
	return SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_linear_clamp, screenUV, 0);
}

bool _BloomBicubicUpsampling;
float _BloomIntensity;

float4 BloomAddPassFragment (Varyings input) : SV_TARGET {
	float3 lowRes;
	if (_BloomBicubicUpsampling) {
		lowRes = GetSourceBicubic(input.screenuv).rgb;
	}
	else {
		lowRes = GetSource(input.screenuv).rgb;
	}
	float4 highRes = GetSource2(input.screenuv);
	return float4(lowRes * _BloomIntensity + highRes.rgb, highRes.a);
}

float4 BloomHorizontalPassFragment (Varyings input) : SV_TARGET {
	float3 color = 0.0;
	float offsets[] = {
		-4.0, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0
	};
	float weights[] = {
		0.01621622, 0.05405405, 0.12162162, 0.19459459, 0.22702703,
		0.19459459, 0.12162162, 0.05405405, 0.01621622
	};
	for (int i = 0; i < 9; i++) {
		float offset = offsets[i] * 2.0 * GetSourceTexelSize().x;
		color += GetSource(input.screenuv + float2(offset, 0.0)).rgb * weights[i];
	}
	return float4(color, 1.0);
}

float4 _BloomThreshold;

float3 ApplyBloomThreshold (float3 color) {
	float brightness = Max3(color.r, color.g, color.b);
	float soft = brightness + _BloomThreshold.y;
	soft = clamp(soft, 0.0, _BloomThreshold.z);
	soft = soft * soft * _BloomThreshold.w;
	float contribution = max(soft, brightness - _BloomThreshold.x);
	contribution /= max(brightness, 0.00001);
	return color * contribution;
}

float4 BloomPrefilterPassFragment (Varyings input) : SV_TARGET {
	float3 color = ApplyBloomThreshold(GetSource(input.screenuv).rgb);
	return float4(color, 1.0);
}

float4 BloomPrefilterFirefliesPassFragment (Varyings input) : SV_TARGET {
	float3 color = 0.0;
	float weightSum = 0.0;
	float2 offsets[] = {
		float2(0.0, 0.0),
		float2(-1.0, -1.0), float2(-1.0, 1.0), float2(1.0, -1.0), float2(1.0, 1.0)
	};
	for (int i = 0; i < 5; i++) {
		float3 c =
			GetSource(input.screenuv + offsets[i] * GetSourceTexelSize().xy * 2.0).rgb;
		c = ApplyBloomThreshold(c);
		float w = 1.0 / (Luminance(c) + 1.0);
		color += c * w;
		weightSum += w;
	}
	color /= weightSum;
	return float4(color, 1.0);
}

float4 BloomScatterPassFragment (Varyings input) : SV_TARGET {
	float3 lowRes;
	if (_BloomBicubicUpsampling) {
		lowRes = GetSourceBicubic(input.screenuv).rgb;
	}
	else {
		lowRes = GetSource(input.screenuv).rgb;
	}
	float3 highRes = GetSource2(input.screenuv).rgb;
	return float4(lerp(highRes, lowRes, _BloomIntensity), 1.0);
}

float4 BloomScatterFinalPassFragment (Varyings input) : SV_TARGET {
	float3 lowRes;
	if (_BloomBicubicUpsampling) {
		lowRes = GetSourceBicubic(input.screenuv).rgb;
	}
	else {
		lowRes = GetSource(input.screenuv).rgb;
	}
	float4 highRes = GetSource2(input.screenuv);
	lowRes += highRes.rgb - ApplyBloomThreshold(highRes.rgb);
	return float4(lerp(highRes.rgb, lowRes, _BloomIntensity), highRes.a);
}

float4 BloomVerticalPassFragment (Varyings input) : SV_TARGET {
	float3 color = 0.0;
	float offsets[] = {
		-3.23076923, -1.38461538, 0.0, 1.38461538, 3.23076923
	};
	float weights[] = {
		0.07027027, 0.31621622, 0.22702703, 0.31621622, 0.07027027
	};
	for (int i = 0; i < 5; i++) {
		float offset = offsets[i] * GetSourceTexelSize().y;
		color += GetSource(input.screenuv + float2(0.0, offset)).rgb * weights[i];
	}
	return float4(color, 1.0);
}

float4 CopyPassFragment (Varyings input) : SV_TARGET {
	return GetSource(input.screenuv);
}

float4 ToneMappingACESPassFragment(Varyings input):SV_Target{
	float4 color=GetSource(input.screenuv);

	color.rgb=min(color.rgb,60.0);
	color.rgb=AcesTonemap(unity_to_ACES(color.rgb));

	return color;
}

#endif