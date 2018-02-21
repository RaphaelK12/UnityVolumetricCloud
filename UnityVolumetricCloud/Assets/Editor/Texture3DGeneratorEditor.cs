using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(Texture3DGenerator))]
public class Texture3DGeneratorEditor : Editor
{

    /// <summary>
    /// InspectorのGUIを更新
    /// </summary>
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        //ボタンを表示
        if (GUILayout.Button("Rebuild"))
        {
            Texture3DGenerator generator = target as Texture3DGenerator;
            generator.Rebuild();
        }
    }

}