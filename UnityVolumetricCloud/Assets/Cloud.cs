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
    private Texture2D _weatherTexture;

    [SerializeField]
    private Texture2D _heightTexture;

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
    private float _weatherUVScale = 1;

    [SerializeField]
    private float AbsportionCoEff = 0;
    [SerializeField]
    private float ScatteringCoEff = 0.01f;

    [SerializeField, Range(0.0005f, 1f)]
    private float _lightingStepScale = 0.01f;
    [SerializeField]
    private float _cloudStepScale = 1f;

    [SerializeField, Range(0,2)]
    private float coverageScale = 1.0f;

    [SerializeField, Range(0.1f, 100)]
    private float cloudDensityScale = 1;

    [SerializeField]
    private bool _enableBeer = true;
    [SerializeField]
    private bool _enableHG = true;


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
        this._mat.SetTexture("_Height", this._heightTexture);
        this._mat.SetTexture("_Weather", this._weatherTexture);
        this._mat.SetTexture("_DepthWeather", this._depthTarget.renderTexture);

        this._mat.SetFloat("_StartValue", this._start);
        this._mat.SetFloat("_SampleValue", this._sample);

        this._mat.SetVector("_CloudHeightMaxMin", new Vector4(this._cloudHeightMax, this._cloudHeightMin, this._cloudHeightMax - this._cloudHeightMin, 0));


        this._mat.SetFloat("_CloudBaseUVScale", this._cloudBaseUVScale);
        this._mat.SetFloat("_WeatherUVScale", this._weatherUVScale);

        this._mat.SetFloat("_AbsportionCoEff", this.AbsportionCoEff);
        this._mat.SetFloat("_ScatteringCoEff", this.ScatteringCoEff);
        this._mat.SetFloat("_LightingStepScale", this._lightingStepScale);
        this._mat.SetFloat("_CloudStepScale", this._cloudStepScale);
        this._mat.SetFloat("_CoverageScale", this.coverageScale);
        this._mat.SetFloat("_CloudDensityScale", this.cloudDensityScale);
        
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, this._mat);
    }
}
