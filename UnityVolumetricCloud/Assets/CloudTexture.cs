using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Assertions;

public class CloudTexture : MonoBehaviour {

    #region const fields
    const int kSizeOfVolume = 16;
    const int kNumberOfBuffer = kSizeOfVolume * kSizeOfVolume * kSizeOfVolume;
    #endregion

    #region member variables
    [SerializeField]
    private Texture3D _noiseTexture;
    [SerializeField]
    [Range(0, kSizeOfVolume-1)] private int _debugLayer = 0;
    private Texture2D _debugTexture;
    private Color[] _debugData;

    private Particle[] _data;

    [SerializeField] private Shader _rs;
    [SerializeField] private float _particleSize = 0.1f;

    ComputeBuffer _buffer;
    struct Particle
    {
        public Vector3 position;
        public Vector4 color;
    }
    Material _mat;
    #endregion


    #region public functions
    public void CreateVolumeTexture()
    {
        if(this._noiseTexture != null)
        {
            Destroy(this._noiseTexture);
        }

        this._noiseTexture = new Texture3D(kSizeOfVolume, kSizeOfVolume, kSizeOfVolume, TextureFormat.Alpha8, false);
        this._debugTexture = new Texture2D(kSizeOfVolume, kSizeOfVolume, TextureFormat.ARGB32, false);
        this._debugData = new Color[kSizeOfVolume* kSizeOfVolume];
    }

    #endregion

    #region private functions

    void InitRenderData()
    {
        Assert.IsNotNull(_rs);
        this._buffer = new ComputeBuffer(kNumberOfBuffer, Marshal.SizeOf(typeof(Particle)));

        this._mat = new Material(this._rs);
    }
    void FillTextureData(Texture3D texture)
    {
        Assert.IsNotNull(texture);
        Assert.IsTrue(texture.width == texture.height);
        Assert.IsTrue(texture.width == texture.depth);
        Assert.IsTrue(texture.width == kSizeOfVolume);

        var noiseGenerater = new NoiseTools.PerlinNoise(10, 1, 0);

        this._data = new Particle[kSizeOfVolume * kSizeOfVolume * kSizeOfVolume];
        var data = new Color[kSizeOfVolume * kSizeOfVolume * kSizeOfVolume];
        var index = 0;
        var scale = 1.0f / kNumberOfBuffer;

        var min = float.MaxValue;
        var max = float.MinValue;

        for(uint i = 0; i < kSizeOfVolume; ++i)
        {
            var x = i * scale;
            for (uint j = 0; j < kSizeOfVolume; ++j)
            {
                var y = j * scale;
                for (uint k = 0; k < kSizeOfVolume; ++k)
                {
                    var z = k * scale;

                    var c = noiseGenerater.GetFractal(x, y, z, 5);
                    data[index] = new Color(c, c, c, c);

                    this._data[index].position = new Vector3(i, j, k);
                    this._data[index].color = new Vector4(c, c, c, c);
                    index++;

                    Debug.LogFormat("{0}", c);

                    max = c > max ? c : max;
                    min = c < min ? c : min;

                }
            }
        }


        Debug.LogFormat("{0}, {1}", min, max);

        this._noiseTexture.SetPixels(data);
        this._noiseTexture.Apply();

    }

    // Use this for initialization
    void Start () {
        this.CreateVolumeTexture();
        this.InitRenderData();

        this.FillTextureData(this._noiseTexture);

        Assert.IsNotNull(_data);
        this._buffer.SetData(this._data);
    }
	
	// Update is called once per frame
	void Update ()
    {
        var debugIndex = 0;
        var index = this._debugLayer * kSizeOfVolume * kSizeOfVolume;
        for (uint j = 0; j < kSizeOfVolume; ++j)
        {
            for (uint k = 0; k < kSizeOfVolume; ++k)
            {
                this._debugData[debugIndex++] = (this._data[index].color - new Vector4(0.4f, 0.4f, 0.4f, 0.4f)) * 10;
                index++;
            }
        }

        this._debugTexture.SetPixels(this._debugData);
        this._debugTexture.Apply();
    }

    private void OnGUI()
    {
        GUI.DrawTexture(new Rect(0, 0, 512, 512), this._debugTexture);
    }

    private void OnRenderObject()
    {
        Assert.IsNotNull(this._mat);
        this._mat.SetPass(0);
        this._mat.SetBuffer("_buffer", this._buffer);
        this._mat.SetMatrix("_inv_view_mat", Camera.main.worldToCameraMatrix.inverse);
        this._mat.SetFloat("_particle_size", this._particleSize);

        Graphics.DrawProcedural(MeshTopology.Points, kNumberOfBuffer);
    }
    #endregion
}
