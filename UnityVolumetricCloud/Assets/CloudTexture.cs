using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Assertions;

public class CloudTexture : MonoBehaviour {

    #region const fields
    const int kSizeOfVolume = 32;
    const int kdepth = 32;
    const int kNumberOfBuffer = kSizeOfVolume * kSizeOfVolume * kdepth;
    #endregion

    #region member variables
    [SerializeField]
    private Texture3D _noiseTexture;

    [SerializeField]
    private Texture2D _coverageTexture;

    public Texture3D NoiseTexture
    {
        get { return _noiseTexture; }
    }
    [SerializeField]
    [Range(0, kdepth - 1)] private int _debugLayer = 0;
    [SerializeField]
    [Range(0, 3)] private int _colorLayer = 0;
    [SerializeField]
    private bool _displayDebugTexture = false;
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
        if (this._noiseTexture != null)
        {
            Destroy(this._noiseTexture);
        }

        this._noiseTexture = new Texture3D(kSizeOfVolume, kSizeOfVolume, kdepth, TextureFormat.ARGB32, false);

        this._debugTexture = new Texture2D(kSizeOfVolume, kSizeOfVolume, TextureFormat.ARGB32, false);
        this._debugData = new Color[kSizeOfVolume * kSizeOfVolume];
    }

    #endregion

    #region private functions

    void InitRenderData()
    {
        Assert.IsNotNull(_rs);
        this._buffer = new ComputeBuffer(kNumberOfBuffer, Marshal.SizeOf(typeof(Particle)));

        this._mat = new Material(this._rs);
    }

    // Utility function that maps a value from one range to another.
    float Remap(float original_value, float original_min, float original_max, float new_min, float new_max)
    {
        return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
    }

    float InvertWorley(float worley)
    {
        worley = worley * Mathf.Lerp(1, 2.0f, worley);
        return 1-worley;
    }

    void FillTextureData(Texture3D texture)
    {
        Assert.IsNotNull(texture);
        Assert.IsTrue(texture.width == texture.height);
        //Assert.IsTrue(texture.width == texture.depth);
        Assert.IsTrue(texture.width == kSizeOfVolume);

        var perlinNoise = new NoiseTools.PerlinNoise(4, 1, 0);
        var worleyNoise = new NoiseTools.WorleyNoise(7, 1, 0);

        var worleyNoiseF1 = new NoiseTools.WorleyNoise(10, 1, 0);
        var worleyNoiseF2 = new NoiseTools.WorleyNoise(15, 1, 0);
        var worleyNoiseF3 = new NoiseTools.WorleyNoise(20, 1, 0);


        this._data = new Particle[kNumberOfBuffer];
        var data = new Color[kNumberOfBuffer];
        var index = 0;
        var scale = 1.0f / kSizeOfVolume;

        var min = float.MaxValue;
        var max = float.MinValue;

        for(uint i = 0; i < kSizeOfVolume; ++i)
        {
            var x = i * scale;
            for (uint j = 0; j < kSizeOfVolume; ++j)
            {
                var y = j * scale;
                for (uint k = 0; k < kdepth; ++k)
                {
                    var z = k * scale;

                    var perlin = perlinNoise.GetFractal(x, y, z, 4);
                    var worley = worleyNoise.GetFractal(x, y, z, 2);
                    var worleyf1 = worleyNoiseF1.GetFractal(x, y, z, 2);
                    var worleyf2 = worleyNoiseF2.GetFractal(x, y, z, 2);
                    var worleyf3 = worleyNoiseF3.GetFractal(x, y, z, 2);

                    var perlin_worley = this.Remap(perlin, -InvertWorley(worley), 1, 0, 1);

                    data[index] = new Color(perlin_worley, InvertWorley(worleyf1), InvertWorley(worleyf2), InvertWorley(worleyf3));

                    this._data[index].position = new Vector3(i, j, k);
                    this._data[index].color = new Vector4(perlin_worley, worleyf1, worleyf2, worleyf3);
                    index++;

                    //Debug.LogFormat("{0}", c);

                    //max = c > max ? c : max;
                    //min = c < min ? c : min;

                }
            }
        }


        Debug.LogFormat("{0}, {1}", min, max);

        this._noiseTexture.SetPixels(data);
        this._noiseTexture.Apply();

    }

    // Use this for initialization
    void Awake () {
        this.CreateVolumeTexture();
        this.InitRenderData();

        this.FillTextureData(this._noiseTexture);

        Assert.IsNotNull(_data);
        this._buffer.SetData(this._data);

        //FindObjectOfType<Texture3DViewer>().MapData(this.NoiseTexture);
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
                var c = this._data[index].color[_colorLayer];
                this._debugData[debugIndex++] = new Color(c, c, c, 1);
                index++;
            }
        }

        this._debugTexture.SetPixels(this._debugData);
        this._debugTexture.Apply();
    }

    private void OnGUI()
    {
        if(_displayDebugTexture)
        {
            GUI.DrawTexture(new Rect(0, 0, 512, 512), this._debugTexture);
        }
    }

    private void OnRenderObject()
    {
        Assert.IsNotNull(this._mat);
        this._mat.SetPass(0);
        this._mat.SetBuffer("_buffer", this._buffer);
        this._mat.SetMatrix("_inv_view_mat", Camera.main.worldToCameraMatrix.inverse);
        this._mat.SetFloat("_particle_size", this._particleSize);
        
        //Graphics.DrawProcedural(MeshTopology.Points, kNumberOfBuffer);
    }
    #endregion
}
