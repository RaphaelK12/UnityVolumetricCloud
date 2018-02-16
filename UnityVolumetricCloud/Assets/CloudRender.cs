using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Assertions;

public class CloudRender : MonoBehaviour {

    [SerializeField]
    private Shader _shader;

    private Material _mat;
    private Camera _camera;

    [SerializeField]
    private CloudTexture _noiseTex;

    [SerializeField]
    [Range(0, 100)] private float _start = 20;

    // Use this for initialization
    void Start () {

        this._mat = new Material(this._shader);
        this._camera = this.GetComponent<Camera>();

        this._noiseTex = FindObjectOfType<CloudTexture>();

        //TestPositon();
    }
	
	// Update is called once per frame
	void Update () {


        if (this._noiseTex == null) return;

        //TestPositon();

        //samve as GL.GetGPUProjectionMatrix(this._camera.projectionMatrix.inverse, false);
        var invMat = GL.GetGPUProjectionMatrix(this._camera.projectionMatrix, false).inverse;
        this._mat.SetMatrix("_MainCameraInvProj", invMat);
        this._mat.SetMatrix("_MainCameraInvView", this._camera.cameraToWorldMatrix);
        this._mat.SetVector("_CameraPosWS", this._camera.transform.position);
        this._mat.SetFloat("_CameraNearPlane", this._camera.nearClipPlane);

        this._mat.SetTexture("_NoiseTex", this._noiseTex.NoiseTexture);

        this._mat.SetFloat("_StartValue", this._start);

    }

    private void TestPositon()
    {
        Vector4 pos_near = new Vector4(100, 200, this._camera.nearClipPlane, 1);
        Vector4 pos_far = new Vector4(100, 200, this._camera.farClipPlane, 1);

        Debug.LogFormat("{0}", this._camera.projectionMatrix);

        Matrix4x4 mat = GL.GetGPUProjectionMatrix(this._camera.projectionMatrix, false);
        Debug.LogFormat("{0} gl mat", mat);

        Vector4 cs_pos_near = mat * (pos_near);
        Vector4 cs_pos_far = mat * (pos_far);
        Debug.LogFormat("{0} tranform to {1}", pos_near, cs_pos_near);
        Debug.LogFormat("{0} tranform to {1}", pos_far, cs_pos_far);

        cs_pos_near /= cs_pos_near.w;

        var invMat = GL.GetGPUProjectionMatrix(this._camera.projectionMatrix, false).inverse;
        Debug.LogFormat("{0} mat inv", mat);

        var otherInvMat = GL.GetGPUProjectionMatrix(this._camera.projectionMatrix.inverse, false);
        Debug.LogFormat("{0} inv mat", mat);
        

        Vector4 ws_near = invMat * cs_pos_near;
        Vector4 ws_far = invMat * cs_pos_far;

        Vector3 cs_new = new Vector3(0.3f, 0.5f, -1);
        Vector3 ws_new = invMat.MultiplyPoint(cs_new);
        Debug.LogFormat("{0} recover to {1}", cs_new, ws_new);
        
        cs_new = new Vector3(0.3f, 0.5f, 0);
        ws_new = invMat.MultiplyPoint(cs_new);
        Debug.LogFormat("{0} recover to {1}", cs_new, ws_new);

        cs_new = new Vector3(0.3f, 0.5f, 1);
        ws_new = invMat.MultiplyPoint(cs_new);
        Debug.LogFormat("{0} recover to {1}", cs_new, ws_new);


        Assert.IsTrue(pos_near == ws_near);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, this._mat);
    }

}
