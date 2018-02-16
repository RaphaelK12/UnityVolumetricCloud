using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class NoiseTexture : MonoBehaviour {


    [SerializeField]
    private Texture2D _noiseTexture;

    [SerializeField]
    [Range(1, 20)]
    private int _frequency = 10;
    [SerializeField]
    [Range(1, 20)]
    private int _repeat = 10;
    [SerializeField]
    [Range(1, 10)]
    private int _fractal = 5;

    [SerializeField]
    private bool _changed = false;

    [SerializeField]
    private bool _usePerlin = false;

    // Use this for initialization
    void Start()
    {
        this.Generate();
    }

    void Generate()
    {
        this._noiseTexture = new Texture2D(256, 256, TextureFormat.RGBA32, false);


        var scale = 1.0f / 256;
        var noisePerlin = new NoiseTools.PerlinNoise(_frequency, _repeat);
        var noiseWorley = new NoiseTools.WorleyNoise(_frequency, _repeat);

        for (int i = 0; i < 256; ++i)
        {
            var x = i * scale;
            for (int j = 0; j < 256; ++j)
            {
                var y = j * scale;
                for (int k = 0; k < 1; ++k)
                {
                    var z = k * scale;
                    var c = noisePerlin.GetFractal(x, y, z, _fractal);
                    c = _usePerlin?noisePerlin.GetAt(x, y):noiseWorley.GetAt(x,y,z);
                    //c = 1 - c;
                    //c = Mathf.Abs(c * 2 - 1);
                    this._noiseTexture.SetPixel(i, j, new Color(c, c, c, 1));
                }
            }
        }

        this._noiseTexture.Apply();
    }
	
	// Update is called once per frame
	void Update () {

        if(_changed)
        {
            this.Generate();
            _changed = false;
        }
    }

    private void OnGUI()
    {
        GUI.DrawTexture(new Rect(0, 0, this._noiseTexture.width, this._noiseTexture.height), this._noiseTexture);
    }
}
