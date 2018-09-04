using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DepthTextureDebug : MonoBehaviour
{
    
    public ObjectProjection target;
    // Use this for initialization
    void Start () {
		
	}
	
	// Update is called once per frame
	void Update () {
		
	}

    private void OnGUI()
    {
        if (this.gameObject.activeSelf == false || this.target.renderTexture == null) return;
        var w = this.target.renderTexture.width/5;
        GUI.DrawTexture(new Rect(0,0, w, w), this.target.renderTexture);
    }
}
