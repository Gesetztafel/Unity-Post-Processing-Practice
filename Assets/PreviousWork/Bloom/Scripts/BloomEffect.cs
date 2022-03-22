using UnityEngine;
using UnityEngine.Rendering;

namespace Gesetz
{
    [ExecuteInEditMode]
    [ImageEffectAllowedInSceneView]
    [RequireComponent(typeof(Camera))]
    public class BloomEffect : MonoBehaviour
    {
        enum BloomPass
        {
            BloomAdd,
            BloomHorizontal,
            BloomPrefilter,
            BloomPrefilterFireflies,
            BloomScatter,
            BloomScatterFinal,
            BloomVertical,
            Copy,
            ToneMappingACES
        }

        int
            bloomBicubicUpsamplingId = Shader.PropertyToID("_BloomBicubicUpsampling"),
            bloomIntensityId = Shader.PropertyToID("_BloomIntensity"),
            bloomPrefilterId = Shader.PropertyToID("_BloomPrefilter"),
            bloomResultId = Shader.PropertyToID("_BloomResult"),
            bloomThresholdId = Shader.PropertyToID("_BloomThreshold");

        private int
            bloomSourceId = Shader.PropertyToID("_BloomSource"),
            bloomSource2Id = Shader.PropertyToID("_BloomSource2"),
            bloomColorId = Shader.PropertyToID("_Bloom_Color");

        private const int maxBloomPyramidLevels = 16;

        private int bloomPyramidID;

        public void BloomInit()
        {
            bloomPyramidID = Shader.PropertyToID("_BloomPyramid0");
            for (int i = 1; i < maxBloomPyramidLevels * 2; ++i)
            {
                Shader.PropertyToID("_BloomPyramid" + i);
            }
        }

        public enum BloomMode
        {
            Additive,
            Scattering
        }

        [System.Serializable]
        public struct BloomSettings
        {
            [Range(0f, 16f)] public int maxIterations;
            [Min((1f))] public int downscaleLimit;
            public bool bicubicUpsampling;
            [Min(0f)] public float threshold;
            [Range(0f, 1f)] public float thresholdKnee;

            [Min(0f)] public float intensity;

            public bool fadeFireflies;

            public BloomMode bloomMode;
            [Range(0.05f, 0.95f)] public float scatter;
        }

        [SerializeField]
        private BloomSettings bloom = new BloomSettings
        {
            maxIterations = 4,
            downscaleLimit = 1,
            threshold = 1.0f,
            thresholdKnee = 0.5f,
            intensity = 7.0f,
            fadeFireflies = true,
            bloomMode = BloomMode.Scattering,
            scatter = 0.7f
        };

        [SerializeField] public bool useHDR = true;

        [SerializeField] public bool useToneMapping = false;

        // int
        //     SrcBlendId = Shader.PropertyToID("_SrcBlend"),
        //     DstBlendId = Shader.PropertyToID("_DstBlend");
        //
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

        private Camera renderCamera;

        [System.NonSerialized] private Material bloomMaterial;


        private const string bufferName = "Bloom Buffer";

        private CommandBuffer bloomBuffer = null;

        private Vector2Int bufferSize;

        private void Awake()
        {
            renderCamera = gameObject.GetComponent<Camera>();
            if (useHDR)
                renderCamera.allowHDR = true;
            Shader bloomShader = Shader.Find("Hidden/Gesetz/Bloom");
            if (bloomMaterial == null)
            {
                bloomMaterial = new Material(bloomShader);
                bloomMaterial.hideFlags = HideFlags.DontSave;
            }
        }

        private void OnEnable()
        {
            if (bloomBuffer == null)
            {
                bloomBuffer = new CommandBuffer();
                bloomBuffer.name = bufferName;
            }

            renderCamera.AddCommandBuffer(CameraEvent.AfterImageEffects, bloomBuffer);
        }

        private void OnPreRender()
        {
            if (bloomBuffer != null)
            {
                RenderBloom();
            }
        }

        private void OnDisable()
        {
            if (bloomBuffer != null)
            {
                renderCamera.RemoveCommandBuffer(CameraEvent.AfterImageEffects, bloomBuffer);
                bloomBuffer = null;
            }
        }

        private void OnDestroy()
        {
            if (bloomBuffer != null)
                bloomBuffer.Dispose();
        }

