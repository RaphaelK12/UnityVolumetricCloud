// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Render/CloudShader"
{
	Properties
	{
		_MainTex ("CloudVolumeTexture", 3D) = "white" {}
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100
		
		//Cull Off ZWrite Off ZTest Always
		//Blend One OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			#pragma enable_d3d11_debug_symbols

			#include "UnityCG.cginc"
			#include "Lighting.cginc" // for light color
			#include "Assets/Common.cginc"

			struct vIn
			{
				float4 position		: POSITION;
				float2 uv			: TEXCOORD0;

			};

			struct v2f
			{
				float4 position	: SV_POSITION;
				float2 uv		: TEXCOORD1;
				float4 dir_ws	: TEXCOORD0;
			};

			float4 _CloudTopColor;
			float4 _CloudBottomColor;

			sampler2D _MainTex;
			sampler2D _HeightType1;
			sampler2D _HeightType2;
			sampler2D _HeightType3;
			sampler2D _Weather;
			sampler2D _DepthWeather;
			float4 _MainTex_ST;

			float4 _CameraPosWS;
			float _CameraNearPlane;
			float4x4 _MainCameraInvProj;
			float4x4 _MainCameraInvView;

			sampler3D _NoiseTex;
			sampler3D _CloudDetailTexture;
			sampler2D _CurlNoiseTexture;

			float _StartValue;

			float _CloudBaseUVScale;
			float _CloudDetailUVScale;
			float _WeatherUVScale;
			float _CurlNoiseUVScale;

            float4 _CloudHeightMaxMin;

			//cloud rendering parameters
			float _ScatteringCoEff;
			float _HG;

			float _SilverIntensity;
			float _SilverSpread;


			float _LightingStepScale;
			float _CloudStepScale;
			float _CloudDensityScale;

			float _CoverageScale;

			float4 _CloudNoiseBias;
			
			
			v2f vert (vIn v)
			{
				v2f o = (v2f)0;
				o.position = UnityObjectToClipPos(v.position);
				o.uv = v.uv;

				//here to create a clip space position 
				//with z value that on the near clip plane.
				//if this is ndc space, z is 0 because ndc space z is from 0 to 1 for d3d
				//and UNITY_NEAR_CLIP_VALUE will get this

				//here UnityObjectToClipPos does not divide xyz by w, so we just revert position from clip space to view space
				float4 clip = float4(o.position.xyz, 1.0);
				//then transform it back to view space
				//do not confuse _MainCameraInvProj with buildin shader value like UNITY_MATRIX_IT_MV
				//they may be different for post process effect
				float4 positionVS = mul(_MainCameraInvProj, clip);

				//do not use this, it is a postprocess camera
				//positionVS.z = _ProjectionParams.y;

				//set the position on the near plane so we can start ray marching from here
				//positionVS.z = _CameraNearPlane;
				positionVS.w = 1;


				//positionVS is also view space direction
				//so transform it back to word space
				o.dir_ws = float4(mul((float3x3)_MainCameraInvView, positionVS.xyz), 0 );

				return o;
			}

			v2f vert_new(vIn v)
			{
				v2f o = (v2f)0;
				o.position = UnityObjectToClipPos(v.position);
				o.dir_ws = mul(unity_ObjectToWorld, v.position) - float4(0.5,0.5,-1.0f,1.0f);
				return o;
			}

			float SphereSDF(float4 pos)
			{
				return length(pos) - 1;
			}
			float RayMarchingSphere(float4 dir_ws)
			{
				float4 dir = dir_ws;//normalize(dir_ws);
				
				int num_samples = 500;

				float end = 10000;
				float current_depth = 0;

				//current_depth = _StartValue;
				float step_length = 0.01;

				//if (current_depth > 0) return 0;

				float result = 0;

				for (int i = 0; i < num_samples; ++i)
				{
					float4 current = _CameraPosWS + dir * current_depth;
					float value = SphereSDF(current);

					if (value < 0.01)
					{
						return 1;
					}

					current_depth += step_length;
				}

				return result;
			}

			// Utility function that maps a value from one range to another.
			float Remap(float original_value, float original_min, float original_max, float new_min, float new_max)
			{
				if(original_max == original_min) return new_min;
				return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
			}


			// fractional value for sample position in the cloud layer
			float GetHeightFractionForPoint(float3 inPosition, float2 inCloudMaxMin)
			{
				// get global fractional position in cloud zone
				float heightFraction = (inPosition.y - inCloudMaxMin.y) / (inCloudMaxMin.x - inCloudMaxMin.y);

				return saturate(heightFraction);
			}

			//this function will retrun how much cloud
			//should be remained in this heightFraction with this cloudType
			float GetHeightFractionFromFraction(float heightFraction, float cloudType)
			{
				//return tex2Dlod(_HeightType1, float4(0, heightFraction,0,0)).r;
				heightFraction = clamp(heightFraction, 0, 1);
				float h1 = tex2Dlod(_HeightType1, float4(0, heightFraction,0,0)).r;
				float h2 = tex2Dlod(_HeightType2, float4(0, heightFraction,0,0)).r;
				float h3 = tex2Dlod(_HeightType3, float4(0, heightFraction,0,0)).r;

				float h12 = lerp(h1, h2, saturate(cloudType * 2));
				float h23 = lerp(h2, h3, saturate((cloudType - 0.5) * 2));

				return lerp(h12,h23,cloudType);
			}

			//another cloudLayerDensity function from https://github.com/mccannd/Project-Marshmallow
			//same but without sampling texture
			float cloudLayerDensity(float relativeHeight, float cloudType) 
			{
				relativeHeight = clamp(relativeHeight, 0, 1);
    
				float cumulus = max(0.0, Remap(relativeHeight, 0.0, 0.2, 0.0, 1.0) * Remap(relativeHeight, 0.7, 0.9, 1.0, 0.0));
				float stratocumulus = max(0.0, Remap(relativeHeight, 0.0, 0.2, 0.0, 1.0) * Remap(relativeHeight, 0.2, 0.7, 1.0, 0.0)); 
				float stratus = max(0.0, Remap(relativeHeight, 0.0, 0.1, 0.0, 1.0) * Remap(relativeHeight, 0.2, 0.3, 1.0, 0.0)); 

				float d1 = lerp(stratus, stratocumulus, clamp(cloudType * 2.0, 0.0, 1.0));
				float d2 = lerp(stratocumulus, cumulus, clamp((cloudType - 0.5) * 2.0, 0.0, 1.0));
				return lerp(d1, d2, cloudType);
    		}

			float3 GetAmbientColor(float3 position)
			{
				return (float3)0;
				float ExtinctionCoEff = _ScatteringCoEff;
				float height = GetHeightFractionForPoint(position, _CloudHeightMaxMin);
				return lerp(_CloudBottomColor, _CloudTopColor, height).rgb * ExtinctionCoEff * 0.01;
			}

			float PhaseHenyeyGreenStein(float cosAngle, float g)
			{
				//return ((1.0 - g * g) / pow((1.0 + g * g - 2.0 * g * inScatteringAngle), 3.0 / 2.0)) / (4.0 * 3.14159);
				
				return ((1.0 - g * g ) / (4.0 * 3.1415926f * pow ((1.0 + g * g - 2.0 * g * cosAngle ) , 3.0 / 2.0)));
			}
						
			//this will get In-Scattering term
			float HenyeyGreenstein ( float3 inLightVector , float3 inViewVector , float inG )
			{
				float cos_angle = dot ( normalize ( inLightVector ) , normalize ( inViewVector )) ;
				return ((1.0 - inG * inG ) / (4.0 * 3.1415926f * pow ((1.0 + inG * inG - 2.0 * inG * cos_angle ) , 3.0 / 2.0)));
			}

			//this will get Extinction term
			//we can get Transparence from this
			float BeerLambert(float opticalDepth)
			{
				//original paper add a rain parameter here
				//to make a darker clooud for weather texture's g chanel
				float ExtinctionCoEff = _ScatteringCoEff; // * weather.g
				return exp( -ExtinctionCoEff * opticalDepth);
			}

			float Powder(float opticalDepth)
			{
				float ExtinctionCoEff = _ScatteringCoEff;
				return 1.0f - exp( - 2 * ExtinctionCoEff * opticalDepth);
			}
			
			float4 SampleWeatherTexture(float3 pos)
			{			
				const float baseFreq = 1e-5;
				float2 weather_uv = pos.xz * _WeatherUVScale *baseFreq;
				weather_uv += 0.8;
				return tex2Dlod(_Weather, float4(weather_uv, 0, 0));
				return tex2Dlod(_DepthWeather, float4(weather_uv, 0, 0));
			}

			float4 SampleCloudTexture(float3 pos)
			{
				const float baseFreq = 1e-5;
				pos *= _CloudBaseUVScale * baseFreq * _CloudNoiseBias.xyz;
				return tex3Dlod(_NoiseTex, float4(pos,0));
			}

			float4 SampleCloudDetailTexture(float3 pos)
			{
				const float baseFreq = 1e-5;
				pos *= _CloudDetailUVScale * baseFreq;
				return tex3Dlod(_CloudDetailTexture, float4(pos,0));
			}

			float4 SampleCloudCurlTexture(float3 pos)
			{
				const float baseFreq = 1;
				pos *= _CurlNoiseUVScale * baseFreq;
				return tex2Dlod(_CurlNoiseTexture, float4(pos,0));
			}



			float SampleCloudDensity(float3 p, float4 weather)
			{				
				//Sample base shape
				float4 low_frequency_noises = SampleCloudTexture(p);

				float low_freq_fBm = (low_frequency_noises.g * 0.625) + (low_frequency_noises.b * 0.25) + (low_frequency_noises.a * 0.125);
				
				// define the base cloud shape by dilating it with the low frequency fBm made of Worley noise.
				// here is slightlt different than original code WITHOUT Nagative below
				float base_cloud = Remap(low_frequency_noises.r, (1.0 - low_freq_fBm), 1.0, 0.0, 1.0);
				float height_fraction = GetHeightFractionForPoint(p, _CloudHeightMaxMin);
				

				//DONE: missing density_height_gradient
				float density_height_gradient = GetHeightFractionFromFraction(height_fraction, weather.b);

				{
					//========================================================
					//Wind part
					//DONE: missing wind
					// wind settings
					float3 wind_direction = float3(1.0, 0.0, 0.0);
					float cloud_speed = 500.0;

					// cloud_top offset - push the tops of the clouds along this wind direction by this many units.
					float cloud_top_offset = 500.0;

					// skew in wind direction
					p += height_fraction * wind_direction * cloud_top_offset;

					//animate clouds in wind direction and add a small upward bias to the wind direction
					p+= (wind_direction + float3(0.0, 0.1, 0.0)  ) * _Time * cloud_speed;
					//=========================================================
				}

				base_cloud *= density_height_gradient;

				//cloud coverage is stored in the weather_data's red channel.
				float cloud_coverage = weather.r;

				float anvil_bias = 0.3f;
				// apply anvil deformations
				cloud_coverage = pow(cloud_coverage, Remap(height_fraction, 0.7, 0.8, 1.0, lerp(1.0, 0.5, anvil_bias)));
				
				//Use remapper to apply cloud coverage attribute
				//if cloud_coverage = 0,
				//it will do nothing about base_cloud value
				//resrict cloud_coverage value in the range of base_cloud
				//float base_cloud_with_coverage  = Remap(base_cloud, cloud_coverage, 1.0, 0.0, 1.0); 

				float base_cloud_with_coverage  = 0;

				if(1)//this will have more control on cloud coverage than code in else cluase.
				{
					//_CoverageScale in range (0,1) will change texture_coverage;
					//_CoverageScale in range (1,2) will get over_all value from texture_coverage to 1;
					float texture_coverage = lerp(0, cloud_coverage, saturate(_CoverageScale));
					base_cloud_with_coverage = base_cloud * (texture_coverage + saturate(_CoverageScale-1));
				}
				else
				{				
					// I do not use the following two lines because I want to map coverage(_CoverageScale value from 0 to 2)
					//from 0 to texture's cloud_coverage then to base_cloud value
					base_cloud_with_coverage = Remap(base_cloud, cloud_coverage*_CoverageScale, 1.0, 0.0, 1.0); 
					//Multiply result by cloud coverage so that smaller clouds are lighter and more aesthetically pleasing.
					base_cloud_with_coverage *= cloud_coverage;
				}

				//define final cloud value
				float final_cloud = base_cloud_with_coverage;

				//DONE: detailed sample
				if(1)
				{
					// add some turbulence to bottoms of clouds using curl noise.  Ramp the effect down over height and scale it by some value (200 in this example)
					float2 curl_noise =  SampleCloudCurlTexture(float3(p.x, p.y, 0.0)).rg;
					p.xy += curl_noise.rg * (1.0 - height_fraction) * 200.0;

					// sample high-frequency noises
					float3 high_frequency_noises = SampleCloudDetailTexture(p).rgb;

					// build High frequency Worley noise fBm
					float high_freq_fBm = ( high_frequency_noises.r * 0.625 ) + ( high_frequency_noises.g * 0.25 ) + ( high_frequency_noises.b * 0.125 );

					// get the height_fraction for use with blending noise types over height
					float height_fraction  = GetHeightFractionForPoint(p, _CloudHeightMaxMin);

					// transition from wispy shapes to billowy shapes over height
					float high_freq_noise_modifier = lerp(high_freq_fBm, 1.0 - high_freq_fBm, saturate(height_fraction * 10.0));

					// erode the base cloud shape with the distorted high frequency Worley noises.
					final_cloud = Remap(base_cloud_with_coverage, high_freq_noise_modifier * 0.2 , 1.0, 0.0, 1.0);
				}
				return saturate(final_cloud * _CloudDensityScale);
			}

			
			float3 SampleLight(float3 pos, float3 eyeRay)
			{
				const float3 RandomUnitSphere[6] = 
				{
					{0.3f, -0.8f, -0.5f},
					{0.9f, -0.3f, -0.2f},
					{-0.9f, -0.3f, -0.1f},
					{-0.5f, 0.5f, 0.7f},
					{-1.0f, 0.3f, 0.0f},
					{-0.3f, 0.9f, 0.4f}
				};
				
				//this dir point to light position for direction light
				float3 lightDir = _WorldSpaceLightPos0.xyz;
				float3 lightColor = _LightColor0.rgb;
				
				//sample 6 points for lighting
				float step_num = 6;
				float stepScale = _CloudHeightMaxMin.z / step_num * _LightingStepScale;
				float3 stepLength =  stepScale * lightDir;

				
				float densitySum = 0.0;

				for (int i = 0; i < step_num; i++)
				{
					float3 random_sample = RandomUnitSphere[i] * stepLength * (i + 1);

					float3 sample_pos = pos + random_sample;
					
					float4 weather = SampleWeatherTexture(sample_pos);

					float cloud_noise = SampleCloudDensity(sample_pos, weather);

					densitySum += cloud_noise * stepScale;

					pos += stepLength;
				}
				
				//use 2 hg function to avoid dark part of cloud
				//as course note indicates.
				float cosThea = dot(eyeRay, lightDir);
				float hgForward = PhaseHenyeyGreenStein(cosThea, _HG);
				float hgBackward = PhaseHenyeyGreenStein(cosThea, 0.99 - _SilverSpread) * _SilverIntensity;

				float hgTotal = max(hgForward, hgBackward);
				
				//add parameter here to make cloud lighter
				float lightEnergy1 = BeerLambert(densitySum);
				float lightEnergy2 = BeerLambert(densitySum*0.25)*0.7;

				float lightEnergy = max(lightEnergy1,lightEnergy2);

				//Powder effect term
				float powder = Powder(densitySum);

				return lightColor* lightEnergy * hgTotal * powder;
			}

			float4 RayMarchingCloud(float3 eyeRay, float4 bg)
			{			
                if(eyeRay.y < 0) return bg;

				eyeRay = normalize(eyeRay);

				float4 final = float4(0,0,0,1);
				//1.get the start and end point of cloud
				//from _CloudHeightMaxMin
				//for batter result, use sphere to get this 
				//because earch is sphere
				float2 sampleMaxMin = _CloudHeightMaxMin.xy / eyeRay.y;

				//start ray marching from min height of the cloud
				float3 pos = _CameraPosWS + (eyeRay * sampleMaxMin.y);

				//2.calucate step length and step num
				//TODO: higher eyeRay.y will get lower step num
				int step_num = 128;
				float stepScale = (sampleMaxMin.x - sampleMaxMin.y) / step_num; 
				float3 stepLength = eyeRay * stepScale * _CloudStepScale;

				float densitySum = 0;// not used
				float extinction = 1;

				//3.start raymarcing for loop
				for(int i = 0 ; i < step_num; ++i)
				{
					//3.1 get current sample point					
					//3.2 sample cloud noise
					float4 weather = SampleWeatherTexture(pos);
					float cloudDensity = SampleCloudDensity(pos, weather); 
					//3.3 if noise value > 0
					if(cloudDensity > 0)
					{
						float3 ambientColor = GetAmbientColor(pos) * stepScale;
						float densityScaled = cloudDensity * stepScale;
						//3.3.1 sample light for this point =>ComputeSunColor in 2013 - Real-time Volumetric Rendering Course Notes.pdf
						float3 lightColor = SampleLight(pos, eyeRay);
						//3.3.2 blend light color with current depth
						densitySum += densityScaled;
						lightColor *= densityScaled;

						extinction *= BeerLambert(densityScaled);

						final.rgb += (ambientColor + lightColor) * extinction;
					}
					//3.4 move step_length forward
					pos += stepLength;

					if(extinction < 0.001) 
						break;
				}
				//final.rgb *= extinction;
				
				final.a = saturate(1-extinction);				

				float horizonFade = (1.0f - saturate(sampleMaxMin.x / 50000));
				final *= horizonFade;
				
				final = final + saturate(1-final.a) * bg;

				return final;
			}
			
			float4 frag (v2f i) : SV_Target
			{
				//Graphics.Blit(source, destination, this._mat);
				//will render a full screnn quad for position (0,1) in  both x and y
				//so it is better to map this to (-1,1)
				float4 bg = tex2D(_MainTex, i.uv);
				//do ray matching here;
				return RayMarchingCloud(i.dir_ws.xyz, bg);
			}
			ENDCG
		}
	}
}
