/*!
 * File: PerlinWorleyNoise.cs
 * Date: 2018/03/02 12:34
 *
 * Author: Yuan Li
 * Contact: vanish8.7@gmail.com
 *
 * Description: To generate detailed worley noise
 *
 * 
 */
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DetailWorleyNoise : NoiseTexture
{
    [SerializeField]
    private NoiseTexture _worleyNoise0;
    [SerializeField]
    private NoiseTexture _worleyNoise1;
    [SerializeField]
    private NoiseTexture _worleyNoise2;
    
    
    protected override Color GetNoise(NoiseTools.NoiseGeneratorBase noise, float frequency, int dimension, int fractal, int x, int y, int z = 0)
    {
        if (this._worleyNoise0 == null || this._worleyNoise1 == null || this._worleyNoise2 == null) return Color.black;
        //inverted worley noise
        //with higher frequency
        float worley0 = this._worleyNoise0.GetNoiseData(x, y, z);
        float worley1 = this._worleyNoise1.GetNoiseData(x, y, z);
        float worley2 = this._worleyNoise2.GetNoiseData(x, y, z);

        return new Color(worley0, worley1, worley2, 1);
    }

}
