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

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			#pragma enable_d3d11_debug_symbols

			#include "UnityCG.cginc"
			#include "Assets/Common.cginc"

			struct vIn
			{
				float4 position		: SV_POSITION;

			};

			struct v2f
			{
				float4 position	: SV_POSITION;
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
			int _SampleValue;
			
			
			v2f vert (vIn v)
			{
				v2f o = (v2f)0;
				o.position = UnityObjectToClipPos(v.position);

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
				uvw /= _SampleValue;
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

			float SampleCloudNoise(float3 uvw, float2 sample_max_min)
			{

				float height_fraction = GetHeightFractionForPoint(uvw, sample_max_min);
				float density_height_gradient = tex2Dlod(_Height, float4(0, height_fraction, 0, 0));



				float cloud = 0;
				uvw /= _SampleValue;
				float4 low_frequency_noises = tex3Dlod(_NoiseTex, float4(uvw, 0));

				float cloud_coverage = tex2Dlod(_Weather, float4(uvw.xz, 0, 0));
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

				if (dir.y < 0.01) return 0.2f;

				int num_samples = 128;
				//this is y range for cloud
				float2 debugBroader = float2(3200, 1500);

				float2 sample_max_min = debugBroader / dir.y;
				float step_length = (sample_max_min.x - sample_max_min.y)  / num_samples;


				float end = 10000;
				float current_depth = sample_max_min.y;

				//current_depth = _StartValue;
				//step_length = 1;

				//if (current_depth > 0) return 0;

				float4 result = float4(0,0,0,0);
				float4 dst = float4(0, 0, 0, 0);

				for (int i = 0; i < num_samples; ++i)
				{
					float4 current = _CameraPosWS + dir * current_depth;
					
					/*if (abs(current.x) > debugBroader || abs(current.y) > debugBroader || abs(current.z) > debugBroader)
					{
						return 0;
					}*/

					if (abs(current.y) > debugBroader.x)
					{
						return float4(0,0,0,0);
					}

					float value = SampleCloudNoise(current, sample_max_min);

					//float cubeValue = BoxSDF(current);

					/*float4 src = float4(value, value, value, value);
					// blend
					dst = (1.0 - dst) * src + dst;

					dst.xyz = (1.0 - dst.a) * src.a * src.xyz + dst.xyz;
					dst.a = (1.0 - dst.a)  * src.a + dst.a;

					if (dst.a > 0) {
						return dst;
					}*/
						result.rgba += value;
						//value = intersectSDF(value, cubeValue);
						if (result.a > 0.99)
						{
							float4 sky = float4(0.2, 0, 0.5, 1);
							value = lerp(value, sky, saturate(sample_max_min.x / 10000));
							return float4(value, value, value,1);
						}
					current_depth += step_length ;

					if (current_depth > end)
					{
						float4 sky = float4(0, 0, 0.5, 1);
						//end = lerp(end, sky, saturate(sample_max_min.x / 5000));
						return float4(0.2, 0.2, 0.2,1);
					}
				}


				float4 sky = float4(0, 0, 0.5, 1);
				end = lerp(end, sky, saturate(sample_max_min.x / 5000));
				//col = i.dir_ws;

				return result;
			}
			
			float4 frag (v2f i) : SV_Target
			{

				//Graphics.Blit(source, destination, this._mat);
				//will render a full screnn quad for position (0,1) in  both x and y
				//so it is better to map this to (-1,1)
				float4 col = float4(0,0,0,1);
				//do ray matching here;

				//float result = RayMarching(i.dir_ws);

				

				//col = float4(i.dir_ws,1);

				//col.r = i.pos_vs.z > 0?1:0;
				//col.rgba = result < 0.9 ? result : 0;
				//col.a = result < 0.9 ? result : 1;

				col.rgba = RayMarching(i.dir_ws);
				//i.dir_ws = normalize(i.dir_ws);

				float4 dir = normalize(i.dir_ws);
				float3 view_dir = UNITY_MATRIX_IT_MV[2].xyz;
				view_dir = normalize(view_dir);
				//dir.xyz = view_dir / dot(view_dir, dir);
				//col.rg = (i.dir_ws.xy);// +1) *0.5;
				//col.r = -col.r;

				//col = result;// > 9999 ? 0 : result;
				return col;
			}
			ENDCG
		}
	}
}
