using System;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

[Serializable]
[PostProcess(typeof(PostProcessOutlineRenderer), PostProcessEvent.BeforeStack, "Custom/Post Process Outline", allowInSceneView: false)]
public sealed class PostProcessOutline : PostProcessEffectSettings
{
    [Tooltip("Number of pixels between samples that are tested for an edge. When this value is 1, tested samples are adjacent.")]
    public IntParameter pixelScale = new IntParameter { value = 1 };

    [Tooltip("Difference between depth values, scaled by the current depth, required to draw an edge.")]
    public FloatParameter depthThreshold = new FloatParameter { value = 1.5f };

    [Tooltip("Larger values will require the difference between normals to be greater to draw an edge.")]
    [Range(0f, 1f)]
    public FloatParameter normalThreshold = new FloatParameter { value = 0.4f };

    [Tooltip("The value at which the dot product between the surface normal and the view direction will affect " +
        "the depth threshold. This ensures that surfaces at right angles to the camera require a larger depth threshold to draw " +
        "an edge, avoiding edges being drawn along slopes.")]
    [Range(0f, 1f)]
    public FloatParameter depthNormalThreshold = new FloatParameter { value = 0.5f };

    [Tooltip("Scale the strength of how much the depthNormalThreshold affects the depth threshold.")]
    public FloatParameter depthNormalThresholdScale = new FloatParameter { value = 7f };

    public ColorParameter edgeColor = new ColorParameter { value = Color.black };
}

public sealed class PostProcessOutlineRenderer : PostProcessEffectRenderer<PostProcessOutline>
{

    private Shader _shader;

    public override DepthTextureMode GetCameraFlags()
    {
        return DepthTextureMode.Depth;
        //return DepthTextureMode.Depth | DepthTextureMode.DepthNormals;
    }

    public override void Init()
    {
        if (_shader == null)
            _shader = Shader.Find("Hidden/Outline Post Process");
    }

    public override void Render(PostProcessRenderContext context)
    {
        var sheet = context.propertySheets.Get(_shader);
        var properties = sheet.properties;
        properties.SetFloat("_PixelScale", settings.pixelScale);
        properties.SetFloat("_DepthThreshold", settings.depthThreshold);
        properties.SetFloat("_NormalThreshold", settings.normalThreshold);
        properties.SetFloat("_DepthNormalThreshold", settings.depthNormalThreshold);
        properties.SetFloat("_DepthNormalThresholdScale", settings.depthNormalThresholdScale);
        properties.SetColor("_EdgeColor", settings.edgeColor);

        Matrix4x4 clipToView = GL.GetGPUProjectionMatrix(context.camera.projectionMatrix, true).inverse;
        properties.SetMatrix("_ClipToView", clipToView);

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
    }

}