        void RenderBloom()
        {
            bloomBuffer.Clear();
            //
            BloomInit();
            //TODO-HalfxHalf 
            int width = renderCamera.pixelWidth,
                height = renderCamera.pixelHeight;

            RenderTextureFormat format = useHDR ?
                RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default;

            //grab pass
            bloomBuffer.GetTemporaryRT(
                bloomColorId, width, height, 0, FilterMode.Bilinear, format
                );
            bloomBuffer.Blit(BuiltinRenderTextureType.CameraTarget, bloomColorId);

            if (bloom.maxIterations == 0 || bloom.intensity <= 0f ||
            height < bloom.downscaleLimit * 2 || width < bloom.downscaleLimit * 2)
                return;

            bloomBuffer.BeginSample("Bloom");

            Vector4 threshold;

            threshold.x = Mathf.GammaToLinearSpace(bloom.threshold);
            threshold.y = threshold.x * bloom.thresholdKnee;
            threshold.z = 2f * threshold.y;
            threshold.w = 0.25f / (threshold.y + 0.00001f);
            threshold.y -= threshold.x;
            bloomBuffer.SetGlobalVector(bloomThresholdId, threshold);


            bloomBuffer.GetTemporaryRT(
                bloomPrefilterId, width, height, 0, FilterMode.Bilinear, format
            );
            bloomBuffer.BlitSRT(
                bloomColorId, bloomPrefilterId, bloomMaterial, bloom.fadeFireflies ?
                    (int)BloomPass.BloomPrefilterFireflies : (int)BloomPass.BloomPrefilter
            );

            width /= 2;
            height /= 2;

            int fromId = bloomPrefilterId, toId = bloomPyramidID + 1;
            int i;
            for (i = 0; i < bloom.maxIterations; i++)
            {
                if (height < bloom.downscaleLimit || width < bloom.downscaleLimit)
                {
                    break;
                }
                int midId = toId - 1;
                bloomBuffer.GetTemporaryRT(
                    midId, width, height, 0, FilterMode.Bilinear, format
                );
                bloomBuffer.GetTemporaryRT(
                    toId, width, height, 0, FilterMode.Bilinear, format
                );
                bloomBuffer.BlitSRT(fromId, midId, bloomMaterial, (int)BloomPass.BloomHorizontal);
                bloomBuffer.BlitSRT(midId, toId, bloomMaterial, (int)BloomPass.BloomVertical);
                fromId = toId;
                toId += 2;
                width /= 2;
                height /= 2;
            }

            bloomBuffer.ReleaseTemporaryRT(bloomPrefilterId);
            bloomBuffer.SetGlobalFloat(
                bloomBicubicUpsamplingId, bloom.bicubicUpsampling ? 1f : 0f
            );

            BloomPass combinePass, finalPass;
            float finalIntensity;
            if (bloom.bloomMode == BloomMode.Additive)
            {
                combinePass = finalPass = BloomPass.BloomAdd;
                bloomBuffer.SetGlobalFloat(bloomIntensityId, 1f);
                finalIntensity = bloom.intensity;
            }
            else
            {
                combinePass = BloomPass.BloomScatter;
                finalPass = BloomPass.BloomScatterFinal;
                bloomBuffer.SetGlobalFloat(bloomIntensityId, bloom.scatter);
                finalIntensity = Mathf.Min(bloom.intensity, 1f);
            }


            if (i > 1)
            {
                bloomBuffer.ReleaseTemporaryRT(fromId - 1);
                toId -= 5;
                for (i -= 1; i > 0; i--)
                {
                    bloomBuffer.SetGlobalTexture(bloomSource2Id, toId + 1);
                    bloomBuffer.BlitSRT(fromId, toId, bloomMaterial, (int)combinePass);
                    bloomBuffer.ReleaseTemporaryRT(fromId);
                    bloomBuffer.ReleaseTemporaryRT(toId + 1);
                    fromId = toId;
                    toId -= 2;
                }
            }
            else
            {
                bloomBuffer.ReleaseTemporaryRT(bloomPyramidID);
            }
            bloomBuffer.SetGlobalFloat(bloomIntensityId, finalIntensity);
            bloomBuffer.SetGlobalTexture(bloomSource2Id, bloomColorId);
            bloomBuffer.GetTemporaryRT(
                bloomResultId, renderCamera.pixelWidth, renderCamera.pixelHeight, 0,
                FilterMode.Bilinear, format
            );
            bloomBuffer.BlitSRT(fromId, bloomResultId, bloomMaterial, (int)finalPass);
            bloomBuffer.ReleaseTemporaryRT(fromId);


            bloomBuffer.EndSample("Bloom");

            bloomBuffer.ReleaseTemporaryRT(bloomColorId);


            DoToneMappingAces(bloomResultId);

            bloomBuffer.ReleaseTemporaryRT(bloomResultId);
        }

        void DoToneMappingAces(int sourceId)
        {
            bloomBuffer.BlitSRT(sourceId, BuiltinRenderTextureType.CameraTarget, bloomMaterial, useToneMapping ? (int)BloomPass.ToneMappingACES : (int)BloomPass.Copy);
        }

    }
}
