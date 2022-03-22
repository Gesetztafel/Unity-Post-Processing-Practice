using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Gesetz
{
    public static class GraphisUilities
    {
        public static Mesh s_FullscreenTriangle;

        public static Mesh FullscreenTriangle
        {
            get
            {
                if (s_FullscreenTriangle != null)
                    return s_FullscreenTriangle;
                s_FullscreenTriangle = new Mesh() { name = "Fullscreen Triangle" };
                s_FullscreenTriangle.SetVertices(new List<Vector3>
                  {
                      new Vector3(-1f, -1f, 1f),
                      new Vector3(3f,  -1f, 1f),
                      new Vector3(-1f, 3f, 1f)
                  });
                s_FullscreenTriangle.SetIndices(new int[] { 0, 1, 2 }, MeshTopology.Triangles, 0, false);
                s_FullscreenTriangle.UploadMeshData(false);

                return s_FullscreenTriangle;
            }
        }

        public static void BlitSRT(this CommandBuffer buffer, RenderTargetIdentifier dest, Material mat, int pass)
        {
            buffer.SetRenderTarget(dest);
            buffer.DrawMesh(FullscreenTriangle, Matrix4x4.identity, mat, 0, pass);
        }
        public static void BlitSRT(this CommandBuffer buffer, Texture src, RenderTargetIdentifier dest, Material mat, int pass)
        {
            buffer.SetGlobalTexture(ShaderIDs._MainTex, src);
            buffer.SetRenderTarget(dest);
            buffer.DrawMesh(FullscreenTriangle, Matrix4x4.identity, mat, 0, pass);
        }
        public static void BlitSRT(this CommandBuffer buffer, RenderTargetIdentifier src, RenderTargetIdentifier dest, Material mat, int pass)
        {
            buffer.SetGlobalTexture(ShaderIDs._MainTex, src);
            buffer.SetRenderTarget(dest);
            buffer.DrawMesh(FullscreenTriangle, Matrix4x4.identity, mat, 0, pass);
        }
        public static void BlitMRT(this CommandBuffer buffer, Texture src, RenderTargetIdentifier[] colorIdentifier, Material mat, int pass)
        {
            buffer.SetRenderTarget(colorIdentifier, BuiltinRenderTextureType.CameraTarget);
            buffer.DrawMesh(FullscreenTriangle, Matrix4x4.identity, mat, 0, pass);
        }
        public static void BlitMRT(this CommandBuffer buffer, RenderTargetIdentifier[] colorIdentifier, Material mat, int pass)
        {
            buffer.SetRenderTarget(colorIdentifier, BuiltinRenderTextureType.CameraTarget);
            buffer.DrawMesh(FullscreenTriangle, Matrix4x4.identity, mat, 0, pass);
        }


    }
}
