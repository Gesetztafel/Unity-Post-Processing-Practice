Shader "Hidden/Gesetz/FXAA" {
	
	SubShader {
		Cull Off ZTest Always ZWrite Off
		
		HLSLINCLUDE
		#include "Gesetz_Common.hlsl"
		#include "FXAAPasses.hlsl"
		ENDHLSL
		
		Pass {
			Name "Luminance Pass"
			HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment LumaPassFragment

				#include "FXAAPasses.hlsl"
			ENDHLSL
		}
		
		Pass {
			Name "Log Luminance Pass"
			HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment LumaPassFragment

				#define LOG_LUMINANCE
			
				#include "FXAAPasses.hlsl"
			ENDHLSL
		}
		
		Pass {
			Name "FXAA With Green"
			//Blend [_SrcBlend] [_DstBlend]
			
			HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment FXAAPassFragment
				#pragma multi_compile _ FXAA_QUALITY_MEDIUM FXAA_QUALITY_LOW
				#include "FXAAPasses.hlsl"
			ENDHLSL
		}
		Pass {
			Name "FXAA With Luma"
			//Blend [_SrcBlend] [_DstBlend]
			
			HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment FXAAPassFragment
				#pragma multi_compile _ FXAA_QUALITY_MEDIUM FXAA_QUALITY_LOW
				#define FXAA_ALPHA_CONTAINS_LUMA
				#include "FXAAPasses.hlsl"
			ENDHLSL
		}
		
		//Debug Mode
	}
}