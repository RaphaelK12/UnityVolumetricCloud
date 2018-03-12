using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Assertions;

public class ObjectProjection : MonoBehaviour {

    public RenderTexture renderTexture = null;

    private Camera _referenceCamera = null;
    private Shader _replacementShader = null;
    private Material _depthMat = null;

    // Use this for initialization
    void Start () {

        this._referenceCamera = this.GetComponent<Camera>();
        Assert.IsNotNull(this._referenceCamera);

        this._referenceCamera.depthTextureMode = DepthTextureMode.Depth;

        this._replacementShader = Shader.Find("Unlit/DepthShader");
        this._depthMat = new Material(this._replacementShader);

        this.renderTexture = new RenderTexture(this._referenceCamera.pixelWidth, this._referenceCamera.pixelHeight, 0, RenderTextureFormat.Default, RenderTextureReadWrite.Default);
    }
	
	// Update is called once per frame
	void Update () {
		
	}

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, this.renderTexture, this._depthMat);
        Graphics.Blit(source, destination);
    }
}
