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
			float4 _MainTex_ST;

			float4 _CameraPosWS;
			float _CameraNearPlane;
			float4x4 _MainCameraInvProj;
			float4x4 _MainCameraInvView;

			sampler3D _NoiseTex;

			float _StartValue;
			
			
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
				positionVS.z = _CameraNearPlane;
				positionVS.w = 1;

				//positionVS is also view space direction
				//so transform it back to word space
				o.dir_ws = float4(mul((float3x3)_MainCameraInvView, positionVS.xyz), 0 );

				return o;
			}

			float SphereSDF(float4 pos)
			{
				return length(pos) - 1;
			}

			float SampleNoise(float3 uvw)
			{
				uvw /= 64;
				return tex3Dlod(_NoiseTex, float4(uvw,0)).r;
			}

			float intersectSDF(float distA, float distB) {
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
			float RayMarching(float4 dir_ws)
			{
				float4 dir = normalize(dir_ws);
				float3 view_dir = UNITY_MATRIX_IT_MV[2].xyz;
				view_dir = normalize(view_dir);
				dir /= dot(view_dir, dir);
				float end = 10000;
				float step_length = 1;
				float current_depth = _StartValue;

				float result = 0;

				for (int i = 0; i < 100; ++i)
				{
					float4 current = _CameraPosWS + dir * current_depth;
					
					int debugBroader = 32;
					/*if (abs(current.x) > debugBroader || abs(current.y) > debugBroader || abs(current.z) > debugBroader)
					{
						return 0;
					}*/

					if (abs(current.y) > debugBroader)
					{
						//return 0;
					}

					float value = SampleNoise(current);

					//float cubeValue = BoxSDF(current);

					//value = intersectSDF(value, cubeValue);
					if (value > 0)
					{
						return value;
					}

					current_depth += step_length;

					if (current_depth > end)
					{
						return end;
					}
				}
				return end;
			}
			
			float4 frag (v2f i) : SV_Target
			{

				//Graphics.Blit(source, destination, this._mat);
				//will render a full screnn quad for position (0,1) in  both x and y
				//so it is better to map this to (-1,1)
				float4 col = float4(0,0,0,1);
				//do ray matching here;

				float result = RayMarching(i.dir_ws);

				

				//col = float4(i.dir_ws,1);

				//col.r = i.pos_vs.z > 0?1:0;
				//col.rgba = result < 0.9 ? result : 0;
				//col.a = result < 0.9 ? result : 1;

				//col = i.dir_ws;
				col = result > 9999 ? 0 : result;
				return col;
			}
			ENDCG
		}
	}
}
