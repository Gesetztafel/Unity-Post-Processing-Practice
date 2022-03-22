Shader "Hidden/Gesetz/Bloom"
{
    SubShader
    {
        Cull Off
		ZTest Always
		ZWrite Off

        HLSLINCLUDE
		#include "Gesetz_Common.hlsl"
		#include "BloomPasses.hlsl"
		ENDHLSL


    	
		Pass {
			Name "Bloom Add"
			
			HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment BloomAddPassFragment
			ENDHLSL
		}
		
		Pass {
			Name "Bloom Horizontal"
			
			HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment BloomHorizontalPassFragment
			ENDHLSL
		}

		Pass {
			Name "Bloom Prefilter"
			
			HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment BloomPrefilterPassFragment
			ENDHLSL
		}
		
		Pass {
			Name "Bloom Prefilter Fireflies"
			
			HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment BloomPrefilterFirefliesPassFragment
			ENDHLSL
		}
		
		Pass {
			Name "Bloom Scatter"
			
			HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment BloomScatterPassFragment
			ENDHLSL
		}
		
		Pass {
			Name "Bloom Scatter Final"
			
			HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment BloomScatterFinalPassFragment
			ENDHLSL
		}
		
		Pass {
			Name "Bloom Vertical"
			
			HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment BloomVerticalPassFragment
			ENDHLSL
		}
    	
    	 Pass
    	{
			Name "Copy"
    		
    		HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment CopyPassFragment
			ENDHLSL
    		
    	}
    	
    	Pass
    	{
			Name "Tone Mapping ACES"
    		
    		HLSLPROGRAM
				#pragma target 3.5
				#pragma vertex DefaultVertex
				#pragma fragment ToneMappingACESPassFragment
			ENDHLSL
    		
    	}
    }

}
