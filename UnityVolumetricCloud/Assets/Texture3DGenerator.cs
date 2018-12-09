using System.Collections;
using System.Collections.Generic;

#if UNITY_EDITOR
using UnityEditor;
#endif
using UnityEngine;

public class Texture3DGenerator : ScriptableObject
{
    [SerializeField]
    private Texture3D _texture;

	#if UNITY_EDITOR
    public void Rebuild()
    {
        var assetName = "CloudTexture.asset";
        var assetPath = AssetDatabase.FindAssets(assetName);
        if (assetPath != null)
        {
            AssetDatabase.DeleteAsset(assetPath[0]);
        }

        var assetPathName = AssetDatabase.GenerateUniqueAssetPath("Asset" + "/" + assetName);

        // Create an asset.
//         var asset = ScriptableObject.CreateInstance<Texture3DGenerator>();
//         asset.ChangeResolution(resolution);
//         AssetDatabase.CreateAsset(asset, assetPathName);
//         AssetDatabase.AddObjectToAsset(asset.texture, asset);
// 
//         // Build an initial volume for the asset.
//         asset.RebuildTexture();

        // Save the generated mesh asset.
        AssetDatabase.SaveAssets();
    }
	#endif
}
