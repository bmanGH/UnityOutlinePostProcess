using UnityEngine;

[ExecuteAlways]
[RequireComponent(typeof(Camera))]
public class RenderViewSpaceNormalsTexture : MonoBehaviour
{

    RenderTextureFormat renderTextureFormat = RenderTextureFormat.ARGB32;
    const FilterMode filterMode = FilterMode.Point;
    const int renderTextureDepth = 32;
    const CameraClearFlags cameraClearFlags = CameraClearFlags.Color;
    static readonly Color background = new Color(0f, 0f, 0f, 0f);
    const DepthTextureMode depthTextureMode = DepthTextureMode.None;
    static readonly int targetTextureID = Shader.PropertyToID("_CameraNormalsTexture");

    private Shader replacementShader;
    private RenderTexture _renderTexture;
    private Camera _thisCamera;
    private Camera _renderCamera;

    private void Start()
    {
        if (replacementShader == null)
            replacementShader = Shader.Find("Hidden/View Space Normals");

        _thisCamera = GetComponent<Camera>();

        CreateRenderTexture();
        CreateRenderCamera();
    }

    private void OnEnable()
    {
        EnableRenderCamera();
    }

    private void OnDisable()
    {
        DisableRenderCamera();
    }

    private void OnDestroy()
    {
        DestroyRenderTexture();
        DestroyRenderCamera();
    }

    private void Update()
    {
        SyncRenderCamera();
    }

    #region - Render Texture

    private void CreateRenderTexture()
    {
        if (_renderTexture == null)
        {
            //RenderTextureFormat renderTextureFormat = RenderTextureFormat.ARGB32;
            //if (SystemInfo.SupportsRenderTextureFormat(RenderTextureFormat.ARGBHalf))
            //    renderTextureFormat = RenderTextureFormat.ARGBHalf;
            _renderTexture = new RenderTexture(_thisCamera.pixelWidth, _thisCamera.pixelHeight, renderTextureDepth, renderTextureFormat);
            _renderTexture.filterMode = filterMode;

            Shader.SetGlobalTexture(targetTextureID, _renderTexture);
        }
    }

    private void DestroyRenderTexture()
    {
        if (_renderTexture != null)
        {
            if (_renderCamera != null)
                _renderCamera.targetTexture = null;

            if (Application.isPlaying)
                Destroy(_renderTexture);
            else
                DestroyImmediate(_renderTexture);
            _renderTexture = null;

            Shader.SetGlobalTexture(targetTextureID, null);
        }
    }

    #endregion

    #region - Render Camera

    private void CreateRenderCamera()
    {
        if (_renderCamera == null)
        {
            GameObject go = new GameObject("Render View Space Normals");
            go.hideFlags = HideFlags.HideAndDontSave;
            go.transform.SetParent(transform);

            _renderCamera = go.AddComponent<Camera>();
            _renderCamera.CopyFrom(_thisCamera);
            _renderCamera.depth = _thisCamera.depth - 1;
            _renderCamera.clearFlags = cameraClearFlags;
            _renderCamera.backgroundColor = background;
            _renderCamera.depthTextureMode = depthTextureMode;
            _renderCamera.SetReplacementShader(replacementShader, "RenderType");

            _renderCamera.targetTexture = _renderTexture;
        }
    }

    private void DestroyRenderCamera()
    {
        if (_renderCamera != null)
        {
            if (Application.isPlaying)
                Destroy(_renderCamera.gameObject);
            else
                DestroyImmediate(_renderCamera.gameObject);
            _renderCamera = null;
        }
    }

    private void EnableRenderCamera()
    {
        if (_renderCamera != null)
        {
            _renderCamera.enabled = true;

            Shader.SetGlobalTexture(targetTextureID, _renderTexture);
        }
    }

    private void DisableRenderCamera()
    {
        if (_renderCamera != null)
        {
            _renderCamera.enabled = false;

            Shader.SetGlobalTexture(targetTextureID, null);
        }
    }

    private void SyncRenderCamera()
    {
        if (_renderCamera != null)
        {
            // Recreate render texture for screen size changed
            if (_renderTexture.width != _thisCamera.pixelWidth || _renderTexture.height != _thisCamera.pixelHeight)
            {
                DestroyRenderTexture();
                CreateRenderTexture();
                _renderCamera.targetTexture = _renderTexture;
            }

            // Sync normals texture render camera with main camera
            _renderCamera.cullingMask = _thisCamera.cullingMask;
            _renderCamera.orthographicSize = _thisCamera.orthographicSize;
            _renderCamera.fieldOfView = _thisCamera.fieldOfView;
            _renderCamera.nearClipPlane = _thisCamera.nearClipPlane;
            _renderCamera.farClipPlane = _thisCamera.farClipPlane;
            _renderCamera.rect = _thisCamera.rect;
        }
    }

    #endregion

}
