Shader "Gesetz/SSAO"
{
		HLSLINCLUDE
			#include "Gesetz_Common.hlsl"
			#include"SSAO.hlsl"

			#pragma target 5.0
		ENDHLSL
	SubShader
	{
		ZTest Always Cull Off ZWrite Off
		
		Pass
		{
			Name "Downsample"
			
			HLSLPROGRAM

			#pragma vertex DefaultVertex
			#pragma fragment frag_DownSample
			ENDHLSL
		}
		
		Pass
		{
			Name "Scalable AO"
			
			HLSLPROGRAM

			#pragma vertex DefaultVertex
			#pragma fragment frag_AO
			ENDHLSL
		}
		
		Pass
		{
			Name "Blur X"
			
			HLSLPROGRAM
            #define BLUR_HORIZONTAL

			#pragma vertex DefaultVertex
			#pragma fragment frag_blur
			ENDHLSL
		}
		Pass
		{
			Name "Blur Y"
			
			HLSLPROGRAM

			#pragma vertex DefaultVertex
			#pragma fragment frag_blur
			ENDHLSL
		}
		
		Pass
		{
			Name "Upsample"
			
			HLSLPROGRAM

			#pragma vertex DefaultVertex
			#pragma fragment frag_Upsample
			ENDHLSL
		}
		
		Pass
		{
			Name "Composition"
			
			Blend Zero OneMinusSrcColor, Zero OneMinusSrcAlpha
			HLSLPROGRAM

			#pragma vertex DefaultVertex
			#pragma fragment frag_composition
			ENDHLSL
		}
		Pass
		{
			Name "Debug"
			HLSLPROGRAM

			#pragma vertex DefaultVertex
			#pragma fragment frag_debug
			ENDHLSL
		}
	}
}