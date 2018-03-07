﻿// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

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

			sampler2D _MainTex;
			sampler2D _Height;
			sampler2D _Weather;
			float4 _MainTex_ST;

			float4 _CameraPosWS;
			float _CameraNearPlane;
			float4x4 _MainCameraInvProj;
			float4x4 _MainCameraInvView;

			sampler3D _NoiseTex;

			float _StartValue;

			float _CloudBaseUVScale;
			float _WeatherUVScale;

            float4 _CloudHeightMaxMin;

			//cloud rendering parameters
			float _AbsportionCoEff;
			float _ScatteringCoEff;

			float _LightingScale;
			
			
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

			float SampleNoise(float3 uvw)
			{
				uvw *= _CloudBaseUVScale;
				return tex3Dlod(_NoiseTex, float4(uvw,0)).r;
			}
			// Utility function that maps a value from one range to another.
			float Remap(float original_value, float original_min, float original_max, float new_min, float new_max)
			{
				return new_min + (((original_value - original_min) / (original_max - original_min)) * (new_max - new_min));
			}


			// fractional value for sample position in the cloud layer
			float GetHeightFractionForPoint(float3 inPosition, float2 inCloudMaxMin)
			{
				// get global fractional position in cloud zone
				float height_fraction = (inPosition.y - inCloudMaxMin.y) / (inCloudMaxMin.x - inCloudMaxMin.y);

				return saturate(height_fraction);
			}

			float PhaseHenyeyGreenStein(float inScatteringAngle, float g)
			{
				return ((1.0 - g * g) / pow((1.0 + g * g - 2.0 * g * inScatteringAngle), 3.0 / 2.0)) / (4.0 * 3.14159);
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
				float ExtinctionCoEff = _AbsportionCoEff + _ScatteringCoEff;
				return exp( -ExtinctionCoEff * opticalDepth);
			}

			float SampleCloudNoise(float3 uvw, float2 sample_max_min)
			{

				float height_fraction = GetHeightFractionForPoint(uvw, sample_max_min);
				float density_height_gradient = tex2Dlod(_Height, float4(0, height_fraction, 0, 0));



				float cloud = 0;
				
				const float baseFreq = 1e-5;
				uvw *=_CloudBaseUVScale * baseFreq;

				float4 low_frequency_noises = tex3Dlod(_NoiseTex, float4(uvw, 0));

				float2 weather_uv = uvw.xz * _WeatherUVScale;
				float cloud_coverage = tex2Dlod(_Weather, float4(weather_uv, 0, 0));
				float anvil_bias = 0.3;

				// apply anvil deformations
				cloud_coverage = pow(cloud_coverage, Remap(height_fraction, 0.7, 0.8, 1.0, lerp(1.0, 0.5, anvil_bias)));

				//return low_frequency_noises.a;

				float low_freq_fBm = (low_frequency_noises.g * 0.625) + (low_frequency_noises.b * 0.25) + (low_frequency_noises.a * 0.125);

				//return low_freq_fBm;
				// define the base cloud shape by dilating it with the low frequency fBm made of Worley noise.
				float base_cloud = Remap(low_frequency_noises.r, -(1.0 - low_freq_fBm), 1.0, 0.0, 1.0);

				base_cloud *= cloud_coverage;

				return base_cloud;
			}

			
			float3 SampleLight(float4 current, float dir)
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

				//first get step size and step num
				float steps = 6;
				float step_size = _CloudHeightMaxMin.z / steps;

				float3 light_dir = _WorldSpaceLightPos0.xyz;
				float3 light_color = float3(1,1,1);

				float CosThea = dot(dir, light_dir);


				float3 dir_step_length = light_dir * step_size;
				float3 pos = current + 0.5*dir_step_length;

				float density_sum = 0;

				for(int i = 0; i < steps; ++i)
				{
					float3 random_sample = RandomUnitSphere[i] * dir_step_length * (i + 1);

					float3 sample_pos = pos + random_sample;

					float cloud_noise = SampleCloudNoise(sample_pos, _CloudHeightMaxMin.xy);

					density_sum += cloud_noise;

					pos += dir_step_length;
				}

				float hg = PhaseHenyeyGreenStein(CosThea, 0.7);
				float beer = BeerLambert(density_sum);

				return light_color * beer * hg ;

			}

			float intersectSDF(float distA, float distB) 
			{
				return max(distA, distB);
			}
			float udBox(float4 p, float4 b)
			{
				return length(max(abs(p) - b, 0.0));
			}

			float BoxSDF(float4 pos)
			{
				return udBox(pos, float4(10,10,10,1));
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



			float4 RayMarching(float4 dir_ws)
			{
				float4 dir = dir_ws;

                clip(dir.y);

                
				int num_samples = 128;
				//this is y range for cloud
                float2 sample_max_min = _CloudHeightMaxMin.xy / dir.y;
                float step_length = _CloudHeightMaxMin.z / num_samples;


				float end = 10000;
				float current_depth = sample_max_min.y;

				//current_depth = _StartValue;
				//step_length = 1;

				//if (current_depth > 0) return 0;

				float4 result = float4(0,0,0,0);
				float4 dst = float4(0, 0, 0, 0);

				float opticalDepth = 0;

				for (int i = 0; i < num_samples; ++i)
				{
					float4 current = _CameraPosWS + dir * current_depth;
					
					/*if (abs(current.x) > debugBroader || abs(current.y) > debugBroader || abs(current.z) > debugBroader)
					{
						return 0;
					}*/

					if (abs(current.y) > _CloudHeightMaxMin.x)
					{
						return float4(0,0,0,0);
					}

					float value = SampleCloudNoise(current, _CloudHeightMaxMin.xy);

					if(value > 0)
					{
						float3 light = SampleLight(current, dir.xyz);
						
						opticalDepth += value;
						
						result.rgb += light * BeerLambert(opticalDepth);
					}


					result.rgba += value;
					//value = intersectSDF(value, cubeValue);
					if (result.a > 0.99)
					{
						float4 sky = float4(0.2, 0, 0.5, 1);
						value = lerp(value, sky, saturate(sample_max_min.x / 10000));
						return float4(value, value, value,1.0 - BeerLambert(opticalDepth));
					}
					current_depth += step_length ;

					if (current_depth > end)
					{
						float4 sky = float4(0, 0, 0.5, 1);
						//end = lerp(end, sky, saturate(sample_max_min.x / 5000));
						return float4(0.2, 0.2, 0.2,1);
					}
				}

				
				result.a = 1.0 - BeerLambert(opticalDepth);

				float4 sky = float4(0, 0, 0.5, 1);
				end = lerp(end, sky, saturate(sample_max_min.x / 5000));
				//col = i.dir_ws;

				return result;
			}

			float4 SampleWeatherTexture(float3 pos)
			{			
				const float baseFreq = 1e-5;
				float2 weather_uv = pos.xz * _WeatherUVScale *baseFreq;
				return tex2Dlod(_Weather, float4(weather_uv, 0, 0));
			}

			float4 SampleCloudTexture(float3 pos)
			{
				const float baseFreq = 1e-5;
				pos *= _CloudBaseUVScale * baseFreq;
				return tex3Dlod(_NoiseTex, float4(pos,0));
			}

			float SampleCloudDensity(float3 p, float4 weather)
			{				
				//Sample base shape
				float4 low_frequency_noises = SampleCloudTexture(p);

				float low_freq_fBm = (low_frequency_noises.g * 0.625) + (low_frequency_noises.b * 0.25) + (low_frequency_noises.a * 0.125);
				
				// define the base cloud shape by dilating it with the low frequency fBm made of Worley noise.
				float base_cloud = Remap(low_frequency_noises.r, -(1.0 - low_freq_fBm), 1.0, 0.0, 1.0);

				//TODO: missing density_height_gradient

				//cloud coverage is stored in the weather_data's red channel.
				float cloud_coverage = weather.r;

				// apply anvil deformations
				//cloud_coverage = pow(cloud_coverage, Remap(height_fraction, 0.7, 0.8, 1.0, lerp(1.0, 0.5, anvil_bias)));
				
				//Use remapper to apply cloud coverage attribute
				float base_cloud_with_coverage  = Remap(base_cloud, cloud_coverage, 1.0, 0.0, 1.0); 

				//Multiply result by cloud coverage so that smaller clouds are lighter and more aesthetically pleasing.
				base_cloud_with_coverage *= cloud_coverage;

				//define final cloud value
				float final_cloud = base_cloud_with_coverage;

				//TODO: missing detailed sample
				return final_cloud * 10;
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
				
				float step_num = 6;
				float stepScale = (_CloudHeightMaxMin.z / step_num) * _LightingScale;
				float3 stepLength =  stepScale * lightDir;

				//float CosThea = dot(eyeRay, lightDir);
				
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

				float hg = HenyeyGreenstein(eyeRay, lightDir, 0.6);
				float light_energy = BeerLambert(densitySum);

				return lightColor * light_energy * hg;
			}

			float4 RayMarchingCloud(float3 eyeRay, float4 bg)
			{			
                if(eyeRay.y < 0) return bg;

				float4 final = float4(0,0,0,1);
				//1.get the start and end point of cloud
				//from _CloudHeightMaxMin
				float2 sampleMaxMin = _CloudHeightMaxMin.xy / eyeRay.y;

				float3 pos = _CameraPosWS + (eyeRay * sampleMaxMin.y);

				//if(_CloudHeightMaxMin.y == 1500) return float4(1,0,0,1);
				//2.calucate step length and step num
				//TODO: higher eyeRay.y will get lower step num
				int step_num = 128;
				float stepScale = (sampleMaxMin.x - sampleMaxMin.y) / step_num; 
				float3 stepLength = eyeRay * stepScale;

				float densitySum = 0;

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
						float densityScaled = cloudDensity * stepScale;
						//3.3.1 sample light for this point =>ComputeSunColor in 2013 - Real-time Volumetric Rendering Course Notes.pdf
						float3 lightColor = SampleLight(pos, eyeRay);
						//3.3.2 blend light color with current depth
						densitySum += densityScaled;
						lightColor *= densityScaled;

						final.rgb += lightColor * BeerLambert(densitySum) * 0.1;
					}
					//if(densitySum > 0.8) break;
					//3.4 move step_length forward
					pos += stepLength;
				}
				
				final.a = 1-BeerLambert(densitySum);				

				float horizonFade = (1.0f - saturate(sampleMaxMin.x / 30000));
				final *= horizonFade;
				
				final = final + (1-final.a) * bg;

				return final;
			}
			
			float4 frag (v2f i) : SV_Target
			{

				//Graphics.Blit(source, destination, this._mat);
				//will render a full screnn quad for position (0,1) in  both x and y
				//so it is better to map this to (-1,1)
				float4 bg = tex2D(_MainTex, i.uv);
				//do ray matching here;
				//float result = RayMarching(i.dir_ws);

				//return i.dir_ws;
				return RayMarchingCloud(i.dir_ws.xyz, bg);

				//col = float4(i.dir_ws,1);

				//col.r = i.pos_vs.z > 0?1:0;
				//col.rgba = result < 0.9 ? result : 0;
				//col.a = result < 0.9 ? result : 1;

				/*col.rgba = RayMarching(i.dir_ws);
				//i.dir_ws = normalize(i.dir_ws);

				float4 dir = normalize(i.dir_ws);
				float3 view_dir = UNITY_MATRIX_IT_MV[2].xyz;
				view_dir = normalize(view_dir);
				//dir.xyz = view_dir / dot(view_dir, dir);
				//col.rg = (i.dir_ws.xy);// +1) *0.5;
				//col.r = -col.r;

				//col = result;// > 9999 ? 0 : result;
				return col;*/
			}
			ENDCG
		}
	}
}
