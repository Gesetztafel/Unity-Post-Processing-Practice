using UnityEngine;
using UnityEngine.Rendering;

namespace Gesetz
{
    [ExecuteInEditMode]
    [ImageEffectAllowedInSceneView]
    [RequireComponent(typeof(Camera))]
    public class FXAA : MonoBehaviour
    {
        public enum FXAAPass
        {
            Luminance,
            Log_Luminance,
            FXAAWithGreen,
            FXAAWithLuma
        }

        const string
            fxaaQualityLowKeyword = "FXAA_QUALITY_LOW",
            fxaaQualityMediumKeyword = "FXAA_QUALITY_MEDIUM";

        // int
        //     SrcBlendId = Shader.PropertyToID("_SrcBlend"),
        //     DstBlendId = Shader.PropertyToID("_DstBlend");

        int fxaaConfigId = Shader.PropertyToID("_FXAAConfig");

        int
            _FXAA_SourceId = Shader.PropertyToID("_FXAA_Source"),
            _Luminace_Tex_Id = Shader.PropertyToID("_Luminance_Tex");

        //[SerializeField]
        // public bool keepAlpha = true;

        public enum LuminanceMode { /*Alpha,*/ Green, Luminance, LogLuminance }

        public enum EdgeQuality { Low, Medium, High }

        [System.Serializable]
        public struct FXAASettings
        {
            public LuminanceMode luminanceMode;

            [Range(0.0312f, 0.0833f)] public float fixedThreshold;

            [Range(0.063f, 0.333f)] public float relativeThreshold;

            [Range(0f, 1f)] public float subpixelBlending;

            public EdgeQuality edgeQuality;
        }

        [SerializeField]
        public FXAASettings fxaa = new FXAASettings
        {
            luminanceMode = LuminanceMode.Luminance,
            fixedThreshold = 0.0625f,
            relativeThreshold = 0.125f,
            subpixelBlending = 0.75f,
            edgeQuality = EdgeQuality.High
        };

        // [System.Serializable]
        // public struct FinalBlendMode
        // {
        //     public BlendMode source, destination;
        // }
        // [SerializeField]
        // public FinalBlendMode finalBlendMode = new FinalBlendMode
        // {
        //     source = BlendMode.One,
        //     destination = BlendMode.Zero
        // };

        Camera renderCamera;

        Material fxaaMaterial;

        const string bufferName = "FXAA Buffer";

        CommandBuffer fxaaBuffer = null;

        void Awake()
        {
            renderCamera = gameObject.GetComponent<Camera>();
            Shader fxaaShader = Shader.Find("Hidden/Gesetz/FXAA");
            if (fxaaMaterial == null)
            {
                fxaaMaterial = new Material(fxaaShader);
                fxaaMaterial.hideFlags = HideFlags.DontSave;
            }
        }

        private void OnEnable()
        {
            if (fxaaBuffer == null)
            {
                fxaaBuffer = new CommandBuffer();
                fxaaBuffer.name = bufferName;
            }
            renderCamera.AddCommandBuffer(CameraEvent.AfterImageEffects, fxaaBuffer);
        }

        private void OnPreRender()
        {
            if (fxaaBuffer != null)
            {
                RenderFXAA();
            }
        }

        private void OnDisable()
        {
            if (fxaaBuffer != null)
            {
                renderCamera.RemoveCommandBuffer(CameraEvent.AfterImageEffects, fxaaBuffer);
                fxaaBuffer = null;
            }
        }

        private void OnDestroy()
        {
            if (fxaaBuffer != null)
                fxaaBuffer.Dispose();
        }

        void ConfigureFXAA()
        {
            //EdgeQuality
            if (fxaa.edgeQuality == EdgeQuality.Low)
            {
                fxaaBuffer.EnableShaderKeyword(fxaaQualityLowKeyword);
                fxaaBuffer.DisableShaderKeyword(fxaaQualityMediumKeyword);
            }
            else if (fxaa.edgeQuality == EdgeQuality.Medium)
            {
                fxaaBuffer.DisableShaderKeyword(fxaaQualityLowKeyword);
                fxaaBuffer.EnableShaderKeyword(fxaaQualityMediumKeyword);
            }
            else
            {
                fxaaBuffer.DisableShaderKeyword(fxaaQualityLowKeyword);
                fxaaBuffer.DisableShaderKeyword(fxaaQualityMediumKeyword);
            }

            //fxaaConfig
            fxaaBuffer.SetGlobalVector(fxaaConfigId, new Vector4(
                fxaa.fixedThreshold, fxaa.relativeThreshold, fxaa.subpixelBlending
            ));
        }

        void RenderFXAA()
        {
            fxaaBuffer.Clear();

            // fxaaBuffer.SetGlobalFloat(SrcBlendId, 1f);
            // fxaaBuffer.SetGlobalFloat(DstBlendId, 0f);

            ConfigureFXAA();

            fxaaBuffer.GetTemporaryRT(
                _FXAA_SourceId, renderCamera.pixelWidth, renderCamera.pixelHeight, 0, FilterMode.Bilinear, RenderTextureFormat.Default
                );

            fxaaBuffer.Blit(BuiltinRenderTextureType.CameraTarget, _FXAA_SourceId);

            if (fxaa.luminanceMode == LuminanceMode.Green)
            {
                fxaaBuffer.BlitSRT(_FXAA_SourceId, BuiltinRenderTextureType.CameraTarget, fxaaMaterial, (int)FXAAPass.FXAAWithGreen);
            }
            else
            {
                FXAAPass luminancePass = fxaa.luminanceMode == LuminanceMode.Luminance ? FXAAPass.Luminance : FXAAPass.Log_Luminance;

                fxaaBuffer.GetTemporaryRT(
                    _Luminace_Tex_Id, renderCamera.pixelWidth, renderCamera.pixelHeight, 0, FilterMode.Bilinear, RenderTextureFormat.Default
                );
                fxaaBuffer.BlitSRT(_FXAA_SourceId, _Luminace_Tex_Id, fxaaMaterial, (int)luminancePass);
                fxaaBuffer.BlitSRT(_Luminace_Tex_Id, BuiltinRenderTextureType.CameraTarget, fxaaMaterial, (int)FXAAPass.FXAAWithLuma);
            }

            fxaaBuffer.ReleaseTemporaryRT(_FXAA_SourceId);
        }


    }
}
