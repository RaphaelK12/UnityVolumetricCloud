using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(DetailWorleyNoise))]
public class DetailWorleyNoiseEditor : Editor
{
    public override void OnInspectorGUI()
    {
        EditorGUILayout.BeginVertical();
        if (GUILayout.Button("Save"))
        {
            ((DetailWorleyNoise)target).SaveToAsset();
        }
        if (GUILayout.Button("Load"))
        {
            ((DetailWorleyNoise)target).LoadAsset();
        }
        EditorGUILayout.EndVertical();

        //Called whenever the inspector is drawn for this object.
        DrawDefaultInspector();
    }

}
