using UnityEngine;
using UnityEngine.Rendering;

namespace Gesetz
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    public class SSAO : MonoBehaviour
    {
        public enum AOPass
        {
            Downsample,
            ScalableAO,
            BlurX,
            BlurY,
            Upsample,
            Compisition,
            Debug_overlay
        }

        public enum ResolutionMode
        {
            HalfRes = 1,
            FullRes = 2
        };

        #region Shader Properties

        [SerializeField, Range(0.5f, 2.0f)]
        float _RadiusWorld = 1.0f;

        [SerializeField]
        float _maxRadiusScreen = 0.8f;

        [SerializeField, Range(1.0f, 6.0f)]
        float _Contrast = 4.0f;


        public Vector4 AOParams
        {
            get { return new Vector4(_RadiusWorld, _maxRadiusScreen, _Contrast); }
        }

        [SerializeField, Range(12, 64)] int _sampleCount = 16;


        [SerializeField] bool _debug = false;

        public bool Debug
        {
            get { return _debug; }
            set { _debug = value; }
        }

        #endregion

        #region Base Properties

        private Camera renderCamera;
        private Material aoMaterial;
        private CommandBuffer aoBuffer = null;

        private ResolutionMode resolutionMode = ResolutionMode.HalfRes;

        private Vector2 RenderResolution;
        private Vector2 CameraSize;

        //ShaderIDs
        private static int
            _AOParams_ID = Shader.PropertyToID("_AOParams"),
            _SampleCount_ID = Shader.PropertyToID("_SampleCount");

        private static int
            _ssaoTexture_upsample_ID = Shader.PropertyToID("_ssaoTexture_upsample"),
            _depth_Texture_x4_ID = Shader.PropertyToID("_depth_Texture_x4"),
            _ssaoTexture_x4_ID = Shader.PropertyToID("_ssaoTexture_x4"),
            _AO_ColorTex_ID = Shader.PropertyToID("_AO_ColorTex");

        private RenderTexture
            _ssaoTexture_upsample_RT,
            _depth_Texture_x4_RT,
            _ssaoTexture_x4_RT,
            _ssao_BlurXTexture_x4_RT,
            _ssao_BlurTexture_x4_RT,
            _AO_ColorTex;

        #endregion

        #region MonoBehaviour functions

        private void Awake()
        {
            renderCamera = gameObject.GetComponent<Camera>();
            if (aoMaterial == null)
            {
                aoMaterial = new Material(Shader.Find("Gesetz/SSAO"));
                aoMaterial.hideFlags = HideFlags.DontSave;
            }
        }

        private void OnEnable()
        {
            if (aoBuffer == null)
            {
                aoBuffer = new CommandBuffer();
                aoBuffer.name = "SSAO";
            }
            renderCamera.AddCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, aoBuffer);
        }

        private void OnPreRender()
        {
            RenderResolution = new Vector2(renderCamera.pixelWidth, renderCamera.pixelHeight);
            UpdateVarible();

            if (aoBuffer != null)
            {
                RenderSSAO();
            }
        }

        private void OnDisable()
        {
            if (aoBuffer != null)
            {
                renderCamera.RemoveCommandBuffer(CameraEvent.BeforeImageEffectsOpaque, aoBuffer);
                aoBuffer = null;
            }
        }

        private void OnDestroy()
        {
            ReleaseBuffers();
            if (aoBuffer != null)
            {
                aoBuffer.Dispose();
            }
        }
        #endregion


        #region SSAO Functions

        void UpdateMaterialProperties()
        {
            aoMaterial.SetVector(_AOParams_ID, AOParams);
            aoMaterial.SetInt(_SampleCount_ID, _sampleCount);
        }

        void UpdateVarible()
        {
            Vector2 CameraSize = new Vector2(renderCamera.pixelWidth, renderCamera.pixelHeight);

            RenderTexture.ReleaseTemporary(_AO_ColorTex);
            _AO_ColorTex = RenderTexture.GetTemporary((int)CameraSize.x, (int)CameraSize.y,
                0, RenderTextureFormat.DefaultHDR);
            _AO_ColorTex.filterMode = FilterMode.Bilinear;

            RenderTexture.ReleaseTemporary(_depth_Texture_x4_RT);
            _depth_Texture_x4_RT =
                RenderTexture.GetTemporary((int)CameraSize.x / 2, (int)CameraSize.y / 2, 0, RenderTextureFormat.R16,
                    RenderTextureReadWrite.Linear);
            _depth_Texture_x4_RT.filterMode = FilterMode.Bilinear;

            RenderTexture.ReleaseTemporary(_ssaoTexture_x4_RT);
            _ssaoTexture_x4_RT =
                RenderTexture.GetTemporary((int)CameraSize.x / 2, (int)CameraSize.y / 2, 0, RenderTextureFormat.ARGB32,
                    RenderTextureReadWrite.Linear);
            _ssaoTexture_x4_RT.filterMode = FilterMode.Bilinear;

            RenderTexture.ReleaseTemporary(_ssao_BlurXTexture_x4_RT);
            _ssao_BlurXTexture_x4_RT =
                RenderTexture.GetTemporary((int)CameraSize.x / 2, (int)CameraSize.y / 2, 0, RenderTextureFormat.ARGB32,
                    RenderTextureReadWrite.Linear);

            RenderTexture.ReleaseTemporary(_ssao_BlurTexture_x4_RT);
            _ssao_BlurTexture_x4_RT =
                RenderTexture.GetTemporary((int)CameraSize.x / 2, (int)CameraSize.y / 2, 0, RenderTextureFormat.ARGB32,
                    RenderTextureReadWrite.Linear);

            RenderTexture.ReleaseTemporary(_ssaoTexture_upsample_RT);
            _ssaoTexture_upsample_RT =
                RenderTexture.GetTemporary((int)CameraSize.x, (int)CameraSize.y, 0, RenderTextureFormat.ARGB32,
                    RenderTextureReadWrite.Linear);
            _ssaoTexture_upsample_RT.filterMode = FilterMode.Bilinear;

            UpdateMaterialProperties();
        }

        void ReleaseBuffers()
        {
            RenderTexture.ReleaseTemporary(_depth_Texture_x4_RT);
            RenderTexture.ReleaseTemporary(_ssaoTexture_x4_RT);
            RenderTexture.ReleaseTemporary(_ssao_BlurXTexture_x4_RT);
            RenderTexture.ReleaseTemporary(_ssao_BlurTexture_x4_RT);
            RenderTexture.ReleaseTemporary(_ssaoTexture_upsample_RT);
            RenderTexture.ReleaseTemporary(_AO_ColorTex);
        }

        void RenderSSAO()
        {
            aoBuffer.Clear();

            aoBuffer.SetGlobalTexture(_AO_ColorTex_ID, _AO_ColorTex);
            aoBuffer.CopyTexture(BuiltinRenderTextureType.CameraTarget, _AO_ColorTex);

            //Downsample
            aoBuffer.SetGlobalTexture(_depth_Texture_x4_ID, _depth_Texture_x4_RT);
            aoBuffer.BlitSRT(_depth_Texture_x4_RT, aoMaterial, (int)AOPass.Downsample);
            //Scalable AO
            aoBuffer.SetGlobalTexture(_ssaoTexture_x4_ID, _ssaoTexture_x4_RT);
            aoBuffer.BlitSRT(_depth_Texture_x4_RT, _ssaoTexture_x4_RT, aoMaterial, (int)AOPass.ScalableAO);
            //BlurX
            aoBuffer.BlitSRT(_ssao_BlurXTexture_x4_RT, aoMaterial, (int)AOPass.BlurX);
            //BlurY
            aoBuffer.BlitSRT(_ssao_BlurXTexture_x4_RT, _ssao_BlurTexture_x4_RT, aoMaterial, (int)AOPass.BlurY);
            //Upsample
            aoBuffer.SetGlobalTexture(_ssaoTexture_upsample_ID, _ssaoTexture_upsample_RT);
            aoBuffer.BlitSRT(_ssao_BlurTexture_x4_RT, _ssaoTexture_upsample_RT, aoMaterial, (int)AOPass.Upsample);

            AOPass combinePass = Debug ? AOPass.Debug_overlay : AOPass.Compisition;

            aoBuffer.BlitSRT(_ssaoTexture_upsample_RT, BuiltinRenderTextureType.CameraTarget, aoMaterial, (int)combinePass);
        }


        #endregion
    }
}
