using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CloudRender : MonoBehaviour {

    [SerializeField]
    private Shader _shader;

    private Material _mat;

	// Use this for initialization
	void Start () {

        this._mat = new Material(this._shader);
	}
	
	// Update is called once per frame
	void Update () {
		
	}

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, this._mat);
    }
}
