using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Assertions;

public class Texture3DViewer : MonoBehaviour {

    [SerializeField]
    private CloudTexture _noiseTex;
    [SerializeField]
    private Texture3D _targetTexture;

    [SerializeField]
    private Texture2D _mappedTexture;

    struct int2
    {
        public int x;
        public int y;
        public int2(int _x, int _y)
        {
            x = _x;
            y = _y;
        }
    }
    void FillData(Color[] destination, int2 destSize, Color[] source, int2 sourceSize, int2 start)
    {
        Assert.IsNotNull(destination);
        Assert.IsNotNull(source);

        int index = start.y * sourceSize.x * destSize.x + start.x * sourceSize.y;
        int sourceIndex = 0;
        for (uint i = 0; i < sourceSize.x; ++i)
        {
            for (uint j = 0; j < sourceSize.y; ++j)
            {
                var c = source[sourceIndex++];
                destination[index++] = new Color(c.a, c.a, c.a, 1);
                Debug.LogFormat("{0}", c);
            }
            index += destSize.x - sourceSize.x;
        }
    }

    // Use this for initialization
    void Start()
    {
        
    }

    public void MapData(Texture3D texture)
    {
        this._targetTexture = texture;

        Assert.IsNotNull(_targetTexture);

        int depthDimension = Mathf.CeilToInt(Mathf.Sqrt(this._targetTexture.depth));
        int weight = this._targetTexture.width * depthDimension;
        int height = this._targetTexture.height * depthDimension;

        _mappedTexture = new Texture2D(weight, height, TextureFormat.RGBA32, false);

        Color[] data = new Color[weight * height];
        Color[] targetData = this._targetTexture.GetPixels();

        int2 destSize = new int2(_mappedTexture.width, _mappedTexture.height);
        int2 sourceSize = new int2(_targetTexture.width, _targetTexture.height);

        for (int i = 0; i < depthDimension; ++i)
        {
            for (int j = 0; j < depthDimension; ++j)
            {
                int2 start = new int2(i, j);
                FillData(data, destSize, targetData, sourceSize, start);
            }
        }



        this._mappedTexture.SetPixels(data);
        this._mappedTexture.Apply();
    }


    private void OnGUI()
    {
        GUI.DrawTexture(new Rect(0, 0, this._mappedTexture.width, this._mappedTexture.height), this._mappedTexture);
    }
    // Update is called once per frame
    void Update()
    {

    }
}
