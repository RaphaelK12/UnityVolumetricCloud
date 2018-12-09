/*!
 * File: Cloud.cs
 * Date: 2018/03/02 16:50
 *
 * Author: Yuan Li
 * Contact: vanish8.7@gmail.com
 *
 * Description:
 *
 * 
 */
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Cloud : MonoBehaviour {

    [SerializeField]
    private Shader _cloudShader;
    private Material _mat;
    private Camera _camera;

    [SerializeField]
    private Texture3D _cloudBaseTexture;
    [SerializeField]
    private Texture3D _cloudDetailTexture;
    [SerializeField]
    private Texture2D _curlNoiseTexture;

    [SerializeField]
    private Texture2D _weatherTexture;

    [SerializeField]
    private Texture2D _heightTexture1;
    [SerializeField]
    private Texture2D _heightTexture2;
    [SerializeField]
    private Texture2D _heightTexture3;

    [SerializeField]
    [Range(0, 100)]
    private float _start = 20;

    [SerializeField]
    [Range(0, 10000)]
    private float _sample = 2300;

    [SerializeField]
    private float _cloudHeightMin = 1500;
    [SerializeField]
    private float _cloudHeightMax = 3500;


    [SerializeField]
    private float _cloudBaseUVScale = 5;
    [SerializeField]
    private float _cloudDetailUVScale = 5;

    [SerializeField]
    private float _curlNoiseUVScale = 1;

    [SerializeField]
    private float _weatherUVScale = 1;

    [SerializeField]
    private float AbsportionCoEff = 0;
    [SerializeField, Range(0.01f, 1f)]
    private float ScatteringCoEff = 0.01f;
    [SerializeField, Range(0f, 1f)]
    private float PowderCoEff = 0.01f;
    [SerializeField, Range(0f, 1f)]
    private float PowderScale = 1f;

    [SerializeField, Range(0.01f, 0.9f)]
    private float _hg = 0.6f;

    [SerializeField, Range(0.01f, 5f)]
    private float _silverIntensity = 1f;
    [SerializeField, Range(0.01f, 1f)]
    private float _silverSpread = 0.6f;

    [SerializeField, Range(0.0005f, 1f)]
    private float _lightingStepScale = 0.01f;
    [SerializeField]
    private float _cloudStepScale = 1f;

    [SerializeField, Range(0,2)]
    private float coverageScale = 1.0f;

    [SerializeField, Range(0.1f, 100)]
    private float cloudDensityScale = 1;

    [SerializeField]
    private Color _cloudTopColor;
    [SerializeField]
    private Color _cloudBottomColor;

    [SerializeField]
    private bool _enableBeer = true;
    [SerializeField]
    private bool _enableHG = true;

    [SerializeField]
    private Vector4 _textureBias = new Vector4(1, 1, 1, 0);
    [SerializeField, Range(0, 1)]
    private float _anvilBias = 0.3f;


    [SerializeField]
    private ObjectProjection _depthTarget;

    // Use this for initialization
    void Start ()
    {
        this._mat = new Material(this._cloudShader);
        this._camera = this.GetComponent<Camera>();       
    }
	
	// Update is called once per frame
	void Update ()
    {
        //samve as GL.GetGPUProjectionMatrix(this._camera.projectionMatrix.inverse, false);
        var invMat = GL.GetGPUProjectionMatrix(this._camera.projectionMatrix, false).inverse;
        this._mat.SetMatrix("_MainCameraInvProj", invMat);
        this._mat.SetMatrix("_MainCameraInvView", this._camera.cameraToWorldMatrix);
        this._mat.SetVector("_CameraPosWS", this._camera.transform.position);
        this._mat.SetFloat("_CameraNearPlane", this._camera.nearClipPlane);

        this._mat.SetTexture("_NoiseTex", this._cloudBaseTexture);
        this._mat.SetTexture("_CloudDetailTexture", this._cloudDetailTexture);
        this._mat.SetTexture("_CurlNoiseTexture", this._curlNoiseTexture);

        this._mat.SetTexture("_HeightType1", this._heightTexture1);
        this._mat.SetTexture("_HeightType2", this._heightTexture2);
        this._mat.SetTexture("_HeightType3", this._heightTexture3);

        this._mat.SetTexture("_Weather", this._weatherTexture);
        this._mat.SetTexture("_DepthWeather", this._depthTarget.renderTexture);

        this._mat.SetFloat("_StartValue", this._start);
        this._mat.SetFloat("_SampleValue", this._sample);

        this._mat.SetVector("_CloudHeightMaxMin", new Vector4(this._cloudHeightMax, this._cloudHeightMin, this._cloudHeightMax - this._cloudHeightMin, 0));


        this._mat.SetFloat("_CloudBaseUVScale", this._cloudBaseUVScale);
        this._mat.SetFloat("_CloudDetailUVScale", this._cloudDetailUVScale); 
        this._mat.SetFloat("_WeatherUVScale", this._weatherUVScale);
        this._mat.SetFloat("_CurlNoiseUVScale", this._curlNoiseUVScale);

        this._mat.SetFloat("_AbsportionCoEff", this.AbsportionCoEff);
        this._mat.SetFloat("_ScatteringCoEff", this.ScatteringCoEff);
        this._mat.SetFloat("_PowderCoEff", this.PowderCoEff);
        this._mat.SetFloat("_PowderScale", this.PowderScale); 
        this._mat.SetFloat("_HG", this._hg);
        this._mat.SetFloat("_SilverIntensity", this._silverIntensity);
        this._mat.SetFloat("_SilverSpread", this._silverSpread);

        this._mat.SetFloat("_LightingStepScale", this._lightingStepScale);
        this._mat.SetFloat("_CloudStepScale", this._cloudStepScale);
        this._mat.SetFloat("_CoverageScale", this.coverageScale);
        this._mat.SetFloat("_CloudDensityScale", this.cloudDensityScale);

        this._mat.SetVector("_CloudTopColor", this._cloudTopColor);
        this._mat.SetVector("_CloudBottomColor", this._cloudBottomColor);

        this._mat.SetVector("_CloudNoiseBias", this._textureBias);
        this._mat.SetFloat("_AnvilBias", this._anvilBias);

    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, this._mat);
    }

	void OnGUI()
	{
		GUI.Label (new Rect(10,10,100,30), "Cloud Coverage");
		coverageScale = GUI.HorizontalSlider (new Rect (10, 50, 100, 30), coverageScale, 0,2);
	}
}
